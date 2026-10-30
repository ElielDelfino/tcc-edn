"use strict";

const $ = (id) => document.getElementById(id);
const fmt = new Intl.NumberFormat("pt-BR");

function apiUrl() {
  const url = window.CONTADOR_API_URL;
  if (typeof url !== "string" || !url.trim() || url === "COLE_A_URL_AQUI") {
    throw new Error("A URL da API não está configurada.");
  }
  return url.trim();
}

function mensagemErro(status) {
  if (status === 403) return "Endereço da API incorreto.";
  if (status === 404) return "A rota da API não foi encontrada.";
  if (status === 429) return "Muitas requisições. Tente de novo.";
  if (status === 500) return "O servidor não conseguiu acessar o banco.";
  if (status) return `Não foi possível obter o total (HTTP ${status}).`;
  return "Não foi possível falar com a API.";
}

function setStatus(kind, text) {
  const el = $("status");
  el.className = "status" + (kind ? " " + kind : "");
  el.textContent = text;
}

function showCount(n) {
  $("count").textContent = fmt.format(n);
}

function setBusy(busy) {
  const btn = $("btn-atualizar");
  btn.disabled = busy;
  btn.setAttribute("aria-busy", busy ? "true" : "false");
}

async function chamar(metodo) {
  const resposta = await fetch(apiUrl(), {
    method: metodo,
    cache: "no-store",
    headers: metodo === "POST" ? { "Content-Type": "application/json" } : {},
  });
  if (!resposta.ok) {
    throw new Error(mensagemErro(resposta.status));
  }
  const dados = await resposta.json();
  if (typeof dados.count !== "number") {
    throw new Error("A API não devolveu o total esperado.");
  }
  return dados.count;
}

async function executar(metodo) {
  setBusy(true);
  setStatus("", "");
  try {
    const total = await chamar(metodo);
    showCount(total);
    setStatus(
      "ok",
      metodo === "POST"
        ? `Acesso registrado. Total: ${fmt.format(total)}.`
        : `Total atualizado, sem incrementar: ${fmt.format(total)}.`,
    );
  } catch (erro) {
    const rede = erro instanceof TypeError;
    setStatus("err", rede ? mensagemErro(0) : erro.message);
  } finally {
    setBusy(false);
  }
}

document.addEventListener("DOMContentLoaded", () => {
  $("btn-atualizar").addEventListener("click", () => executar("GET"));
  executar("POST");
});
