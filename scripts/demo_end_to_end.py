#!/usr/bin/env python3
"""Demonstração da Sprint 3: GET inicial, três ciclos curl POST -> curl GET.

Executa chamadas HTTP reais com curl, valida os resultados e salva evidências
locais. Não configura infraestrutura AWS nem substitui testes de deploy.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.parse import urlsplit


def curl_request(executable: str, endpoint: str, method: str) -> dict:
    """Retorna resposta válida ou falha; usa curl (curl.exe no Windows)."""
    args = [
        executable,
        "--silent",
        "--show-error",
        "--max-time", "20",
        "--connect-timeout", "8",
        "--header", "Accept: application/json",
        "--request", method,
        "--write-out", "\n__HTTP_STATUS__:%{http_code}",
    ]
    if method == "POST":
        args += ["--header", "Content-Type: application/json", "--data", "{}"]
    args += ["--url", endpoint]

    completed = subprocess.run(args, capture_output=True, text=True,
                               encoding="utf-8", errors="replace", check=False)
    body, marker, status_text = completed.stdout.rpartition("\n__HTTP_STATUS__:")
    if not marker:
        details = completed.stderr.strip() or "resposta HTTP sem status"
        raise RuntimeError(f"{method}: falha na chamada HTTP (curl {completed.returncode}): {details}")
    try:
        status = int(status_text.strip())
    except ValueError as exc:
        raise RuntimeError(f"{method}: status HTTP inválido recebido do curl") from exc
    if completed.returncode != 0 or status != 200:
        # Não imprime o corpo de erros, que pode conter detalhes não destinados à demo.
        raise RuntimeError(f"{method}: esperado HTTP 200; recebido HTTP {status} "
                           f"(curl {completed.returncode}). Verifique o deploy e os logs.")
    try:
        response = json.loads(body)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"{method}: a API não retornou um JSON válido") from exc
    if not isinstance(response, dict) or type(response.get("count")) is not int:
        raise RuntimeError(f"{method}: resposta esperada {{\"count\": N}} com N inteiro")
    if response["count"] < 0:
        raise RuntimeError(f"{method}: o contador não pode ser negativo")
    return {"method": method, "status": status, "count": response["count"]}


def validar_url(endpoint: str) -> str:
    endpoint = endpoint.strip()
    parsed = urlsplit(endpoint)
    if parsed.scheme not in ("https", "http") or not parsed.netloc:
        raise ValueError("Informe a URL HTTP(S) completa, terminando em /count")
    if parsed.path.rstrip("/").endswith("/count") is False:
        raise ValueError("Use o output 'count_endpoint', com caminho terminado em /count")
    if parsed.query or parsed.fragment or parsed.username or parsed.password:
        raise ValueError("Use uma URL sem query string, fragmento ou credenciais")
    if parsed.scheme == "http" and parsed.hostname not in ("localhost", "127.0.0.1", "::1"):
        raise ValueError("Para API pública, use HTTPS (HTTP permitido só em localhost)")
    return endpoint


def executar(endpoint: str, repeticoes: int, evidencias_dir: Path, curl_cmd: str) -> bool:
    inicial = datetime.now(timezone.utc)
    evidencias_dir.mkdir(parents=True, exist_ok=True)
    rotulo = inicial.strftime("%Y%m%d-%H%M%S-%f")
    registro: dict = {
        "tarefa": "Sprint 3 - Preparar demonstracao funcional end-to-end",
        "inicio_utc": inicial.isoformat(),
        "tipo": "API HTTP real (o destino informado pode ser local ou AWS)",
        "endpoint": endpoint,
        "ciclos_solicitados": repeticoes,
        "ciclos_validados": 0,
        "status": "falhou",
        "chamadas": [],
    }
    linhas = ["DEMONSTRAÇÃO E2E — Sprint 3", f"Início (UTC): {inicial.isoformat()}",
              f"Endpoint: {endpoint}", f"Ciclos: {repeticoes}", ""]
    sucesso = False

    try:
        primeiro = curl_request(curl_cmd, endpoint, "GET")
        registro["chamadas"].append({"fase": "baseline", **primeiro})
        anterior = primeiro["count"]
        linhas.append(f"GET inicial: HTTP 200 | count={anterior} (sem incremento)")
        print(linhas[-1])

        for ciclo in range(1, repeticoes + 1):
            post = curl_request(curl_cmd, endpoint, "POST")
            registro["chamadas"].append({"ciclo": ciclo, **post})
            linhas.append(f"Ciclo {ciclo}: curl POST -> HTTP 200 | count={post['count']}")
            print(linhas[-1])
            if post["count"] != anterior + 1:
                raise RuntimeError(f"ciclo {ciclo}: POST deveria retornar {anterior + 1}, "
                                   f"mas retornou {post['count']}. "
                                   "Não execute outra demo em paralelo.")

            get = curl_request(curl_cmd, endpoint, "GET")
            registro["chamadas"].append({"ciclo": ciclo, **get})
            linhas.append(f"Ciclo {ciclo}: curl GET  -> HTTP 200 | count={get['count']}")
            print(linhas[-1])
            if get["count"] != post["count"]:
                raise RuntimeError(f"ciclo {ciclo}: GET retornou {get['count']}; "
                                   f"esperado {post['count']} (GET não pode incrementar)")
            anterior = get["count"]
            registro["ciclos_validados"] = ciclo

        confirmacao = curl_request(curl_cmd, endpoint, "GET")
        registro["chamadas"].append({"fase": "verificacao-final", **confirmacao})
        if confirmacao["count"] != anterior:
            raise RuntimeError("GET final alterou o contador; GET precisa ser somente leitura")
        linhas.append(f"GET final: HTTP 200 | count={confirmacao['count']} (permaneceu igual)")
        linhas.append(f"APROVADO: {repeticoes} ciclos completos; incremento líquido = {repeticoes}.")
        registro["status"] = "aprovado"
        registro["contagem_inicial"] = primeiro["count"]
        registro["contagem_final"] = confirmacao["count"]
        sucesso = True
    except (OSError, RuntimeError) as exc:
        registro["erro"] = str(exc)
        linhas.append(f"REPROVADO: {exc}")
    finally:
        registro["fim_utc"] = datetime.now(timezone.utc).isoformat()
        arquivo_json = evidencias_dir / f"demo-{rotulo}.json"
        arquivo_txt = evidencias_dir / f"demo-{rotulo}.txt"
        arquivo_json.write_text(json.dumps(registro, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        arquivo_txt.write_text("\n".join(linhas) + "\n", encoding="utf-8")
        print("\n" + linhas[-1])
        print(f"Evidências: {arquivo_json} e {arquivo_txt}")
    return sucesso


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Demo E2E: curl POST/GET, mínimo 3 ciclos")
    parser.add_argument("--url", required=True, help="Output count_endpoint do Terraform (/count)")
    parser.add_argument("--cycles", type=int, default=3, help="Mínimo 3 (padrão: 3)")
    parser.add_argument("--evidence-dir", type=Path, default=Path("evidencias/demo"),
                        help="Pasta de evidências locais (não versionadas)")
    args = parser.parse_args(argv)
    if args.cycles < 3 or args.cycles > 100:
        parser.error("--cycles deve estar entre 3 e 100")
    try:
        endpoint = validar_url(args.url)
    except ValueError as exc:
        parser.error(str(exc))
    curl_cmd = shutil.which("curl.exe" if sys.platform == "win32" else "curl")
    if not curl_cmd:
        parser.error("curl não encontrado. No Windows, verifique curl.exe no PATH")
    return 0 if executar(endpoint, args.cycles, args.evidence_dir, curl_cmd) else 1


if __name__ == "__main__":
    sys.exit(main())
