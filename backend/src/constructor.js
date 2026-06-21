const express = require("express");
const fs = require("fs");
const path = require("path");
const multer = require("multer");
const { parse } = require("csv-parse/sync");
const pool = require("./db");
const { requireAuth, requireRole, mapDbError } = require("./auth");

const router = express.Router();

// Todas as rotas deste arquivo exigem usuario autenticado do tipo Escuderia.
router.use(requireAuth, requireRole("Escuderia"));

// Pasta temporaria para os CSVs enviados. O arquivo e apagado apos o processamento.
const uploadDir = path.join(__dirname, "..", "uploads");
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}
const upload = multer({ dest: uploadDir });

// Colunas esperadas no CSV de pilotos.
const REQUIRED_COLUMNS = ["driver_ref", "given_name", "family_name", "date_of_birth", "country_id"];

function normalizeCsvHeader(header) {
  return String(header || "")
    .replace(/^\uFEFF/, "")
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, "_");
}

function requireText(value, columnName) {
  const text = String(value || "").trim();
  if (!text) {
    throw new Error(`${columnName} é obrigatório.`);
  }
  return text;
}

function parseRequiredPastDate(value, columnName) {
  const text = requireText(value, columnName);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) {
    throw new Error(`${columnName} deve estar no formato YYYY-MM-DD.`);
  }

  const [year, month, day] = text.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  const isValid =
    date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day;
  if (!isValid) {
    throw new Error(`${columnName} possui uma data inválida.`);
  }

  const today = new Date();
  const todayUtc = new Date(Date.UTC(today.getFullYear(), today.getMonth(), today.getDate()));
  if (date > todayUtc) {
    throw new Error(`${columnName} não pode ser uma data futura.`);
  }

  return text;
}

// GET /api/constructor/dashboard
router.get("/dashboard", async (req, res) => {
  const constructorId = req.session.user.idOriginal;

  try {
    const result = await pool.query("SELECT * FROM constructor_dashboard($1)", [constructorId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Escuderia não encontrada." });
    }

    return res.json({ success: true, data: result.rows[0] });
  } catch (err) {
    const { status, message } = mapDbError(err);
    return res.status(status).json({ success: false, message });
  }
});

// GET /api/constructor/drivers/search?familyName=Hamilton
// Retorna apenas pilotos que ja correram pela escuderia autenticada.
router.get("/drivers/search", async (req, res) => {
  const constructorId = req.session.user.idOriginal;
  const familyName = req.query.familyName;

  if (!familyName) {
    return res.status(400).json({ success: false, message: "Parâmetro familyName é obrigatório." });
  }

  try {
    const result = await pool.query(
      "SELECT * FROM constructor_find_driver_by_family_name($1, $2)",
      [constructorId, familyName]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Nenhum piloto encontrado para essa escuderia." });
    }

    return res.json({ success: true, data: result.rows });
  } catch (err) {
    const { status, message } = mapDbError(err);
    return res.status(status).json({ success: false, message });
  }
});

// POST /api/constructor/drivers/upload  (campo "file" com um CSV)
router.post("/drivers/upload", upload.single("file"), async (req, res) => {
  const constructorId = req.session.user.idOriginal;

  if (!req.file) {
    return res.status(400).json({ success: false, message: "Arquivo CSV é obrigatório no campo 'file'." });
  }

  try {
    const content = fs.readFileSync(req.file.path, "utf8");
    const rows = parse(content, {
      bom: true,
      columns: (headers) => headers.map(normalizeCsvHeader),
      skip_empty_lines: true,
      trim: true
    });

    // Valida se as cinco colunas existem no cabecalho.
    const header = rows.length > 0 ? Object.keys(rows[0]) : [];
    const missing = REQUIRED_COLUMNS.filter((c) => !header.includes(c));
    if (missing.length > 0) {
      return res.status(400).json({
        success: false,
        message: "Colunas ausentes no CSV: " + missing.join(", ")
      });
    }

    const inseridos = [];
    const falharam = [];

    // Para cada linha chamamos a funcao SQL que cria o piloto e o vincula a escuderia.
    for (const row of rows) {
      try {
        const driverRef = requireText(row.driver_ref, "driver_ref");
        const givenName = requireText(row.given_name, "given_name");
        const familyName = requireText(row.family_name, "family_name");
        const dateOfBirth = parseRequiredPastDate(row.date_of_birth, "date_of_birth");
        const countryId = Number(row.country_id);
        if (!Number.isInteger(countryId) || countryId <= 0) {
          throw new Error("country_id é obrigatório e deve ser um número positivo.");
        }

        const result = await pool.query(
          "SELECT create_driver_for_constructor($1, $2, $3, $4, $5, $6) AS id",
          [
            constructorId,
            driverRef,
            givenName,
            familyName,
            dateOfBirth,
            countryId
          ]
        );
        inseridos.push({ driver_ref: driverRef, id: result.rows[0].id });
      } catch (err) {
        falharam.push({ driver_ref: row.driver_ref || "-", motivo: err.message });
      }
    }

    return res.json({
      success: true,
      data: {
        total: rows.length,
        inseridos,
        falharam
      }
    });
  } catch (err) {
    const { status, message } = mapDbError(err);
    return res.status(status).json({ success: false, message });
  } finally {
    // Remove o arquivo temporario em qualquer cenario.
    fs.unlink(req.file.path, () => {});
  }
});

// GET /api/constructor/reports/wins
router.get("/reports/wins", async (req, res) => {
  const constructorId = req.session.user.idOriginal;

  try {
    const result = await pool.query("SELECT * FROM report_constructor_driver_wins($1)", [constructorId]);
    return res.json({ success: true, data: result.rows });
  } catch (err) {
    const { status, message } = mapDbError(err);
    return res.status(status).json({ success: false, message });
  }
});

// GET /api/constructor/reports/status
router.get("/reports/status", async (req, res) => {
  const constructorId = req.session.user.idOriginal;

  try {
    const result = await pool.query("SELECT * FROM report_constructor_status_count($1)", [constructorId]);
    return res.json({ success: true, data: result.rows });
  } catch (err) {
    const { status, message } = mapDbError(err);
    return res.status(status).json({ success: false, message });
  }
});

module.exports = router;
