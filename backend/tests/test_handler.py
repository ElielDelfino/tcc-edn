import json
from unittest.mock import MagicMock

import pytest
from botocore.exceptions import ClientError

import handler


@pytest.fixture
def dynamo(monkeypatch):
    """Troca o cliente real do módulo por um dublê, só durante o teste."""
    fake = MagicMock()
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


def test_get_sem_item_devolve_zero(dynamo):
    # Contador ainda não criado: o get_item devolve um dicionário vazio
    dynamo.get_item.return_value = {}

    response = handler.lambda_handler({"httpMethod": "GET"}, None)

    assert response["statusCode"] == 200
    assert json.loads(response["body"]) == {"count": 0}


@pytest.mark.parametrize("event", [{"httpMethod": "DELETE"}, {"httpMethod": "PUT"}, {}])
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
