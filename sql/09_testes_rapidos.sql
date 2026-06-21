/* ============================================================================================================
   09_testes_rapidos.sql - Testes rápidos
   Use para verificar se a base do sistema foi criada corretamente.
   ============================================================================================================ */

SELECT 'Teste autenticação admin' AS teste;
SELECT * FROM authenticate('admin', 'admin');

SELECT 'Contagem usuários por tipo' AS teste;
SELECT tipo, COUNT(*) FROM users GROUP BY tipo ORDER BY tipo;

SELECT 'Dashboard admin - contagens' AS teste;
SELECT * FROM admin_counts();

SELECT 'Dashboard admin - corridas da temporada mais recente' AS teste;
SELECT * FROM admin_latest_races() LIMIT 10;

SELECT 'Relatório admin 1 - status' AS teste;
SELECT * FROM report_admin_status_count() LIMIT 10;

SELECT 'Relatório admin 2 - aeroportos perto de São Carlos' AS teste;
SELECT * FROM report_admin_airports_near_city('São Carlos') LIMIT 10;

SELECT 'Dashboard escuderia - exemplo' AS teste;
SELECT *
FROM constructor_dashboard((SELECT id FROM constructors ORDER BY id LIMIT 1));

SELECT 'Dashboard piloto - exemplo' AS teste;
SELECT *
FROM driver_dashboard((SELECT id FROM drivers ORDER BY id LIMIT 1))
LIMIT 10;

SELECT 'Relatório escuderia - vitórias por piloto' AS teste;
SELECT *
FROM report_constructor_driver_wins((SELECT id FROM constructors ORDER BY id LIMIT 1))
LIMIT 10;

SELECT 'Relatório piloto - pontos por ano/corrida' AS teste;
SELECT *
FROM report_driver_points_by_year_race((SELECT id FROM drivers ORDER BY id LIMIT 1))
LIMIT 10;
