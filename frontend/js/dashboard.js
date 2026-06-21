// Controlador da tela de dashboard. Carrega o conteudo conforme o tipo do usuario.

document.addEventListener("DOMContentLoaded", async () => {
  const content = document.getElementById("dashboard-content");
  try {
    const user = await initAuthenticatedPage();
    renderWelcome(user);

    if (user.tipo === "Admin") {
      await loadAdminDashboard();
    } else if (user.tipo === "Escuderia") {
      await loadConstructorDashboard();
    } else if (user.tipo === "Piloto") {
      await loadDriverDashboard();
    } else {
      showError(content, "Tipo de usuário não reconhecido.");
    }
  } catch (err) {
    showError(content, err.message);
  }
});

function renderWelcome(user) {
  const summary = document.getElementById("user-summary");
  summary.innerHTML = `
    <div class="rounded-xl bg-white p-6 shadow-sm">
      <h2 class="text-2xl font-bold text-gray-900">Olá, ${escapeHtml(user.nomeExibicao)}</h2>
      <p class="text-gray-500">Painel do tipo ${escapeHtml(tipoLabel(user.tipo))}.</p>
    </div>
  `;
}

function grid(cardsHtml) {
  return `<div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">${cardsHtml.join("")}</div>`;
}

function sectionTitle(text) {
  return `<h3 class="mt-2 text-lg font-semibold text-gray-800">${escapeHtml(text)}</h3>`;
}

/* ================================================================== */
/* Dashboard do Administrador                                          */
/* ================================================================== */
async function loadAdminDashboard() {
  const content = document.getElementById("dashboard-content");
  showLoading(content);

  const resposta = await apiRequest("/admin/dashboard");
  const { summary, races, constructors, drivers } = resposta.data;

  const cards = grid([
    createCard("Pilotos cadastrados", formatNumber(summary.total_pilotos)),
    createCard("Escuderias cadastradas", formatNumber(summary.total_escuderias)),
    createCard("Temporadas", formatNumber(summary.total_temporadas))
  ]);

  const tabelaCorridas = createTable(
    [
      { label: "Temporada", key: "temporada", format: formatYear },
      { label: "Corrida", key: "corrida" },
      { label: "Circuito", key: "circuito" },
      { label: "Data", key: "data_corrida", format: formatDate },
      { label: "Horário", key: "horario", format: (v) => (v ? escapeHtml(v) : "-") },
      { label: "Voltas", key: "voltas_registradas", format: formatNumber }
    ],
    races
  );

  const tabelaEscuderias = createTable(
    [
      { label: "Escuderia", key: "escuderia" },
      { label: "Pontos", key: "total_pontos", format: formatNumber }
    ],
    constructors
  );

  const tabelaPilotos = createTable(
    [
      { label: "Piloto", key: "piloto" },
      { label: "Escuderia mais recente", key: "escuderia_mais_recente" },
      { label: "Pontos", key: "total_pontos", format: formatNumber }
    ],
    drivers
  );

  content.innerHTML = `
    ${cards}
    ${sectionTitle("Corridas da temporada mais recente")}
    ${tabelaCorridas}
    ${sectionTitle("Escuderias da temporada mais recente")}
    ${tabelaEscuderias}
    ${sectionTitle("Pilotos da temporada mais recente")}
    ${tabelaPilotos}
  `;

  await renderAdminActions();
}

async function renderAdminActions() {
  const actions = document.getElementById("available-actions");
  showLoading(actions);

  let countries = [];
  try {
    const response = await apiRequest("/admin/countries");
    countries = response.data || [];
  } catch (err) {
    showError(actions, `Não foi possível carregar os países: ${err.message}`);
    return;
  }

  const countryOptions = renderCountryOptions(countries);

  actions.innerHTML = `
    <div class="flex flex-wrap gap-3">
      <button id="btn-form-constructor" class="rounded-lg bg-red-600 px-4 py-2 font-semibold text-white hover:bg-red-700">Cadastrar Escuderia</button>
      <button id="btn-form-driver" class="rounded-lg bg-red-600 px-4 py-2 font-semibold text-white hover:bg-red-700">Cadastrar Piloto</button>
      <a href="reports.html" class="rounded-lg bg-gray-900 px-4 py-2 font-semibold text-white hover:bg-red-600">Acessar Relatórios</a>
    </div>

    <div id="form-constructor" class="mt-4 hidden rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <h3 class="mb-4 text-lg font-semibold text-gray-800">Cadastrar Escuderia</h3>
      <form id="constructor-form" class="grid gap-4 sm:grid-cols-2">
        ${field("c-ref", "Referência", "text", true)}
        ${field("c-name", "Nome", "text", true)}
        ${selectField("c-country", "País", true, countryOptions)}
        ${field("c-wiki", "URL da Wikipédia", "url", false)}
        <div class="sm:col-span-2">
          <button type="submit" class="rounded-lg bg-red-600 px-4 py-2 font-semibold text-white hover:bg-red-700 disabled:opacity-60">Salvar Escuderia</button>
        </div>
      </form>
      <div id="constructor-msg" class="mt-3" aria-live="polite"></div>
    </div>

    <div id="form-driver" class="mt-4 hidden rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <h3 class="mb-4 text-lg font-semibold text-gray-800">Cadastrar Piloto</h3>
      <form id="driver-form" class="grid gap-4 sm:grid-cols-2">
        ${field("d-ref", "Referência", "text", true)}
        ${field("d-given", "Nome", "text", true)}
        ${field("d-family", "Sobrenome", "text", true)}
        ${field("d-birth", "Data de nascimento", "date", true, `max="${new Date().toISOString().slice(0, 10)}"`)}
        ${selectField("d-country", "País", true, countryOptions)}
        <div class="sm:col-span-2">
          <button type="submit" class="rounded-lg bg-red-600 px-4 py-2 font-semibold text-white hover:bg-red-700 disabled:opacity-60">Salvar Piloto</button>
        </div>
      </form>
      <div id="driver-msg" class="mt-3" aria-live="polite"></div>
    </div>
  `;

  toggle("btn-form-constructor", "form-constructor");
  toggle("btn-form-driver", "form-driver");

  setupConstructorForm();
  setupDriverForm();
}

function renderCountryOptions(countries) {
  const options = countries.map((country) => {
    const code = country.code ? ` (${country.code})` : "";
    return `<option value="${Number(country.id)}">${escapeHtml(`${country.name}${code}`)}</option>`;
  });

  return `<option value="">Selecione um país</option>${options.join("")}`;
}

// Campo de formulario com label associado.
function field(id, label, type, required, extra = "") {
  return `
    <div>
      <label for="${id}" class="block text-sm font-semibold text-gray-700">${escapeHtml(label)}</label>
      <input id="${id}" name="${id}" type="${type}" ${required ? "required" : ""} ${extra}
        class="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2 focus:border-red-500 focus:outline-none focus:ring-2 focus:ring-red-200">
    </div>
  `;
}

function selectField(id, label, required, optionsHtml) {
  return `
    <div>
      <label for="${id}" class="block text-sm font-semibold text-gray-700">${escapeHtml(label)}</label>
      <select id="${id}" name="${id}" ${required ? "required" : ""}
        class="mt-1 w-full rounded-lg border border-gray-300 bg-white px-3 py-2 focus:border-red-500 focus:outline-none focus:ring-2 focus:ring-red-200">
        ${optionsHtml}
      </select>
    </div>
  `;
}

function toggle(buttonId, panelId) {
  document.getElementById(buttonId).addEventListener("click", () => {
    document.getElementById(panelId).classList.toggle("hidden");
  });
}

function setupConstructorForm() {
  const form = document.getElementById("constructor-form");
  const msg = document.getElementById("constructor-msg");

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    clearElement(msg);

    const countryRaw = form["c-country"].value;
    const payload = {
      constructorRef: form["c-ref"].value.trim(),
      name: form["c-name"].value.trim(),
      countryId: countryRaw ? Number(countryRaw) : null,
      wikipediaUrl: form["c-wiki"].value.trim() || null
    };

    if (!Number.isInteger(payload.countryId) || payload.countryId <= 0) {
      showError(msg, "Selecione um país.");
      return;
    }

    const button = form.querySelector("button[type='submit']");
    button.disabled = true;
    try {
      const r = await apiRequest("/admin/constructors", { method: "POST", body: JSON.stringify(payload) });
      showSuccess(msg, `Escuderia cadastrada com sucesso (código ${r.data.id}).`);
      form.reset();
    } catch (err) {
      showError(msg, err.message);
    } finally {
      button.disabled = false;
    }
  });
}

function setupDriverForm() {
  const form = document.getElementById("driver-form");
  const msg = document.getElementById("driver-msg");

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    clearElement(msg);

    const countryRaw = form["d-country"].value;
    const payload = {
      driverRef: form["d-ref"].value.trim(),
      givenName: form["d-given"].value.trim(),
      familyName: form["d-family"].value.trim(),
      dateOfBirth: form["d-birth"].value,
      countryId: countryRaw ? Number(countryRaw) : null
    };

    if (!payload.dateOfBirth) {
      showError(msg, "A data de nascimento é obrigatória.");
      return;
    }

    if (payload.dateOfBirth > new Date().toISOString().slice(0, 10)) {
      showError(msg, "A data de nascimento não pode ser futura.");
      return;
    }

    if (!Number.isInteger(payload.countryId) || payload.countryId <= 0) {
      showError(msg, "Selecione um país.");
      return;
    }

    const button = form.querySelector("button[type='submit']");
    button.disabled = true;
    try {
      const r = await apiRequest("/admin/drivers", { method: "POST", body: JSON.stringify(payload) });
      showSuccess(msg, `Piloto cadastrado com sucesso (código ${r.data.id}).`);
      form.reset();
    } catch (err) {
      showError(msg, err.message);
    } finally {
      button.disabled = false;
    }
  });
}

/* ================================================================== */
/* Dashboard da Escuderia                                              */
/* ================================================================== */
async function loadConstructorDashboard() {
  const content = document.getElementById("dashboard-content");
  showLoading(content);

  const resposta = await apiRequest("/constructor/dashboard");
  const d = resposta.data;

  content.innerHTML = `
    ${grid([
      createCard("Escuderia", d.escuderia),
      createCard("Vitórias", formatNumber(d.quantidade_vitorias)),
      createCard("Pilotos", formatNumber(d.quantidade_pilotos)),
      createCard("Primeiro ano", formatYear(d.primeiro_ano)),
      createCard("Último ano", formatYear(d.ultimo_ano))
    ])}
  `;

  renderConstructorActions();
}

function renderConstructorActions() {
  const actions = document.getElementById("available-actions");
  actions.innerHTML = `
    <div class="flex flex-wrap gap-3">
      <button id="btn-search" class="rounded-lg bg-red-600 px-4 py-2 font-semibold text-white hover:bg-red-700">Consultar Piloto por Sobrenome</button>
      <button id="btn-upload" class="rounded-lg bg-red-600 px-4 py-2 font-semibold text-white hover:bg-red-700">Inserir Pilotos por Arquivo</button>
      <a href="reports.html" class="rounded-lg bg-gray-900 px-4 py-2 font-semibold text-white hover:bg-red-600">Acessar Relatórios</a>
    </div>

    <div id="panel-search" class="mt-4 hidden rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <h3 class="mb-4 text-lg font-semibold text-gray-800">Consultar Piloto por Sobrenome</h3>
      <form id="search-form" class="flex flex-col gap-3 md:flex-row">
        <div class="flex-1">
          <label for="s-family" class="block text-sm font-semibold text-gray-700">Sobrenome</label>
          <input id="s-family" name="s-family" type="text" required
            class="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2 focus:border-red-500 focus:outline-none focus:ring-2 focus:ring-red-200">
        </div>
        <div class="flex items-end">
          <button type="submit" class="rounded-lg bg-red-600 px-4 py-2 font-semibold text-white hover:bg-red-700 disabled:opacity-60">Buscar</button>
        </div>
      </form>
      <div id="search-result" class="mt-4" aria-live="polite"></div>
    </div>

    <div id="panel-upload" class="mt-4 hidden rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <h3 class="mb-2 text-lg font-semibold text-gray-800">Inserir Pilotos por Arquivo (CSV)</h3>
      <p class="mb-3 text-sm text-gray-500">Formato esperado:</p>
      <pre class="mb-4 overflow-x-auto rounded-lg bg-gray-100 p-3 text-xs text-gray-700">driver_ref,given_name,family_name,date_of_birth,country_id
novo_piloto,Novo,Piloto,2000-01-01,30</pre>
      <form id="upload-form">
        <div class="rounded-xl border-2 border-dashed border-gray-300 bg-white p-6">
          <label for="csv-file" class="block text-sm font-semibold text-gray-700">Arquivo CSV</label>
          <input id="csv-file" name="csv-file" type="file" accept=".csv" required class="mt-3 block w-full text-sm text-gray-600">
        </div>
        <button type="submit" class="mt-4 rounded-lg bg-red-600 px-4 py-2 font-semibold text-white hover:bg-red-700 disabled:opacity-60">Enviar Arquivo</button>
      </form>
      <div id="upload-result" class="mt-4" aria-live="polite"></div>
    </div>
  `;

  toggle("btn-search", "panel-search");
  toggle("btn-upload", "panel-upload");

  setupSearchForm();
  setupUploadForm();
}

function setupSearchForm() {
  const form = document.getElementById("search-form");
  const result = document.getElementById("search-result");

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const familyName = form["s-family"].value.trim();
    if (!familyName) {
      showError(result, "Informe o sobrenome.");
      return;
    }

    showLoading(result);
    try {
      const r = await apiRequest(`/constructor/drivers/search?familyName=${encodeURIComponent(familyName)}`);
      result.innerHTML = createTable(
        [
          { label: "Nome completo", key: "nome_completo" },
          { label: "Data de nascimento", key: "data_nascimento", format: formatDate },
          { label: "País / Nacionalidade", key: "pais_ou_nacionalidade" }
        ],
        r.data
      );
    } catch (err) {
      showError(result, err.message);
    }
  });
}

function setupUploadForm() {
  const form = document.getElementById("upload-form");
  const result = document.getElementById("upload-result");

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const input = document.getElementById("csv-file");
    if (!input.files || input.files.length === 0) {
      showError(result, "Selecione um arquivo CSV.");
      return;
    }

    const formData = new FormData();
    formData.append("file", input.files[0]);

    const button = form.querySelector("button[type='submit']");
    button.disabled = true;
    showLoading(result);
    try {
      const r = await apiRequest("/constructor/drivers/upload", { method: "POST", body: formData });
      const d = r.data;

      const cards = grid([
        createCard("Total de linhas", formatNumber(d.total)),
        createCard("Inseridas", formatNumber(d.inseridos.length)),
        createCard("Com erro", formatNumber(d.falharam.length))
      ]);

      const linhas = [
        ...d.inseridos.map((i) => ({ ref: i.driver_ref, situacao: "Inserido", detalhe: `Código ${i.id}` })),
        ...d.falharam.map((f) => ({ ref: f.driver_ref, situacao: "Erro", detalhe: f.motivo }))
      ];

      const tabela = createTable(
        [
          { label: "Referência", key: "ref" },
          { label: "Situação", key: "situacao" },
          { label: "Detalhe", key: "detalhe" }
        ],
        linhas
      );

      result.innerHTML = `${cards}<div class="mt-4">${tabela}</div>`;
      form.reset();
    } catch (err) {
      showError(result, err.message);
    } finally {
      button.disabled = false;
    }
  });
}

/* ================================================================== */
/* Dashboard do Piloto                                                 */
/* ================================================================== */
async function loadDriverDashboard() {
  const content = document.getElementById("dashboard-content");
  showLoading(content);

  const resposta = await apiRequest("/driver/dashboard");
  const linhas = resposta.data;

  if (!linhas || linhas.length === 0) {
    content.innerHTML = `<p class="rounded-lg border border-gray-200 bg-white p-4 text-gray-500">Nenhum desempenho registrado para este piloto.</p>`;
    document.getElementById("available-actions").innerHTML = linkRelatorios();
    return;
  }

  const base = linhas[0];
  const desempenho = linhas.filter((linha) => linha.ano !== null && linha.ano !== undefined);

  const cards = grid([
    createCard("Piloto", base.piloto),
    createCard("Escuderia mais recente", base.escuderia_mais_recente || "-"),
    createCard("Primeiro ano", formatYear(base.primeiro_ano)),
    createCard("Último ano", formatYear(base.ultimo_ano))
  ]);

  const desempenhoHtml = desempenho.length > 0
    ? createTable(
        [
          { label: "Ano", key: "ano", format: formatYear },
          { label: "Circuito", key: "circuito" },
          { label: "Pontos", key: "pontos", format: formatNumber },
          { label: "Vitórias", key: "vitorias", format: formatNumber },
          { label: "Total de corridas", key: "total_corridas", format: formatNumber }
        ],
        desempenho
      )
    : `<p class="rounded-lg border border-gray-200 bg-white p-4 text-gray-500">Nenhum desempenho registrado para este piloto.</p>`;

  content.innerHTML = `${cards}${sectionTitle("Desempenho por ano e circuito")}${desempenhoHtml}`;
  document.getElementById("available-actions").innerHTML = linkRelatorios();
}

function linkRelatorios() {
  return `<a href="reports.html" class="inline-block rounded-lg bg-gray-900 px-4 py-2 font-semibold text-white hover:bg-red-600">Acessar Relatórios</a>`;
}
