const express = require("express");
const pool = require("./db");

const router = express.Router();

/* ------------------------------------------------------------------ */
/* Helpers compartilhados                                              */
/* ------------------------------------------------------------------ */

// Traduz um erro do PostgreSQL para um status HTTP e uma mensagem simples.
// 23505 = unique_violation; exceptions RAISE com "ja existe" sao duplicidade.
function mapDbError(err) {
  const msg = (err && err.message) || "";
  if (err && err.code === "23505") {
    return { status: 409, message: "Registro duplicado." };
  }
  if (/j[aá] existe/i.test(msg)) {
    return { status: 409, message: msg };
  }
  return { status: 500, message: "Erro interno no servidor." };
}

// Exige usuario autenticado.
function requireAuth(req, res, next) {
  if (!req.session.user) {
    return res.status(401).json({ success: false, message: "Usuário não autenticado." });
  }
  next();
}

// Exige um tipo especifico (Admin, Escuderia ou Piloto).
function requireRole(role) {
  return function (req, res, next) {
    if (!req.session.user || req.session.user.tipo !== role) {
      return res.status(403).json({ success: false, message: "Acesso não permitido." });
    }
    next();
  };
}

/* ------------------------------------------------------------------ */
/* Rotas de autenticacao                                               */
/* ------------------------------------------------------------------ */

// POST /api/login
router.post("/login", async (req, res) => {
  const { login, password } = req.body;

  if (!login || !password) {
    return res.status(400).json({ success: false, message: "Login e senha são obrigatórios." });
  }

  try {
    const result = await pool.query(
      "SELECT userid, login, tipo, id_original, nome_exibicao FROM authenticate($1, $2)",
      [login, password]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ success: false, message: "Login ou senha inválidos." });
    }

    const row = result.rows[0];

    // Guarda na sessao apenas o necessario. O hash da senha nunca trafega.
    req.session.user = {
      userid: row.userid,
      login: row.login,
      tipo: row.tipo,
      idOriginal: row.id_original,
      nomeExibicao: row.nome_exibicao
    };

    // Registra o acesso no log de usuarios.
    await pool.query("SELECT log_access($1, $2)", [row.userid, "LOGIN"]);

    return res.json({ success: true, data: req.session.user });
  } catch (err) {
    const { status, message } = mapDbError(err);
    return res.status(status).json({ success: false, message });
  }
});

// POST /api/logout
router.post("/logout", requireAuth, async (req, res) => {
  const userid = req.session.user.userid;

  try {
    await pool.query("SELECT log_access($1, $2)", [userid, "LOGOUT"]);

    req.session.destroy(() => {
      res.json({ success: true, data: { message: "Logout realizado com sucesso." } });
    });
  } catch (err) {
    const { status, message } = mapDbError(err);
    return res.status(status).json({ success: false, message });
  }
});

// GET /api/me
router.get("/me", requireAuth, (req, res) => {
  res.json({ success: true, data: req.session.user });
});

module.exports = { router, requireAuth, requireRole, mapDbError };
