/* ============================================================================================================
   99_run_all.sql
   ------------------------------------------------------------------------------------------------------------
   Executa os scripts na ordem correta.

   Uso recomendado:
       cd p4_bd_schema_normalizado_csv/sql
       psql -d f1db -f 99_run_all.sql
   ============================================================================================================ */

\set ON_ERROR_STOP on

\echo '01 - Criando todas as tabelas...'
\ir 01_schema_tabelas.sql

\echo '02 - Carregando dados CSV/TSV...'
\ir 02_carga_csv.sql

\echo '03 - Aplicando métricas e deduplicação do T1...'
\ir 03_t1_deduplicacao_metricas.sql

\echo '04 - Criando views...'
\ir 04_views.sql

\echo '05 - Criando functions/procedures...'
\ir 05_functions.sql

\echo '06 - Carregando usuários iniciais...'
\ir 06_seed_users.sql

\echo '07 - Criando triggers...'
\ir 07_triggers.sql

\echo '08 - Criando índices...'
\ir 08_indices.sql

\echo '09 - Rodando testes rápidos...'
\ir 09_testes_rapidos.sql

\echo 'Base do P4 montada com sucesso.'
