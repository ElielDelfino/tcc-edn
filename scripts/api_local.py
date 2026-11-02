#!/usr/bin/env python3
"""API HTTP local para exercitar a Lambda do TCC sem acessar serviços AWS.

Simula apenas o armazenamento DynamoDB (em RAM), mas executa o handler real.
Uso: py -3 scripts\api_local.py --port 8765 --initial 41
"""
from __future__ import annotations

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import sys
from threading import Lock

# O handler cria um client boto3 durante o import. Desabilitar credenciais reais
# neste processo e fornecer configurações de teste para evitar dependência da AWS.
for name in ("AWS_PROFILE", "AWS_SESSION_TOKEN", "AWS_ENDPOINT_URL"):
    os.environ.pop(name, None)
os.environ.update({
    "TABLE_NAME": "AccessCounterLocal",
    "COUNTER_ID": "hits",
    "AWS_DEFAULT_REGION": "us-east-1",
    "AWS_ACCESS_KEY_ID": "teste-local-sem-acesso-aws",
    "AWS_SECRET_ACCESS_KEY": "teste-local-sem-acesso-aws",
    "AWS_EC2_METADATA_DISABLED": "true",
})
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend" / "contador"))
import handler  # noqa: E402: precisa das variáveis definidas acima


class DynamoDBEmMemoria:
    """Substitui somente update_item/get_item do DynamoDB, sem persistência."""

    def __init__(self, inicial: int):
        self.total = inicial
        self.lock = Lock()

    def update_item(self, **kwargs):
        if kwargs.get("Key") != {"id": {"S": "hits"}}:
            raise ValueError("Chave inesperada")
        if kwargs.get("ReturnValues") != "UPDATED_NEW":
            raise ValueError("ReturnValues inesperado")
        if kwargs.get("UpdateExpression") != "ADD #c :one":
            raise ValueError("Expressão de atualização inesperada")
        with self.lock:
            self.total += 1
            return {"Attributes": {"count": {"N": str(self.total)}}}

    def get_item(self, **kwargs):
        if kwargs.get("Key") != {"id": {"S": "hits"}}:
            raise ValueError("Chave inesperada")
        with self.lock:
            return {"Item": {"id": {"S": "hits"}, "count": {"N": str(self.total)}}}


class API(BaseHTTPRequestHandler):
    def do_GET(self):
        self.processar("GET")

    def do_POST(self):
        self.processar("POST")

    def processar(self, metodo):
        if self.path != "/count":
            self.send_error(404, "Caminho inválido. Use /count")
            return
        result = handler.lambda_handler({"httpMethod": metodo}, None)
        corpo = result["body"].encode("utf-8")
        self.send_response(result["statusCode"])
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(corpo)))
        self.end_headers()
        self.wfile.write(corpo)
        print(f"{metodo:4s} /count -> HTTP {result['statusCode']} {result['body']}", flush=True)

    def log_message(self, *_):
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description="Servidor para testes locais sem AWS")
    parser.add_argument("--port", type=int, default=8765, help="Porta TCP (padrão 8765)")
    parser.add_argument("--initial", type=int, default=41, help="Contagem inicial (padrão 41)")
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535:
        parser.error("Escolha uma porta entre 1024 e 65535")
    if args.initial < 0:
        parser.error("A contagem inicial deve ser >= 0")

    handler.dynamodb = DynamoDBEmMemoria(args.initial)
    try:
        with ThreadingHTTPServer(("127.0.0.1", args.port), API) as servidor:
            print("API local iniciada (DynamoDB simulado em memória; sem AWS).", flush=True)
            print(f"Endpoint: http://127.0.0.1:{args.port}/count", flush=True)
            print("Deixe esta janela aberta. Ctrl+C para encerrar e apagar a contagem.", flush=True)
            servidor.serve_forever()
    except KeyboardInterrupt:
        print("\nServidor encerrado.", flush=True)
    except OSError as exc:
        parser.error(f"Não foi possível abrir a porta {args.port}: {exc}")


if __name__ == "__main__":
    main()
