#######################################################
# Instalaçcao do Node.js
# nvm ls-remote (ver as versoes disponiveis)
# nvm install v22.15.0
# nvm use global v22.15.0
#######################################################
# O Dockerfile gera a imagem da aplicacao
#
# Comandos importantes
#
# docker compose down
# docker compose build
# docker compose up -d
#######################################################

FROM public.ecr.aws/docker/library/node:22-slim
RUN npm install -g npm@11 --loglevel=error

#Instalando o curl
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm install --loglevel=error

COPY . .

RUN NODE_OPTIONS=--openssl-legacy-provider REACT_APP_API_URL=http://localhost:3001 SKIP_PREFLIGHT_CHECK=true npm run build --prefix client
#RUN NODE_OPTIONS=--openssl-legacy-provider REACT_APP_API_URL=http://52.90.36.66:3001 SKIP_PREFLIGHT_CHECK=true npm run build --prefix client

RUN mv client/build build

RUN rm  -rf client/*

RUN mv build client/

EXPOSE 8080

CMD [ "npm", "start" ]
#CMD ["sh", "-c", "node app > logs/app.log"]
