require("dotenv").config();

const express = require("express");
const session = require("express-session");
const cors = require("cors");

const { router: authRouter } = require("./auth");
const adminRouter = require("./admin");
const constructorRouter = require("./constructor");
const driverRouter = require("./driver");

const app = express();

// CORS com credenciais: o frontend roda em outra origem e precisa enviar o cookie.
// FRONTEND_ORIGIN pode ser ajustado no .env (padrao: servidor estatico local).
app.use(
  cors({
    origin: process.env.FRONTEND_ORIGIN || "http://localhost:5500",
    credentials: true
  })
);

app.use(express.json());

// Sessao guardada em cookie. Em producao convem usar um store dedicado e cookie secure.
app.use(
  session({
    secret: process.env.SESSION_SECRET || "chave_do_projeto",
    resave: false,
    saveUninitialized: false,
    cookie: { httpOnly: true, sameSite: "lax" }
  })
);

// Rotas da API.
app.use("/api", authRouter);
app.use("/api/admin", adminRouter);
app.use("/api/constructor", constructorRouter);
app.use("/api/driver", driverRouter);

// Rota nao encontrada.
app.use((req, res) => {
  res.status(404).json({ success: false, message: "Rota não encontrada." });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`API rodando em http://localhost:${PORT}`);
});
