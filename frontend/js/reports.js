// Controlador da tela de relatorios. Os botoes mudam conforme o tipo do usuario.

document.addEventListener("DOMContentLoaded", async () => {
  const result = document.getElementById("report-result");
  try {
    const user = await initAuthenticatedPage();
    renderReportButtons(user);
  } catch (err) {
    showError(result, err.message);
  }
});

const buttonClass = "rounded-lg bg-gray-900 px-4 py-2 font-semibold text-white hover:bg-red-600";

function renderReportButtons(user) {
  const container = document.getElementById("report-buttons");
  let botoes = [];

  if (user.tipo === "Admin") {
    botoes = [
      { id: "r1", label: "Relatório 1 — Resultados por Status" },
      { id: "r2", label: "Relatório 2 — Aeroportos Próximos" },
      { id: "r3", label: "Relatório 3 — Escuderias e Corridas" }
    ];
  } else if (user.tipo === "Escuderia") {
    botoes = [
      { id: "r4", label: "Relatório 4 — Vitórias por Piloto" },
      { id: "r5", label: "Relatório 5 — Resultados por Status" }
    ];
  } else if (user.tipo === "Piloto") {
    botoes = [
      { id: "r6", label: "Relatório 6 — Pontos por Ano e Corrida" },
      { id: "r7", label: "Relatório 7 — Resultados por Status" }
    ];
  }

  container.innerHTML = botoes
    .map((b) => `<button data-report="${b.id}" class="${buttonClass}">${escapeHtml(b.label)}</button>`)
    .join("");

  container.querySelectorAll("button[data-report]").forEach((btn) => {
    btn.addEventListener("click", () => runReport(btn.dataset.report));
  });
}

async function runReport(id) {
  const filters = document.getElementById("report-filters");
  const result = document.getElementById("report-result");
  clearElement(filters);
  clearElement(result);

  try {
    switch (id) {
      case "r1":
        return await reportStatus("/admin/reports/status");
      case "r2":
        return reportAirports();
      case "r3":
        return await reportAdmin3();
      case "r4":
        return await reportConstructorWins();
      case "r5":
        return await reportStatus("/constructor/reports/status");
      case "r6":
        return await reportDriverPoints();
      case "r7":
        return await reportStatus("/driver/reports/status");
      default:
        showError(result, "Relatório não reconhecido.");
    }
  } catch (err) {
    showError(result, err.message);
  }
}

// Tabela de status reutilizada por Admin, Escuderia e Piloto.
async function reportStatus(endpoint) {
  const result = document.getElementById("report-result");
  showLoading(result);
  const r = await apiRequest(endpoint);
  result.innerHTML = createTable(
    [
      { label: "Status", key: "status" },
      { label: "Quantidade", key: "quantidade", format: formatNumber }
    ],
    r.data
  );
}

/* ------------------------- Relatorio 2 ---------------------------- */
function reportAirports() {
  const filters = document.getElementById("report-filters");
  const result = document.getElementById("report-result");

  filters.innerHTML = `
    <form id="airport-form" class="flex flex-col gap-3 md:flex-row">
      <div class="flex-1">
        <label for="city" class="block text-sm font-semibold text-gray-700">Cidade</label>
        <input id="city" name="city" type="text" required placeholder="São Carlos"
          class="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2 focus:border-red-500 focus:outline-none focus:ring-2 focus:ring-red-200">
      </div>
      <div class="flex items-end">
        <button type="submit" class="rounded-lg bg-red-600 px-4 py-2 font-semibold text-white hover:bg-red-700 disabled:opacity-60">Pesquisar</button>
      </div>
    </form>
  `;

  document.getElementById("airport-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const city = document.getElementById("city").value.trim();
    if (!city) {
      showError(result, "Informe o nome da cidade.");
      return;
    }

    showLoading(result);
    try {
      const r = await apiRequest(`/admin/reports/airports?city=${encodeURIComponent(city)}`);
      result.innerHTML = createTable(
        [
          { label: "Cidade pesquisada", key: "cidade_pesquisada" },
          { label: "Código IATA", key: "codigo_iata" },
          { label: "Aeroporto", key: "aeroporto" },
          { label: "Cidade do aeroporto", key: "cidade_aeroporto" },
          { label: "Distância (km)", key: "distancia_km", format: formatNumber },
          { label: "Tipo", key: "tipo_aeroporto" }
        ],
        r.data
      );
    } catch (err) {
      showError(result, err.message);
    }
  });
}

/* ------------------------- Relatorio 3 ---------------------------- */
async function reportAdmin3() {
  const result = document.getElementById("report-result");
  showLoading(result);

  const r = await apiRequest("/admin/reports/report-3");
  const d = r.data;

  // ---- Parte 1: todas as escuderias com a respectiva quantidade de pilotos ----
  const secaoEscuderias = createTable(
    [
      { label: "Escuderia", key: "escuderia" },
      { label: "Quantidade de pilotos", key: "quantidade_pilotos", format: formatNumber }
    ],
    d.constructors
  );

  // ---- Parte 2: relatório hierárquico de corridas em três níveis ----
  // Nível 3 (corridas) é agrupado por circuito para ser aninhado sob o nível 2.
  const corridasPorCircuito = {};
  for (const corrida of d.raceDetails) {
    (corridasPorCircuito[corrida.circuito] ||= []).push(corrida);
  }

  // Nível 2 + 3: para cada circuito, os agregados e a tabela aninhada de corridas.
  const circuitos = d.byCircuit
    .map((c) => {
      const corridas = corridasPorCircuito[c.circuito] || [];
      const tabelaCorridas = createTable(
        [
          { label: "Corrida", key: "corrida" },
          { label: "Ano", key: "ano", format: formatYear },
          { label: "Voltas registradas", key: "voltas_registradas", format: formatNumber },
          { label: "Pilotos participantes", key: "quantidade_pilotos", format: formatNumber }
        ],
        corridas
      );

      return `
        <section class="space-y-2">
          <div class="flex flex-wrap items-baseline justify-between gap-2 rounded-lg bg-gray-900 px-4 py-3 text-white">
            <h4 class="text-base font-semibold">${escapeHtml(c.circuito)}</h4>
            <span class="text-sm">
              Corridas: <strong>${formatNumber(c.quantidade_corridas)}</strong> &middot;
              Voltas mín/méd/máx:
              <strong>${formatNumber(c.minimo_voltas)}</strong> /
              <strong>${formatNumber(c.media_voltas)}</strong> /
              <strong>${formatNumber(c.maximo_voltas)}</strong>
            </span>
          </div>
          <div class="pl-2 md:pl-4">${tabelaCorridas}</div>
        </section>
      `;
    })
    .join("");

  result.innerHTML = `
    <h3 class="text-lg font-semibold text-gray-800">Escuderias cadastradas e quantidade de pilotos</h3>
    ${secaoEscuderias}

    <h3 class="mt-8 text-lg font-semibold text-gray-800">Relatório hierárquico de corridas</h3>

    <p class="mt-2 text-sm font-medium text-gray-500">Nível 1 — Total de corridas cadastradas</p>
    <div class="mt-1 max-w-xs">${createCard("Total de corridas", formatNumber(d.racesTotal))}</div>

    <p class="mt-4 text-sm font-medium text-gray-500">
      Nível 2 — Corridas por circuito (voltas mínima/média/máxima) &nbsp;|&nbsp;
      Nível 3 — Corridas de cada circuito (voltas e pilotos participantes)
    </p>
    <div class="mt-2 space-y-6">${circuitos}</div>
  `;
}

/* ------------------------- Relatorio 4 ---------------------------- */
async function reportConstructorWins() {
  const result = document.getElementById("report-result");
  showLoading(result);
  const r = await apiRequest("/constructor/reports/wins");
  result.innerHTML = createTable(
    [
      { label: "Piloto", key: "piloto" },
      { label: "Quantidade de vitórias", key: "quantidade_vitorias", format: formatNumber }
    ],
    r.data
  );
}

/* ------------------------- Relatorio 6 ---------------------------- */
async function reportDriverPoints() {
  const result = document.getElementById("report-result");
  showLoading(result);
  const r = await apiRequest("/driver/reports/points");

  if (!r.data || r.data.length === 0) {
    result.innerHTML = `<p class="rounded-lg border border-gray-200 bg-white p-4 text-gray-500">Nenhum resultado encontrado.</p>`;
    return;
  }

  // Agrupa as linhas por ano, preservando a ordem retornada pela função SQL.
  const anos = [];
  const porAno = {};
  for (const row of r.data) {
    if (!porAno[row.ano]) {
      porAno[row.ano] = { total: row.total_pontos_ano, corridas: [] };
      anos.push(row.ano);
    }
    // corrida nula indica ano de participação sem pontos.
    if (row.corrida) {
      porAno[row.ano].corridas.push(row);
    }
  }

  // Cada ano vira uma seção: cabeçalho com o total e a tabela das corridas pontuadas.
  const secoes = anos
    .map((ano) => {
      const dados = porAno[ano];
      const corpo = dados.corridas.length
        ? createTable(
            [
              { label: "Corrida", key: "corrida" },
              { label: "Circuito", key: "circuito" },
              { label: "Pontos na corrida", key: "pontos_corrida", format: formatNumber }
            ],
            dados.corridas
          )
        : `<p class="rounded-lg border border-gray-200 bg-white p-4 text-gray-500">Nenhuma corrida pontuada neste ano.</p>`;

      return `
        <section class="space-y-2">
          <div class="flex flex-wrap items-baseline justify-between gap-2 rounded-lg bg-gray-900 px-4 py-3 text-white">
            <h3 class="text-lg font-semibold">Ano ${formatYear(ano)}</h3>
            <span class="text-sm">Total de pontos no ano: <strong>${escapeHtml(formatNumber(dados.total))}</strong></span>
          </div>
          ${corpo}
        </section>
      `;
    })
    .join("");

  result.innerHTML = `<div class="space-y-6">${secoes}</div>`;
}
