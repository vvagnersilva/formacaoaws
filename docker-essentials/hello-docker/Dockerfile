##########################################################################################
# docker build -t teste-volume .
# docker run -ti -p 3000:3000 teste-volume
#
# COMPARTILHAMENTO DE VOLUME COM O HOST
#
# docker run -d -p 3002:3002 -v "$(pwd)"/logs:/usr/src/app/logs teste-volume 
# docker ps (ver o nome do container)
# docker exec -ti dazzling_carson bash
##########################################################################################
FROM  ubuntu:18.04

RUN apt-get update -y

RUN apt-get install nodejs -y

RUN apt-get install npm -y

WORKDIR /usr/src/app

RUN mkdir teste

RUN mkdir logs

COPY package.json .

RUN npm i

COPY app.js .

EXPOSE 3000

# CMD ["node", "app"]
CMD ["sh", "-c", "node app > logs/app.log"]