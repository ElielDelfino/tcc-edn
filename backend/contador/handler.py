"""Handler do Contador de Acessos (integração proxy do API Gateway REST).

GET  /count -> {"count": <total>}
POST /count -> incrementa atomicamente e retorna {"count": <novo total>}
"""
import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TABLE_NAME = os.environ["TABLE_NAME"]
COUNTER_ID = os.environ.get("COUNTER_ID", "hits")
ALLOWED_ORIGIN = os.environ.get("ALLOWED_ORIGIN", "*")

# Cliente criado fora do handler para ser reaproveitado entre invocações
# do mesmo ambiente de execução (reduz latência após o cold start).
dynamodb = boto3.client("dynamodb")


def _response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
        },
        "body": json.dumps(body, ensure_ascii=False),
    }


def _increment() -> int:
    # ADD é atômico no DynamoDB: chamadas simultâneas não sobrescrevem umas às
    # outras (sem read-modify-write) e o item é criado na primeira chamada.
    # "count" é palavra reservada do DynamoDB, por isso o alias #c.
    result = dynamodb.update_item(
        TableName=TABLE_NAME,
        Key={"id": {"S": COUNTER_ID}},
        UpdateExpression="ADD #c :one",
        ExpressionAttributeNames={"#c": "count"},
        ExpressionAttributeValues={":one": {"N": "1"}},
        ReturnValues="UPDATED_NEW",
    )
    return int(result["Attributes"]["count"]["N"])


def _get_total() -> int:
    # Leitura fortemente consistente: reflete todos os incrementos já confirmados.
    result = dynamodb.get_item(
        TableName=TABLE_NAME,
        Key={"id": {"S": COUNTER_ID}},
        ConsistentRead=True,
    )
    item = result.get("Item")
    return int(item["count"]["N"]) if item else 0


def lambda_handler(event, context):
    method = event.get("httpMethod")
    try:
        if method == "POST":
            return _response(200, {"count": _increment()})
        if method == "GET":
            return _response(200, {"count": _get_total()})
        return _response(405, {"error": "Método não permitido"})
    except Exception:
        # Log sem dados do visitante (IP, headers) — RNF-09.
        logger.exception("Falha ao processar %s /count", method)
        return _response(500, {"error": "Erro interno ao processar o contador"})
