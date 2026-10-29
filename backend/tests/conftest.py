import os
import sys
from pathlib import Path

# O handler lê TABLE_NAME e cria o cliente boto3 no momento do import,
# por isso as variáveis precisam existir antes de qualquer teste importá-lo.
os.environ["TABLE_NAME"] = "tabela-de-teste"
os.environ["ALLOWED_ORIGIN"] = "https://site-de-teste.example"
os.environ["AWS_DEFAULT_REGION"] = "us-east-1"   # o boto3 exige região para criar o cliente
os.environ["AWS_ACCESS_KEY_ID"] = "teste"        # credenciais falsas: se algum teste esquecer o
os.environ["AWS_SECRET_ACCESS_KEY"] = "teste"    # dublê, nada chega à conta real
os.environ["AWS_EC2_METADATA_DISABLED"] = "true"  # o boto3 não procura credenciais no IMDS

# Variáveis da máquina de quem roda os testes não podem interferir (perfil, token ou endpoint reais).
for _nome in ("AWS_PROFILE", "AWS_SESSION_TOKEN", "AWS_ENDPOINT_URL", "COUNTER_ID"):
    os.environ.pop(_nome, None)

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "contador"))
