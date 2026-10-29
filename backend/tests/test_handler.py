import importlib.util
import json
import logging
from pathlib import Path
from unittest.mock import MagicMock

import pytest
from botocore.exceptions import ClientError

import handler


@pytest.fixture
def dynamo(monkeypatch):
    """Troca o cliente real do módulo por um dublê, só durante o teste."""
    fake = MagicMock(spec=handler.dynamodb)  # com spec, método inexistente no boto3 dá erro
    monkeypatch.setattr(handler, "dynamodb", fake)
    return fake


def test_post_incrementa_e_devolve_o_novo_total(dynamo):
    # Arrange: o "DynamoDB" vai responder que o total agora é 7
    dynamo.update_item.return_value = {"Attributes": {"count": {"N": "7"}}}

    # Act
    response = handler.lambda_handler({"httpMethod": "POST"}, None)

    # Assert: resposta correta E chamada correta
    assert response["statusCode"] == 200
    assert json.loads(response["body"]) == {"count": 7}
    dynamo.update_item.assert_called_once_with(
        TableName="tabela-de-teste",
        Key={"id": {"S": "hits"}},
        UpdateExpression="ADD #c :one",
        ExpressionAttributeNames={"#c": "count"},
        ExpressionAttributeValues={":one": {"N": "1"}},
        ReturnValues="UPDATED_NEW",
    )
    dynamo.get_item.assert_not_called()


def test_get_devolve_o_total_com_leitura_consistente(dynamo):
    dynamo.get_item.return_value = {"Item": {"id": {"S": "hits"}, "count": {"N": "42"}}}

    response = handler.lambda_handler({"httpMethod": "GET"}, None)

    assert response["statusCode"] == 200
    assert json.loads(response["body"]) == {"count": 42}
    dynamo.get_item.assert_called_once_with(
        TableName="tabela-de-teste",
        Key={"id": {"S": "hits"}},
        ConsistentRead=True,
    )
    dynamo.update_item.assert_not_called()


def test_get_sem_item_devolve_zero(dynamo):
    # Contador ainda não criado: o get_item devolve um dicionário vazio
    dynamo.get_item.return_value = {}

    response = handler.lambda_handler({"httpMethod": "GET"}, None)

    assert response["statusCode"] == 200
    assert json.loads(response["body"]) == {"count": 0}


@pytest.mark.parametrize(
    "event",
    [{"httpMethod": "DELETE"}, {"httpMethod": "PUT"}, pytest.param({}, id="sem-httpMethod")],
)
def test_metodo_nao_permitido_devolve_405_sem_tocar_no_banco(dynamo, event):
    response = handler.lambda_handler(event, None)

    assert response["statusCode"] == 405
    assert json.loads(response["body"]) == {"error": "Método não permitido"}
    dynamo.update_item.assert_not_called()
    dynamo.get_item.assert_not_called()


def test_erro_do_dynamodb_devolve_500_sem_vazar_detalhes(dynamo):
    dynamo.update_item.side_effect = ClientError(
        {"Error": {"Code": "X", "Message": "segredo"}}, "UpdateItem"
    )

    response = handler.lambda_handler({"httpMethod": "POST"}, None)

    assert response["statusCode"] == 500
    assert json.loads(response["body"]) == {"error": "Erro interno ao processar o contador"}
    assert "segredo" not in response["body"]


def test_resposta_traz_header_cors_da_origem_permitida(dynamo):
    dynamo.get_item.return_value = {}

    response = handler.lambda_handler({"httpMethod": "GET"}, None)

    assert response["headers"]["Access-Control-Allow-Origin"] == "https://site-de-teste.example"
    assert response["headers"]["Content-Type"] == "application/json"


# --- Erros em qualquer método, não só no POST ---------------------------------------------------


@pytest.mark.parametrize(
    "metodo, operacao",
    [("POST", "update_item"), ("GET", "get_item")],
)
def test_erro_do_dynamodb_devolve_500_em_post_e_get(dynamo, metodo, operacao):
    getattr(dynamo, operacao).side_effect = ClientError(
        {"Error": {"Code": "X", "Message": "segredo"}}, operacao
    )

    response = handler.lambda_handler({"httpMethod": metodo}, None)

    assert response["statusCode"] == 500
    assert "segredo" not in response["body"]


def test_resposta_malformada_do_dynamodb_devolve_500(dynamo):
    # Item sem o atributo "count": o handler levanta KeyError, que também vira 500
    dynamo.get_item.return_value = {"Item": {"id": {"S": "hits"}}}

    response = handler.lambda_handler({"httpMethod": "GET"}, None)

    assert response["statusCode"] == 500


# --- RNF-09: o log de erro não pode guardar dados do visitante ---------------------------------


def test_log_de_erro_existe_e_nao_contem_dados_do_visitante(dynamo, caplog):
    caplog.set_level(logging.ERROR)
    dynamo.update_item.side_effect = RuntimeError("falha")
    evento = {
        "httpMethod": "POST",
        "requestContext": {"identity": {"sourceIp": "203.0.113.9"}},
        "headers": {"User-Agent": "Mozilla-X"},
    }

    handler.lambda_handler(evento, None)

    assert caplog.records, "o erro deveria ser registrado no log"
    assert "203.0.113.9" not in caplog.text
    assert "Mozilla-X" not in caplog.text


# --- Configuração por variável de ambiente -----------------------------------------------------


def test_usa_o_counter_id_configurado(dynamo, monkeypatch):
    monkeypatch.setattr(handler, "COUNTER_ID", "outro-contador")
    dynamo.update_item.return_value = {"Attributes": {"count": {"N": "1"}}}
    dynamo.get_item.return_value = {}

    handler.lambda_handler({"httpMethod": "POST"}, None)
    handler.lambda_handler({"httpMethod": "GET"}, None)

    assert dynamo.update_item.call_args.kwargs["Key"] == {"id": {"S": "outro-contador"}}
    assert dynamo.get_item.call_args.kwargs["Key"] == {"id": {"S": "outro-contador"}}


def test_sem_allowed_origin_o_padrao_e_asterisco(monkeypatch):
    # Carrega uma cópia do módulo com outro nome, sem ALLOWED_ORIGIN, para não afetar
    # o módulo `handler` usado pelos demais testes.
    monkeypatch.delenv("ALLOWED_ORIGIN")
    caminho = Path(handler.__file__)
    spec = importlib.util.spec_from_file_location("handler_sem_origem", caminho)
    copia = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(copia)

    assert copia._response(200, {})["headers"]["Access-Control-Allow-Origin"] == "*"


# --- Formato da resposta -----------------------------------------------------------------------


def test_corpo_preserva_acentos_sem_escape_unicode(dynamo):
    response = handler.lambda_handler({"httpMethod": "PUT"}, None)

    assert "Método não permitido" in response["body"]
    assert "\\u" not in response["body"]


@pytest.mark.parametrize(
    "metodo, preparar",
    [
        ("POST", lambda d: setattr(d.update_item, "return_value", {"Attributes": {"count": {"N": "1"}}})),
        ("PUT", lambda d: None),
        ("GET", lambda d: setattr(d.get_item, "side_effect", RuntimeError("falha"))),
    ],
    ids=["200-post", "405", "500-get"],
)
def test_todas_as_respostas_trazem_cors_e_content_type(dynamo, metodo, preparar):
    preparar(dynamo)

    response = handler.lambda_handler({"httpMethod": metodo}, None)

    assert response["headers"]["Access-Control-Allow-Origin"] == "https://site-de-teste.example"
    assert response["headers"]["Content-Type"] == "application/json"
