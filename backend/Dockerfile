# Imagem do backend Node/Express.
FROM node:20-alpine

WORKDIR /app

# Instala dependencias primeiro para aproveitar o cache de camadas.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Copia o codigo da aplicacao.
COPY src ./src

EXPOSE 3000

CMD ["node", "src/server.js"]
