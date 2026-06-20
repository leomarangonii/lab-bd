# Frontend — Projeto Final (Laboratório de Bases de Dados)

Interface em HTML + Tailwind (CDN) + JavaScript puro que consome a API Node/Express.
Toda comunicação com o banco passa pela API; o frontend nunca acessa o PostgreSQL.

## 1. Estrutura do projeto

```text
frontend/
├── index.html        # Login
├── dashboard.html    # Painel (muda conforme o tipo do usuário)
├── reports.html      # Relatórios (muda conforme o tipo do usuário)
├── css/
│   └── custom.css    # Só o essencial (foco visível)
└── js/
    ├── api.js        # API_BASE_URL, apiRequest, helpers visuais
    ├── auth.js       # login, /api/me, cabeçalho, logout
    ├── dashboard.js  # dashboards e formulários por tipo
    └── reports.js    # relatórios por tipo
```

## 2. URL do backend

Definida em `js/api.js`:

```javascript
const API_BASE_URL = "http://localhost:3000/api";
```

Altere se o backend rodar em outra porta/host.

## 3. Como executar

O backend roda na porta **3000**. O frontend deve usar uma porta **diferente** (5500),
senão há conflito. O `npx serve` usa 3000 por padrão, então fixe a porta com `-l 5500`.

O backend deve estar rodando (`cd backend && npm start` → `http://localhost:3000`).
Em seguida, sirva o frontend por HTTP em outra porta (não use `file://`, pois os
cookies de sessão não funcionam):

```bash
cd frontend
npx serve . -l 5500
```

ou

```bash
cd frontend
python -m http.server 5500
```

Acesse: `http://localhost:5500`

> Backend → `http://localhost:3000` · Frontend → `http://localhost:5500`.
> A porta 5500 já é a origem liberada no CORS (`FRONTEND_ORIGIN`). Se mudar a porta
> do frontend, ajuste `FRONTEND_ORIGIN` no `.env` do backend para a mesma porta.

## 4. Páginas

- **index.html** — login; em caso de sucesso redireciona para o dashboard.
- **dashboard.html** — valida a sessão (`GET /api/me`) e monta o painel conforme o tipo:
  - **Admin**: cartões (pilotos/escuderias/temporadas), tabelas da temporada mais recente,
    formulários para cadastrar escuderia e piloto.
  - **Escuderia**: cartões (nome, vitórias, pilotos, primeiro/último ano), consulta por
    sobrenome e upload de pilotos por CSV.
  - **Piloto**: cartões (nome, escuderia mais recente, primeiro/último ano) e tabela de
    desempenho por ano e circuito.
- **reports.html** — botões de relatório por tipo.

## 5. Usuários de teste

(Definidos em `sql/06_seed_users.sql`.)

| Tipo | Login | Senha |
|---|---|---|
| Admin | `admin` | `admin` |
| Piloto | `<driver_ref>_d` (ex.: `hamilton_d`) | `<driver_ref>` (ex.: `hamilton`) |
| Escuderia | `<constructor_ref>_c` (ex.: `ferrari_c`) | `<constructor_ref>` (ex.: `ferrari`) |

## 6. Formato do CSV (upload de pilotos pela escuderia)

```csv
driver_ref,given_name,family_name,date_of_birth,country_id
novo_piloto,Novo,Piloto,2000-01-01,30
```

As cinco colunas são obrigatórias. O resultado mostra total de linhas, inseridas e com erro.

## 7. CORS e cookies (importante)

O frontend (`:5500`) e o backend (`:3000`) ficam em **origens diferentes**, e a sessão
usa cookie. Para o navegador enviar/aceitar o cookie, o backend precisa habilitar CORS
com credenciais. No `backend/src/server.js`, antes das rotas:

```javascript
const cors = require("cors"); // npm install cors

app.use(cors({
  origin: "http://localhost:5500", // origem exata do frontend
  credentials: true
}));
```

E o cookie da sessão deve permitir uso entre origens locais:

```javascript
app.use(session({
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: { httpOnly: true, sameSite: "lax" }
}));
```

Observações:
- O frontend já envia `credentials: "include"` em todas as requisições.
- Use sempre `http://localhost` (e não `127.0.0.1`) em ambos para a origem bater.
- Em produção com HTTPS, o cookie precisaria de `secure: true` e `sameSite: "none"`.
