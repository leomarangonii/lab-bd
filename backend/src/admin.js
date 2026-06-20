const express = require("express");
const pool = require("./db");
const { requireAuth, requireRole, mapDbError } = require("./auth");

const router = express.Router();

// Todas as rotas deste arquivo exigem usuario autenticado do tipo Admin.
router.use(requireAuth, requireRole("Admin"));

// GET /api/admin/dashboard
router.get("/dashboard", async (req, res) => {
  try {
    const [counts, races, constructors, drivers] = await Promise.all([
      pool.query("SELECT * FROM p4_admin_counts()"),
      pool.query("SELECT * FROM p4_admin_latest_races()"),
      pool.query("SELECT * FROM p4_admin_latest_constructors_points()"),
      pool.query("SELECT * FROM p4_admin_latest_drivers_points()")
    ]);

    return res.json({
      success: true,
      data: {
        summary: counts.rows[0] || {},
        races: races.rows,
        constructors: constructors.rows,
        drivers: drivers.rows
      }
    });
  } catch (err) {
    const { status, message } = mapDbError(err);
    return res.status(status).json({ success: false, message });
  }
});

// POST /api/admin/constructors
// A trigger tr_p4_sync_constructor_user cria o usuario da escuderia automaticamente.
router.post("/constructors", async (req, res) => {
  const { constructorRef, name, countryId, wikipediaUrl } = req.body;

  if (!constructorRef || !name || !countryId) {
    return res.status(400).json({ success: false, message: "constructorRef, name e countryId são obrigatórios." });
  }

  try {
    const result = await pool.query(
      "SELECT p4_create_constructor($1, $2, $3, $4) AS id",
      [constructorRef, name, countryId, wikipediaUrl || null]
    );
    return res.status(201).json({ success: true, data: { id: result.rows[0].id } });
  } catch (err) {
    const { status, message } = mapDbError(err);
    return res.status(status).json({ success: false, message });
  }
});

// POST /api/admin/drivers
// A trigger tr_p4_sync_driver_user cria o usuario do piloto automaticamente.
router.post("/drivers", async (req, res) => {
  const { driverRef, givenName, familyName, dateOfBirth, countryId } = req.body;

  if (!driverRef || !givenName || !familyName || !dateOfBirth || !countryId) {
    return res.status(400).json({ success: false, message: "driverRef, givenName, familyName, dateOfBirth e countryId são obrigatórios." });
  }

  if (dateOfBirth > new Date().toISOString().slice(0, 10)) {
    return res.status(400).json({ success: false, message: "dateOfBirth não pode ser uma data futura." });
  }

  try {
    const result = await pool.query(
      "SELECT p4_create_driver($1, $2, $3, $4, $5) AS id",
      [driverRef, givenName, familyName, dateOfBirth, countryId]
    );
    return res.status(201).json({ success: true, data: { id: result.rows[0].id } });
  } catch (err) {
    const { status, message } = mapDbError(err);
    return res.status(status).json({ success: false, message });
  }
});

// GET /api/admin/reports/status  (Relatorio 1)
router.get("/reports/status", async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM p4_report_admin_status_count()");
    return res.json({ success: true, data: result.rows });
  } catch (err) {
    const { status, message } = mapDbError(err);
    return res.status(status).json({ success: false, message });
  }
});

// GET /api/admin/reports/airports?city=São Carlos  (Relatorio 2)
router.get("/reports/airports", async (req, res) => {
  const city = req.query.city;

  if (!city) {
    return res.status(400).json({ success: false, message: "Parâmetro city é obrigatório." });
  }

  try {
    const result = await pool.query(
      "SELECT * FROM p4_report_admin_airports_near_city($1)",
      [city]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Nenhum aeroporto encontrado para a cidade informada." });
    }

    return res.json({ success: true, data: result.rows });
  } catch (err) {
    const { status, message } = mapDbError(err);
    return res.status(status).json({ success: false, message });
  }
});

// GET /api/admin/reports/report-3  (Relatorio 3)
// Nao existe funcao agregadora no SQL; combinamos as 4 funcoes tabulares num unico JSON.
router.get("/reports/report-3", async (req, res) => {
  try {
    const [constructors, racesTotal, byCircuit, raceDetails] = await Promise.all([
      pool.query("SELECT * FROM p4_report_admin_constructor_driver_count()"),
      pool.query("SELECT * FROM p4_report_admin_races_total()"),
      pool.query("SELECT * FROM p4_report_admin_races_by_circuit()"),
      pool.query("SELECT * FROM p4_report_admin_race_details()")
    ]);

    return res.json({
      success: true,
      data: {
        constructors: constructors.rows,
        racesTotal: racesTotal.rows[0] ? Number(racesTotal.rows[0].quantidade_corridas) : 0,
        byCircuit: byCircuit.rows,
        raceDetails: raceDetails.rows
      }
    });
  } catch (err) {
    const { status, message } = mapDbError(err);
    return res.status(status).json({ success: false, message });
  }
});

module.exports = router;
