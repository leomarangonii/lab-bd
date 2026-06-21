const express = require("express");
const pool = require("./db");
const { requireAuth, requireRole, mapDbError } = require("./auth");

const router = express.Router();

// Todas as rotas deste arquivo exigem usuario autenticado do tipo Piloto.
router.use(requireAuth, requireRole("Piloto"));

// GET /api/driver/dashboard
// A funcao retorna o detalhamento por ano e circuito; nao agrupamos no backend.
router.get("/dashboard", async (req, res) => {
  const driverId = req.session.user.idOriginal;

  try {
    const result = await pool.query("SELECT * FROM driver_dashboard($1)", [driverId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Piloto não encontrado." });
    }

    return res.json({ success: true, data: result.rows });
  } catch (err) {
    const { status, message } = mapDbError(err);
    return res.status(status).json({ success: false, message });
  }
});

// GET /api/driver/reports/points
router.get("/reports/points", async (req, res) => {
  const driverId = req.session.user.idOriginal;

  try {
    const result = await pool.query("SELECT * FROM report_driver_points_by_year_race($1)", [driverId]);
    return res.json({ success: true, data: result.rows });
  } catch (err) {
    const { status, message } = mapDbError(err);
    return res.status(status).json({ success: false, message });
  }
});

// GET /api/driver/reports/status
router.get("/reports/status", async (req, res) => {
  const driverId = req.session.user.idOriginal;

  try {
    const result = await pool.query("SELECT * FROM report_driver_status_count($1)", [driverId]);
    return res.json({ success: true, data: result.rows });
  } catch (err) {
    const { status, message } = mapDbError(err);
    return res.status(status).json({ success: false, message });
  }
});

module.exports = router;
