// Endereco base da API. Toda comunicacao com o banco passa por aqui.
const API_BASE_URL = "http://localhost:3000/api";

// Funcao generica de requisicao. Envia o cookie de sessao com credentials: "include".
async function apiRequest(endpoint, options = {}) {
  const config = {
    credentials: "include",
    ...options
  };

  // Nao definimos Content-Type quando o corpo e FormData (upload de arquivo).
  if (!(options.body instanceof FormData)) {
    config.headers = {
      "Content-Type": "application/json",
      ...(options.headers || {})
    };
  }

  const response = await fetch(`${API_BASE_URL}${endpoint}`, config);

  let data;
  try {
    data = await response.json();
  } catch {
    data = {};
  }

  if (!response.ok) {
    // Sessao expirada ou inexistente: volta para o login.
    if (response.status === 401) {
      window.location.href = "index.html";
    }
    throw new Error(
      data.message ||
      (data.error && data.error.message) ||
      "Erro ao acessar o servidor."
    );
  }

  return data;
}

/* ------------------------------------------------------------------ */
/* Funcoes visuais auxiliares                                          */
/* ------------------------------------------------------------------ */

function clearElement(element) {
  if (element) {
    element.innerHTML = "";
  }
}

function showLoading(container) {
  container.innerHTML = `
    <div class="flex items-center justify-center p-8">
      <div class="h-8 w-8 animate-spin rounded-full border-4 border-gray-300 border-t-red-600"></div>
      <span class="ml-3 text-gray-600">Carregando...</span>
    </div>
  `;
}

function showError(container, message) {
  container.innerHTML = `
    <div class="rounded-lg border border-red-300 bg-red-50 p-4 text-red-700">
      ${escapeHtml(message)}
    </div>
  `;
}

function showSuccess(container, message) {
  container.innerHTML = `
    <div class="rounded-lg border border-green-300 bg-green-50 p-4 text-green-700">
      ${escapeHtml(message)}
    </div>
  `;
}

// Evita injetar HTML cru vindo de dados do banco.
function escapeHtml(value) {
  if (value === null || value === undefined) {
    return "";
  }
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

// Converte uma data (ISO ou Date) para o formato dd/mm/aaaa.
function formatDate(value) {
  if (!value) {
    return "-";
  }
  const date = new Date(value);
  if (isNaN(date.getTime())) {
    return escapeHtml(value);
  }
  return date.toLocaleDateString("pt-BR", { timeZone: "UTC" });
}

// Formata numeros no padrao brasileiro. Strings numericas tambem sao aceitas.
function formatNumber(value) {
  if (value === null || value === undefined || value === "") {
    return "-";
  }
  const number = Number(value);
  if (isNaN(number)) {
    return escapeHtml(value);
  }
  return number.toLocaleString("pt-BR");
}

// Formata anos/temporadas sem separador de milhar (2007, e não 2.007).
function formatYear(value) {
  if (value === null || value === undefined || value === "") {
    return "-";
  }
  const number = Number(value);
  if (isNaN(number)) {
    return escapeHtml(value);
  }
  return String(number);
}

/* Cria uma tabela HTML.
   columns: [{ label, key, format? }]  -> format(valor, linha) opcional
   rows:    array de objetos
*/
function createTable(columns, rows) {
  if (!rows || rows.length === 0) {
    return `<p class="rounded-lg border border-gray-200 bg-white p-4 text-gray-500">Nenhum resultado encontrado.</p>`;
  }

  const head = columns
    .map((c) => `<th class="px-4 py-3 text-left text-sm font-semibold">${escapeHtml(c.label)}</th>`)
    .join("");

  const body = rows
    .map((row) => {
      const cells = columns
        .map((c) => {
          const raw = row[c.key];
          const value = c.format ? c.format(raw, row) : escapeHtml(raw);
          return `<td class="px-4 py-2 text-sm text-gray-800">${value}</td>`;
        })
        .join("");
      return `<tr class="odd:bg-white even:bg-gray-50 hover:bg-red-50">${cells}</tr>`;
    })
    .join("");

  return `
    <div class="overflow-x-auto rounded-lg border border-gray-200 bg-white shadow-sm">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-900 text-white"><tr>${head}</tr></thead>
        <tbody class="divide-y divide-gray-200">${body}</tbody>
      </table>
    </div>
  `;
}

// Cartao de resumo simples (rotulo + valor).
function createCard(label, value) {
  return `
    <article class="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <p class="text-sm font-medium text-gray-500">${escapeHtml(label)}</p>
      <p class="mt-2 text-3xl font-bold text-gray-900">${escapeHtml(value)}</p>
    </article>
  `;
}
