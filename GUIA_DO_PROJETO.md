# Guia do Projeto — Entendimento e Defesa

> Documento de estudo para a apresentação do Projeto Final (SCC-241 — Laboratório de
> Bases de Dados). Explica **o que** o projeto tem, **por que** cada decisão foi tomada,
> **o que não foi feito** (e por quê) e traz um banco de **perguntas prováveis do professor
> com respostas**. A fonte da verdade do projeto são os scripts em `sql/`.

---

## 1. Visão geral em uma frase

Uma aplicação web de 3 camadas sobre a base da Fórmula 1 (FIA) + cidades e aeroportos do
mundo, em que **toda a regra de negócio mora no PostgreSQL** (funções, views, triggers,
índices) e as camadas de cima (backend Node e frontend HTML/JS) apenas chamam o banco e
mostram o resultado.

```
Navegador → Frontend (HTML/Tailwind/JS, :5500) → Backend (Node/Express, :3000) → PostgreSQL (:5432)
```

**Princípio condutor:** o enunciado exige que "os comandos SQL utilizados pela aplicação
estejam explícitos no código" e que os conceitos da disciplina (funções, triggers, views,
índices) estejam destacados. Por isso **não usamos ORM**: o backend executa SQL explícito e
parametrizado, e a lógica pesada está em funções da aplicação no banco, fáceis de mostrar e auditar.

---

## 2. Stack tecnológico e por que cada escolha

| Camada | Tecnologia | Por que |
|---|---|---|
| Banco | **PostgreSQL** | É o SGBD da disciplina; suporta funções PL/pgSQL, triggers, views, índices avançados (hash, parcial, GiST), e extensões `pgcrypto`/`cube`/`earthdistance`. |
| Backend | **Node.js + Express** + driver **`pg`** | Camada fina e simples. O `pg` permite SQL parametrizado explícito (`$1, $2`), sem ORM escondendo as queries. |
| Sessão | **express-session** (cookie `httpOnly`) | Autenticação por sessão; o cookie não é acessível por JavaScript. |
| Upload | **multer** + **csv-parse** | Receber o arquivo CSV de pilotos (ação da Escuderia) e lê-lo linha a linha. |
| Frontend | **HTML + Tailwind (CDN) + JavaScript puro** | O enunciado dá liberdade de tecnologia. Vanilla JS deixa o código transparente, sem build, fácil de demonstrar a interação com o banco. |
| Execução | **Docker Compose** | "Os arquivos necessários para executar o protótipo": um comando sobe banco + carga + API + frontend, facilitando a avaliação. |

**O que NÃO usamos, de propósito:** ORM (Sequelize/Prisma), frameworks de frontend
(React/Vue/Angular), jQuery, Bootstrap, TypeScript, bundlers. Tudo para manter o SQL e os
conceitos da disciplina visíveis e o projeto simples de explicar.

---

## 3. Mapa de cobertura: requisito → onde está implementado

### 3.1 Administrar usuários (Seção 1 do enunciado)

| Requisito | Status | Onde |
|---|---|---|
| Tabela `USERS` com `userid, login, password, tipo, id_original` (login único) | ✅ | `sql/01_schema_tabelas.sql` |
| `tipo` só pode ser `'Admin'`/`'Escuderia'`/`'Piloto'` | ✅ | `CHECK` na tabela `users` |
| `id_original` nulo p/ admin, preenchido p/ piloto/escuderia | ✅ | `CHECK ck_users_id_original_por_tipo` |
| Senha protegida (sem texto puro) | ✅ | bcrypt via `crypt()/gen_salt('bf')` (pgcrypto) |
| Pilotos e escuderias existentes viram usuários | ✅ | `sql/06_seed_users.sql` |
| Criar/alterar piloto ou escuderia sincroniza `USERS` automaticamente | ✅ | **Triggers** `tr_sync_driver_user` / `tr_sync_constructor_user` (`sql/07_triggers.sql`) |
| Se o login gerado já existir, cancelar a operação | ✅ | `RAISE EXCEPTION` dentro das triggers |
| Tabela `USERS_LOG` (userid, ação LOGIN/LOGOUT, timestamp) | ✅ | `users_log` + função `log_access` chamada no login/logout |

### 3.2 Telas (Seção 2)

| Tela | Status | Onde |
|---|---|---|
| Tela 1 — Login | ✅ | `frontend/index.html` + `js/auth.js` |
| Tela 2 — Dashboard (varia por tipo, mostra nome do usuário) | ✅ | `frontend/dashboard.html` + `js/dashboard.js` |
| Tela 3 — Relatórios (botões por tipo) | ✅ | `frontend/reports.html` + `js/reports.js` |

### 3.3 Ações por tipo (Seção 3)

| Ação | Status | Onde |
|---|---|---|
| Admin cadastra escuderia | ✅ | `POST /api/admin/constructors` → `create_constructor` |
| Admin cadastra piloto | ✅ | `POST /api/admin/drivers` → `create_driver` |
| Usuário criado automaticamente via trigger | ✅ | triggers de sincronização |
| Trigger cancela se login já existe | ✅ | `RAISE EXCEPTION` |
| Escuderia consulta piloto por sobrenome (que já correu por ela) | ✅ | `constructor_find_driver_by_family_name` (usa `RESULTS`) |
| Escuderia insere pilotos por arquivo (CSV) | ✅ | `POST /api/constructor/drivers/upload` → `create_driver_for_constructor` por linha |
| Antes de inserir, checar piloto duplicado (nome+sobrenome) | ✅ | `create_driver` faz `RAISE EXCEPTION` se já existir |
| Piloto só visualiza (não altera) | ✅ | rotas de piloto são todas de leitura; `requireRole('Piloto')` |

### 3.4 Dashboards (Seção 4)

| Item | Status | Função |
|---|---|---|
| Admin: totais de pilotos, escuderias, temporadas | ✅ | `admin_counts` |
| Admin: corridas da temporada mais recente (circuito, data, hora, voltas) | ✅ | `admin_latest_races` |
| Admin: escuderias da temporada recente com total de pontos | ✅ | `admin_latest_constructors_points` |
| Admin: pilotos da temporada recente com total de pontos | ✅ | `admin_latest_drivers_points` |
| Escuderia: vitórias, nº de pilotos, primeiro/último ano | ✅ | `constructor_dashboard(p_constructor_id)` |
| Piloto: primeiro/último ano + por ano/circuito (pontos, vitórias, nº corridas) | ✅ | `driver_dashboard(p_driver_id)` |

### 3.5 Relatórios (Seção 5)

| Relatório | Status | Função / rota |
|---|---|---|
| R1 (Admin) — resultados por status | ✅ | `report_admin_status_count` |
| R2 (Admin) — aeroportos a ≤100 km de cidade BR (medium/large) | ✅ | `report_admin_airports_near_city` (earthdistance) |
| R3 (Admin) — escuderias+pilotos e relatório hierárquico em 3 níveis | ✅ | 4 funções combinadas em `GET /api/admin/reports/report-3` |
| R4 (Escuderia) — vitórias por piloto da escuderia | ✅ | `report_constructor_driver_wins` |
| R5 (Escuderia) — resultados por status (escopo da escuderia) | ✅ | `report_constructor_status_count` |
| R6 (Piloto) — pontos por ano + corridas pontuadas | ✅ | `report_driver_points_by_year_race` |
| R7 (Piloto) — resultados por status (escopo do piloto) | ✅ | `report_driver_status_count` |

**Conclusão:** todos os requisitos funcionais do enunciado estão atendidos.

---

## 4. O banco de dados em detalhe

Os scripts rodam na ordem do `99_run_all.sql`:
`01` tabelas → `02` carga CSV → `03` métricas/dedup/correções → `04` views → `05` funções →
`06` usuários → `07` triggers → `08` índices → `09` testes rápidos.

### 4.1 Modelagem (herança do T1)

A base já vem **normalizada conforme o T1**:
- a **nacionalidade** deixou de ser texto solto em pilotos/escuderias e passou a pertencer ao
  **país** (`countries.nationality`);
- `drivers` e `constructors` referenciam o país por **`country_id`** (FK), não por texto;
- durante a carga (`02`), a nacionalidade textual dos CSVs é usada só na *staging* (`stg`) para
  descobrir o `country_id` (tabela de mapeamento `nationality → country_code`).

**Deduplicação de cidades (T1):** em `03`, cidades com mesmo país + mesmo nome ASCII são
tratadas como duplicatas; mantém-se a de maior população (depois a com coordenadas, depois o
menor id) e as FKs de `airports`/`circuits` são redirecionadas para a cidade mantida.

### 4.2 Tabelas específicas do P4 (criadas por nós)

- **`users`** — exigida pelo enunciado. Tem dois `CHECK` importantes:
  - `tipo IN ('Admin','Escuderia','Piloto')`;
  - `ck_users_id_original_por_tipo`: garante `id_original` nulo para Admin e **não** nulo para
    Piloto/Escuderia (consistência de integridade).
- **`users_log`** — auditoria de acesso. `action_type IN ('LOGIN','LOGOUT')` + timestamp default.
- **`constructor_drivers`** — associação **(constructor_id, driver_id)**. Ver decisão na seção 6.

### 4.3 Funções e procedures (`05_functions.sql`)

Dois grupos:

**(a) Demonstração de conceitos do T2** (reaproveitadas do estilo do gabarito; servem para
mostrar domínio de PL/pgSQL — cursores, `RAISE NOTICE`, `RETURN NEXT`, parâmetro default):
`Nome_Nacionalidade`, `Pilotos_Nacionalidade`, `Cidade_Chamada` (procedure), `Numero_Vitorias`,
`Pais_Continente`.
> ⚠️ **Seja honesto na defesa:** essas funções demonstram conceitos e **não são todas chamadas
> pela aplicação** — a aplicação usa as funções da aplicação. Se perguntarem "onde isso é usado?",
> responda que são herança do T2 para evidenciar PL/pgSQL.

**(b) Funções do P4 (usadas pela aplicação), todas com nomes descritivos:**
- Autenticação/log: `authenticate`, `log_access`.
- Dashboards: `admin_counts`, `admin_latest_races`, `admin_latest_constructors_points`,
  `admin_latest_drivers_points`, `constructor_dashboard`, `driver_dashboard`.
- Relatórios: `report_admin_status_count`, `report_admin_airports_near_city`,
  `report_admin_constructor_driver_count`, `report_admin_races_total`,
  `report_admin_races_by_circuit`, `report_admin_race_details`,
  `report_constructor_driver_wins`, `report_constructor_status_count`,
  `report_driver_points_by_year_race`, `report_driver_status_count`.
- Ações: `create_constructor`, `create_driver`, `create_driver_for_constructor`,
  `constructor_find_driver_by_family_name`.

**Detalhes técnicos que valem na defesa:**
- Funções de consulta são `LANGUAGE sql STABLE` (sem efeitos colaterais, só leem) → o
  planejador pode otimizar melhor; funções com regras/validação são `plpgsql`.
- `create_driver` valida obrigatoriedade dos campos, data não futura e **piloto duplicado**
  (nome+sobrenome) com `RAISE EXCEPTION` — atende a regra da inserção por arquivo.

### 4.4 Views (`04_views.sql`)

A **view central** é **`vw_results_full`**: junta `results` com corrida, temporada, circuito,
piloto, país do piloto, escuderia, país da escuderia e status. Quase todos os dashboards e
relatórios partem dela — evita repetir os mesmos `JOIN` em cada função (DRY) e centraliza a
lógica de junção.

Outras views do P4: `vw_constructor_driver_history` (pilotos por escuderia, via results),
`vw_driver_latest_constructor` (escuderia mais recente do piloto, com `DISTINCT ON`),
`vw_cidades_brasileiras_todas` e `vw_aeroportos_brasileiros_medium_large` (Relatório 2).

Há ainda views/materialized views herdadas do **T4** (`Aeroportos_Brasileiros`,
`Cidades_brasileiras`, `Circuitos_completa`, `Problemas_aeroportos`, etc.) que demonstram o
conceito; nem todas são usadas pela aplicação (mesma observação de honestidade do T2).

### 4.5 Triggers (`07_triggers.sql`)

Duas triggers `AFTER INSERT OR UPDATE` que **sincronizam `USERS`** automaticamente:
- `tr_sync_driver_user` em `drivers` → cria/atualiza usuário `<driver_ref>_d`;
- `tr_sync_constructor_user` em `constructors` → cria/atualiza usuário `<constructor_ref>_c`.

A senha é gravada já com hash (`crypt(ref, gen_salt('bf'))`). **Se o login gerado já existir
para outro registro, a trigger faz `RAISE EXCEPTION`**, o que **aborta a transação** e impede a
inserção inconsistente na tabela de origem — exatamente o que o enunciado pede.

### 4.6 Índices (`08_indices.sql`) e justificativas

- **FKs** (vários `idx_*`): aceleram as junções das views/relatórios.
- `idx_users_login`: o login é consultado em **toda** autenticação.
- `idx_drivers_nome_completo_hash` (**HASH**, herança T5): busca por **igualdade** no nome
  completo do piloto.
- `idx_city_brazil_name_prefix` (**B-tree parcial** com `text_pattern_ops`, `INCLUDE` e
  `WHERE country_id = Brasil`, herança T5): otimiza `LIKE 'nome%'` nas cidades brasileiras
  (Relatório 2). O id do Brasil é descoberto em tempo de execução por um bloco `DO`.
- `idx_results_*` (constructor/driver/status/race): cobrem os filtros e contagens dos
  relatórios 4, 5, 6, 7 e dos dashboards.
- `idx_drivers_family_name_lower`: a busca por sobrenome é feita com `LOWER(family_name)`.
- **Índices espaciais GiST** (`idx_cities_brazil_ll_earth`, `idx_airports_ll_earth`):
  aceleram o `earth_box`/`earth_distance` do Relatório 2.

### 4.7 Extensões

- **pgcrypto** → hashing bcrypt das senhas;
- **cube + earthdistance** → cálculo de distância geográfica (Relatório 2).

---

## 5. Segurança (ponto que o professor costuma cobrar)

| Mecanismo | Como | Onde |
|---|---|---|
| Senha protegida | **bcrypt** (`crypt`/`gen_salt('bf')`); nunca em texto puro | seed, triggers, `authenticate` |
| SCRAM-SHA-256? | **Não se aplica:** não usamos *roles* reais do PostgreSQL; a autenticação é pela tabela `USERS` (o enunciado exige SCRAM só no caso de usuários reais do SGBD) | — |
| SQL Injection | **Consultas parametrizadas** (`$1, $2`); nenhum dado do usuário é concatenado em SQL | todos os arquivos do backend |
| Escopo por usuário | O identificador da escuderia/piloto vem **sempre da sessão** (`req.session.user.idOriginal`), **nunca da URL** | `constructor.js`, `driver.js` |
| Controle de acesso | `requireAuth` (exige login) e `requireRole('Admin'/'Escuderia'/'Piloto')` em cada grupo de rotas | `auth.js` |
| Sessão segura | Cookie `httpOnly` (JS não lê) + `sameSite: 'lax'`; no frontend o usuário fica só em memória, **nunca em localStorage** | `server.js`, `js/auth.js` |
| Sem vazar erro interno | `mapDbError` traduz erros do banco em status HTTP + mensagem curta; **stack trace nunca vai ao frontend** | `auth.js` |
| XSS | `escapeHtml` em todo dado vindo do banco antes de injetar no HTML | `js/api.js` |

Mapeamento de erros: `400` dados inválidos · `401` não autenticado · `403` sem permissão ·
`404` sem resultado · `409` duplicidade (`23505` ou `RAISE 'já existe'`) · `500` erro interno.

---

## 6. Decisão explícita: tabela `constructor_drivers`

O enunciado diz: *"Caso o grupo opte por registrar explicitamente a associação entre o novo
piloto e a escuderia logada, essa decisão deve ser descrita no relatório e implementada de
forma compatível com o esquema relacional."*

**Nossa decisão:** sim, registramos. Criamos a tabela associativa `constructor_drivers
(constructor_id, driver_id)`. Quando uma escuderia insere pilotos por arquivo, a função
`create_driver_for_constructor` cria o piloto em `DRIVERS` (disparando a trigger que cria o
usuário em `USERS`) **e** insere o vínculo em `constructor_drivers`.

**Por que uma tabela separada e não "reaproveitar" results?** Porque um piloto recém-cadastrado
**ainda não correu** — não tem linha em `RESULTS`. O **histórico real** de "quem correu pela
escuderia" continua vindo de `RESULTS` (é o que os relatórios 4 e a busca por sobrenome usam,
seguindo a dica do enunciado). A `constructor_drivers` registra apenas a **associação
administrativa** feita no cadastro, sem poluir o histórico esportivo. As duas fontes coexistem
de forma consistente.

---

## 7. Backend — organização e decisões

- Estrutura simples em `backend/src/`: `server.js` (configuração + montagem das rotas),
  `db.js` (pool de conexões), `auth.js` (login/logout/me + helpers de segurança), e um arquivo
  por tipo de usuário: `admin.js`, `constructor.js`, `driver.js`.
- **Sem camadas extras** (controller/service/repository) de propósito — para um protótipo,
  isso seria cerimônia desnecessária e esconderia o SQL.
- Toda rota usa **async/await** e devolve o **envelope padrão**:
  `{ success: true, data: ... }` ou `{ success: false, message: ... }`.
- Cada rota tem o SQL explícito chamando uma função da aplicação — fácil de mostrar na avaliação.

---

## 8. Frontend — organização e decisões

- Três páginas: `index.html` (login), `dashboard.html`, `reports.html`. Os scripts em `js/`:
  `api.js` (fetch + helpers visuais), `auth.js` (login/sessão/logout), `dashboard.js`,
  `reports.js`.
- `fetch` sempre com **`credentials: "include"`** (envia o cookie de sessão entre as portas).
- **Tudo em Português** e **sem expor nomes internos de coluna** (driver_id, etc.) — as funções
  SQL já devolvem rótulos amigáveis (`piloto`, `escuderia`, `pontos`…), atendendo o requisito de
  "colunas inteligíveis em Língua Portuguesa".
- Anos são formatados **sem separador de milhar** (`2007`, não `2.007`) via `formatYear`.

---

## 9. Como rodar (resumo) e dados carregados

Ver `README.md` para o passo a passo. Em resumo: `docker compose up --build` → abrir
`http://localhost:5500` → login `admin/admin`.

Dados após a carga (verificados): **616 pilotos, 168 escuderias, 1146 corridas, 7600
resultados, 785 usuários** (admin + 1 por escuderia + 1 por piloto).

Usuários de teste: Admin `admin/admin`; Piloto `<driver_ref>_d` / `<driver_ref>`
(ex.: `hamilton_d` / `hamilton`); Escuderia `<constructor_ref>_c` / `<constructor_ref>`
(ex.: `ferrari_c` / `ferrari`).

---

## 10. O que NÃO temos / limitações conscientes

- **Não há usuários reais do PostgreSQL** (e portanto não há SCRAM-SHA-256) — por escolha de
  projeto, a autenticação é pela tabela `USERS` com bcrypt, alternativa explicitamente
  permitida pelo enunciado.
- **Funções/views herdadas do T2/T4 não são todas usadas** pela aplicação — existem para
  demonstrar os conceitos da disciplina.
- **Cookie sem `secure`/HTTPS** — adequado a um protótipo local; em produção exigiria
  `secure: true` e `sameSite: 'none'`.
- **Sessão em memória** (store padrão do express-session) — reiniciar o backend desloga todos;
  aceitável para protótipo.
- **Correção pontual de dados de origem:** 6 nomes de circuitos vinham corrompidos no CSV
  (mojibake, caractere `�`); corrigimos por `circuit_ref` em `sql/03_*` (ver seção 11).

---

## 11. Dificuldades encontradas e como tratamos (bom para o relatório PDF)

1. **Nomes de circuitos corrompidos (`Aut�dromo`)** — o caractere `�` (U+FFFD) já vinha gravado
   no `data/circuits.csv` de origem (não era erro de renderização). Corrigimos 6 linhas por
   `circuit_ref` em `sql/03_deduplicacao_metricas.sql`, de forma reproduzível.
2. **Relatório 6** — a versão inicial só listava corridas pontuadas, sem o total por ano.
   Reescrevemos a função com dois CTEs (`anos_participacao` + `corridas_pontuadas`) unidos por
   `LEFT JOIN`, preservando anos sem pontos, e agrupamos a exibição por ano no frontend.
3. **Relatório 3** — precisava ser hierárquico (3 níveis). Combinamos 4 funções tabulares num
   JSON e montamos o aninhamento (total → por circuito → corridas) no frontend.
4. **Login** — o backend espera o campo JSON **`password`** (não `senha`); CORS com credenciais
   e separação de portas (frontend 5500, backend 3000) foram necessários para o cookie funcionar.
5. **Formato de ano** — `toLocaleString('pt-BR')` colocava `2.007`; criamos `formatYear`.

---

## 12. Perguntas prováveis na apresentação (e respostas curtas)

**"Onde está a regra de negócio?"** No PostgreSQL — funções da aplicação, triggers, views. O backend
só chama e formata.

**"Como a senha é protegida?"** bcrypt via pgcrypto (`crypt`/`gen_salt('bf')`). Nunca em texto
puro. SCRAM não se aplica porque não usamos roles reais do SGBD — usamos a tabela `USERS`, o que
o enunciado permite.

**"Como evita SQL Injection?"** Todas as queries são parametrizadas (`$1, $2`); nenhum dado do
usuário é concatenado na string SQL.

**"Como garante que uma escuderia só vê os dados dela?"** O identificador vem da **sessão**
(`idOriginal`), nunca da URL, e cada função recebe esse id como parâmetro. As rotas exigem o
papel correto (`requireRole`).

**"O que acontece se cadastrar um piloto cujo login já existe?"** A trigger detecta o login
duplicado e faz `RAISE EXCEPTION`, abortando a transação — o piloto **não** é inserido.

**"Como funciona o Relatório 2 (aeroportos a 100 km)?"** Com as extensões `cube`/`earthdistance`:
`earth_box(...)` filtra um quadrado de ~100 km (usando índice GiST) e `earth_distance(...)`
calcula a distância exata; filtramos só `medium_airport`/`large_airport` brasileiros.

**"Por que esses índices?"** Cada um otimiza um filtro/junção real: login na autenticação,
hash no nome do piloto, B-tree parcial para `LIKE` em cidades BR, GiST para a busca espacial,
e índices em `results` para os relatórios por escuderia/piloto/status.

**"Por que `vw_results_full`?"** Para não repetir o mesmo conjunto de `JOIN`s em cada função
— centraliza a junção de resultados+corrida+piloto+escuderia+status.

**"Diferença entre `constructor_drivers` e `RESULTS`?"** `RESULTS` é o histórico esportivo (quem
de fato correu); `constructor_drivers` é a associação administrativa do cadastro por arquivo
(piloto novo que ainda não correu). Ver seção 6.

**"Qual a diferença entre os dois grupos de funções?"** As funções de dashboard, relatórios e ações são usadas pela aplicação;
as outras (T2) demonstram conceitos de PL/pgSQL (cursores, procedures, `RETURN NEXT`).

**"Por que Docker?"** Para a avaliação rodar com um comando, sem instalar PostgreSQL/Node e sem
problemas de ambiente.

---

## 13. Conceitos da disciplina e onde aparecem (checklist do enunciado)

- **Procedimentos e funções** → `sql/05_functions.sql` (as funções da aplicação e as do T2).
- **Triggers** → `sql/07_triggers.sql` (sincronização de `USERS`).
- **Visões** → `sql/04_views.sql` (`vw_results_full` e demais).
- **Índices** → `sql/08_indices.sql` (hash, B-tree parcial com INCLUDE, GiST, FKs).
- **Junções, agregações e filtros** → praticamente todas as funções de relatório/dashboard
  (`JOIN`, `GROUP BY`, `COUNT/SUM/MIN/MAX/AVG`, `FILTER (WHERE ...)`).
- **Controle de acesso e autenticação** → `authenticate` + `users`/`users_log` + middlewares
  `requireAuth`/`requireRole` no backend.
