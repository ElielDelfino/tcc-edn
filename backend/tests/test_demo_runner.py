"""Teste E2E local do script de demonstração usando o handler real da Lambda.

DynamoDB é simulado; este arquivo NÃO atesta deploy real na AWS.
"""
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import shutil
import subprocess
import sys
import threading

import pytest

import handler


SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "demo_end_to_end.py"


class DynamoFalso:
    def __init__(self, inicial=41, incremento=1):
        self.count = inicial
        self.incremento = incremento
        self.lock = threading.Lock()

    def update_item(self, **kwargs):
        assert kwargs["Key"] == {"id": {"S": "hits"}}
        assert kwargs["ReturnValues"] == "UPDATED_NEW"
        with self.lock:
            self.count += self.incremento
            return {"Attributes": {"count": {"N": str(self.count)}}}

    def get_item(self, **kwargs):
        assert kwargs["ConsistentRead"] is True
        with self.lock:
            return {"Item": {"id": {"S": "hits"}, "count": {"N": str(self.count)}}}


@contextmanager
def api_local():
    class ServidorHTTP(BaseHTTPRequestHandler):
        def do_GET(self):
            self.responder("GET")

        def do_POST(self):
            self.responder("POST")

        def responder(self, metodo):
            if self.path != "/count":
                self.send_error(404)
                return
            result = handler.lambda_handler({"httpMethod": metodo}, None)
            body = result["body"].encode("utf-8")
            self.send_response(result["statusCode"])
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), ServidorHTTP)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"http://127.0.0.1:{server.server_port}/count"
    finally:
        server.shutdown()
        thread.join(timeout=5)
        server.server_close()


@pytest.mark.skipif(not shutil.which("curl"), reason="curl ausente neste ambiente")
def test_demo_e2e_tres_ciclos_com_handler_real_e_dynamo_simulado(monkeypatch, tmp_path):
    fake = DynamoFalso(inicial=41)
    monkeypatch.setattr(handler, "dynamodb", fake)
    with api_local() as url:
        completed = subprocess.run(
            [sys.executable, str(SCRIPT), "--url", url, "--cycles", "3",
             "--evidence-dir", str(tmp_path)],
            capture_output=True, text=True, check=False, timeout=30,
        )
    assert completed.returncode == 0, completed.stdout + completed.stderr
    assert "APROVADO: 3 ciclos completos" in completed.stdout
    assert fake.count == 44
    evidence = json.loads(next(tmp_path.glob("demo-*.json")).read_text(encoding="utf-8"))
    assert evidence["status"] == "aprovado"
    assert evidence["ciclos_validados"] == 3
    assert evidence["contagem_inicial"] == 41
    assert evidence["contagem_final"] == 44
    assert [item["method"] for item in evidence["chamadas"]] == [
        "GET", "POST", "GET", "POST", "GET", "POST", "GET", "GET"
    ]


@pytest.mark.skipif(not shutil.which("curl"), reason="curl ausente neste ambiente")
def test_demo_reprova_incremento_incorreto_e_preserva_evidencias(monkeypatch, tmp_path):
    fake = DynamoFalso(inicial=41, incremento=2)
    monkeypatch.setattr(handler, "dynamodb", fake)
    with api_local() as url:
        completed = subprocess.run(
            [sys.executable, str(SCRIPT), "--url", url, "--cycles", "3",
             "--evidence-dir", str(tmp_path)],
            capture_output=True, text=True, check=False, timeout=30,
        )
    assert completed.returncode == 1
    assert "REPROVADO" in completed.stdout
    evidence = json.loads(next(tmp_path.glob("demo-*.json")).read_text(encoding="utf-8"))
    assert evidence["status"] == "falhou"
    assert evidence["ciclos_validados"] == 0
    assert "+1" not in evidence.get("erro", "") or "deveria retornar" in evidence["erro"]
