// Dados do usuario autenticado, mantidos apenas em memoria (nunca em localStorage).
let currentUser = null;

// Traduz o tipo interno para um texto amigavel.
function tipoLabel(tipo) {
  const mapa = { Admin: "Administrador", Escuderia: "Escuderia", Piloto: "Piloto" };
  return mapa[tipo] || tipo;
}

/* ------------------------------------------------------------------ */
/* Tela de login (index.html)                                          */
/* ------------------------------------------------------------------ */
function initLogin() {
  const form = document.getElementById("login-form");
  if (!form) {
    return;
  }

  const errorBox = document.getElementById("login-error");
  const button = form.querySelector("button[type='submit']");

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    clearElement(errorBox);

    const login = form.login.value.trim();
    const password = form.password.value;

    if (!login || !password) {
      showError(errorBox, "Informe login e senha.");
      return;
    }

    button.disabled = true;
    try {
      await apiRequest("/login", {
        method: "POST",
        body: JSON.stringify({ login, password })
      });
      // A senha nunca e guardada; seguimos direto para o dashboard.
      window.location.href = "dashboard.html";
    } catch (err) {
      showError(errorBox, err.message);
      button.disabled = false;
    }
  });
}

/* ------------------------------------------------------------------ */
/* Paginas autenticadas (dashboard.html, reports.html)                 */
/* ------------------------------------------------------------------ */

// Valida a sessao chamando /api/me. Sem sessao, apiRequest ja redireciona.
async function requireSession() {
  const resposta = await apiRequest("/me");
  currentUser = resposta.data;
  return currentUser;
}

// Preenche o cabecalho com o usuario e liga o botao Sair.
function setupHeader(user) {
  const info = document.getElementById("user-info");
  if (info) {
    info.textContent = `${user.nomeExibicao} — ${tipoLabel(user.tipo)}`;
  }

  const logout = document.getElementById("logout-button");
  if (logout) {
    logout.addEventListener("click", async () => {
      try {
        await apiRequest("/logout", { method: "POST" });
      } catch {
        // Mesmo se o logout falhar no servidor, voltamos ao login.
      }
      window.location.href = "index.html";
    });
  }
}

// Inicializa qualquer pagina autenticada e devolve o usuario logado.
async function initAuthenticatedPage() {
  const user = await requireSession();
  setupHeader(user);
  return user;
}

// Liga o formulario de login automaticamente quando a pagina o possui.
document.addEventListener("DOMContentLoaded", initLogin);
