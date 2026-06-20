# Projeto Final — Laboratório de Bases de Dados (SCC-241)

Aplicação web sobre uma base de Fórmula 1 (FIA) com cidades e aeroportos do mundo.
A regra de negócio fica nas **funções SQL** do PostgreSQL; o backend Node/Express é
uma camada fina que chama essas funções com consultas parametrizadas; o frontend é
HTML + Tailwind + JavaScript puro.

```
Navegador  ──►  Frontend (HTML/JS, :5500)  ──►  Backend (Node/Express, :3000)  ──►  PostgreSQL (:5432)
```

## Estrutura

```text
.
├── data/            # CSV/TSV de origem (pilotos, corridas, cidades, aeroportos, ...)
├── sql/             # Scripts do banco, na ordem de execução (99_run_all.sql roda todos)
├── backend/         # API Node/Express (pasta src/)
├── frontend/        # Páginas estáticas (index, dashboard, reports)
├── docker/          # Script de inicialização do banco no container
└── docker-compose.yml
```

---

## Como rodar

Há duas formas. A **Opção A (Docker)** é a mais simples e recomendada para avaliação:
um comando sobe banco, carga dos dados, backend e frontend. A **Opção B (manual)**
serve para quem já tem PostgreSQL e Node instalados.

Em ambas, ao final acesse **http://localhost:5500** e entre com **admin / admin**.

---

## Opção A — Docker (recomendada)

**Pré-requisito:** Docker Desktop (Windows/Mac) ou Docker Engine + Compose (Linux).

Na raiz do projeto:

```bash
docker compose up --build
```

Na **primeira** execução o container do banco roda automaticamente todos os scripts
de `sql/` (via `99_run_all.sql`) e carrega os arquivos de `data/`. Isso leva cerca de
um minuto. Quando o backend logar `API rodando em http://localhost:3000`, abra:

- **Aplicação:** http://localhost:5500
- **API:** http://localhost:3000/api

### Serviços e portas

| Serviço    | Porta | Detalhes                                                        |
|------------|-------|-----------------------------------------------------------------|
| `frontend` | 5500  | nginx servindo os arquivos estáticos                            |
| `backend`  | 3000  | API Node/Express                                                |
| `db`       | 5432  | PostgreSQL 16 — usuário `postgres`, senha `postgres`, banco `f1db_grupo5` |

### Comandos úteis

```bash
docker compose up --build -d     # subir em segundo plano
docker compose logs -f           # acompanhar logs
docker compose down              # parar (mantém os dados do banco)
docker compose down -v           # parar e APAGAR o banco (refaz a carga no próximo up)
```

> A carga inicial só roda quando o volume do banco está vazio. Para refazer do zero
> após mexer nos scripts SQL ou nos dados, use `docker compose down -v` antes de subir.

As credenciais do Docker (`postgres`/`postgres`) são isoladas e **não** afetam uma
instalação local de PostgreSQL.

---

## Opção B — Manual (sem Docker)

**Pré-requisitos:**
- PostgreSQL 14+ com o cliente `psql` no PATH (os scripts usam `\copy`).
- Node.js 18+.

### 1. Criar e carregar o banco

```bash
# Cria o banco (ajuste usuário/host se necessário)
createdb -U postgres f1db_grupo5

# Roda todos os scripts na ordem. IMPORTANTE: execute de dentro da pasta sql/,
# porque os comandos \copy usam caminhos relativos a ../data.
cd sql
psql -U postgres -d f1db_grupo5 -f 99_run_all.sql
```

Isso cria tabelas, views, funções, triggers, índices, carrega os dados e semeia os
usuários iniciais (`06_seed_users.sql`).

### 2. Subir o backend

```bash
cd backend
npm install
cp .env.example .env     # ajuste as credenciais do banco
npm start
```

Edite o `.env` para apontar ao seu PostgreSQL:

| Variável | Descrição |
|---|---|
| `PORT` | Porta da API (padrão 3000) |
| `DB_HOST` / `DB_PORT` / `DB_NAME` / `DB_USER` / `DB_PASSWORD` | Conexão com o PostgreSQL |
| `SESSION_SECRET` | Segredo da sessão |
| `FRONTEND_ORIGIN` | Origem do frontend liberada no CORS (padrão `http://localhost:5500`) |

A API sobe em `http://localhost:3000`.

### 3. Servir o frontend

O frontend precisa ser servido por **HTTP** numa porta **diferente** da do backend
(use 5500). Não abra os arquivos com `file://` — os cookies de sessão não funcionam.

```bash
cd frontend
npx serve . -l 5500
# ou:  python -m http.server 5500
```

Acesse **http://localhost:5500**.

> Use sempre `localhost` (não `127.0.0.1`) nos dois lados, para a origem bater com o
> CORS. Se mudar a porta do frontend, ajuste `FRONTEND_ORIGIN` no `.env` do backend.
> A URL do backend usada pelo frontend está em `frontend/js/api.js` (`API_BASE_URL`).

---

## Usuários de teste

Definidos em `sql/06_seed_users.sql`. As senhas são armazenadas com hash (bcrypt via
pgcrypto), nunca em texto puro.

| Tipo | Login | Senha |
|---|---|---|
| Admin | `admin` | `admin` |
| Piloto | `<driver_ref>_d` (ex.: `hamilton_d`) | `<driver_ref>` (ex.: `hamilton`) |
| Escuderia | `<constructor_ref>_c` (ex.: `ferrari_c`) | `<constructor_ref>` (ex.: `ferrari`) |

---

## Solução de problemas

- **"Rota não encontrada" / erro de CORS:** confira que o frontend está em
  `http://localhost:5500` e o backend em `http://localhost:3000`, e use `localhost`
  em ambos (não `127.0.0.1`).
- **Login falha / cookie não persiste:** sirva o frontend por HTTP (não `file://`).
- **Porta em uso:** o `npx serve` usa 3000 por padrão; fixe a do frontend com `-l 5500`.
- **Quero recarregar o banco do zero (Docker):** `docker compose down -v && docker compose up --build`.
- **`\copy` não encontra os arquivos (manual):** rode o `psql` de dentro da pasta `sql/`.

---

Mais detalhes das rotas da API em [backend/README.md](backend/README.md) e da interface
em [frontend/README.md](frontend/README.md).
