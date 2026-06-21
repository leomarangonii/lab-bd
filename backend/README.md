# Backend - Projeto Final (Laboratório de Bases de Dados)

Camada simples entre o frontend e o PostgreSQL. Toda a lógica de negócio está nas
funções SQL do projeto (`sql/05_functions.sql`); o backend apenas chama essas funções
com consultas parametrizadas.

## Tecnologias

Node.js, Express, PostgreSQL (`pg`), `dotenv`, `express-session`, `multer`, `csv-parse`.

## Pré-requisitos

- Node.js 18+
- PostgreSQL com o banco do projeto já criado e carregado (scripts da pasta `sql/`,
  incluindo `06_seed_users.sql` para os usuários iniciais).

## Instalação

```bash
cd backend
npm install
cp .env.example .env   # ajuste as credenciais do banco
npm start
```

A API sobe em `http://localhost:3000`.

## Variáveis de ambiente (`.env`)

| Variável | Descrição |
|---|---|
| `PORT` | Porta da API (padrão 3000) |
| `DB_HOST` / `DB_PORT` / `DB_NAME` / `DB_USER` / `DB_PASSWORD` | Conexão com o PostgreSQL |
| `SESSION_SECRET` | Segredo da sessão |

## Autenticação

Login de exemplo (usuário semeado): `admin` / `admin`.
Pilotos e escuderias usam `<ref>_d` / `<ref>` e `<ref>_c` / `<ref>`.

## Rotas

### Sessão
- `POST /api/login` — body `{ "login", "password" }`
- `POST /api/logout`
- `GET /api/me`

### Admin (tipo `Admin`)
- `GET /api/admin/dashboard`
- `POST /api/admin/constructors` — `{ constructorRef, name, countryId, wikipediaUrl }`
- `POST /api/admin/drivers` — `{ driverRef, givenName, familyName, dateOfBirth, countryId }`
- `GET /api/admin/reports/status`
- `GET /api/admin/reports/airports?city=São Carlos`
- `GET /api/admin/reports/report-3`

### Escuderia (tipo `Escuderia`)
- `GET /api/constructor/dashboard`
- `GET /api/constructor/drivers/search?familyName=Hamilton`
- `POST /api/constructor/drivers/upload` — `multipart/form-data`, campo `file` (CSV)
- `GET /api/constructor/reports/wins`
- `GET /api/constructor/reports/status`

### Piloto (tipo `Piloto`)
- `GET /api/driver/dashboard`
- `GET /api/driver/reports/points`
- `GET /api/driver/reports/status`

O identificador da escuderia/piloto vem sempre da sessão (`idOriginal`), nunca da URL.

## Formato das respostas

Sucesso:
```json
{ "success": true, "data": {} }
```

Erro:
```json
{ "success": false, "message": "Descrição do erro." }
```

Códigos: `400` dados inválidos · `401` não autenticado · `403` proibido ·
`404` sem resultado · `409` duplicidade · `500` erro interno.

## Upload de pilotos (CSV)

Cabeçalho esperado:
```csv
driver_ref,given_name,family_name,date_of_birth,country_id
novo_piloto,Novo,Piloto,2000-01-01,30
```

O backend valida as colunas, chama `create_driver_for_constructor` por linha,
retorna quais pilotos foram inseridos e quais falharam, e apaga o arquivo temporário.
