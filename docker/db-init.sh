#!/bin/bash
# ============================================================================
# db-init.sh
# ----------------------------------------------------------------------------
# Executado automaticamente pelo container do PostgreSQL na PRIMEIRA subida
# (quando o volume de dados ainda esta vazio).
#
# Entra na pasta /sql e roda 99_run_all.sql pelo psql. Entrar em /sql faz com
# que os caminhos '../data/...' dos comandos \copy resolvam para /data, que e
# onde os CSV/TSV estao montados.
# ============================================================================
set -e

cd /sql
psql -v ON_ERROR_STOP=1 \
     --username "$POSTGRES_USER" \
     --dbname "$POSTGRES_DB" \
     -f 99_run_all.sql
