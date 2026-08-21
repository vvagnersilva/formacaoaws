## Projeto base para o evento Imersão AWS & IA que irei realizar.

### Período do evento: 01/08 e 02/08/2026 (Online e ao Vivo das 9h30 às 17h30)

[>> Página de Inscrição do evento](https://org.imersaoaws.com.br/github/readme)

---

## Arquitetura AWS e Serviços Utilizados

![Diagrama de Arquitetura AWS](./diagrama-aws.png)

Este diagrama mostra os principais blocos de uma arquitetura AWS, com foco em computação, bancos de dados, mensageria, orquestração, IA/ML, rede, observabilidade e segurança.

---

## Como rodar a aplicação

### Build da imagem Docker

```bash
docker compose build server
```

Isso vai fazer build apenas da aplicação Node.js. Use esse comando quando tiver alterado o código e quiser recompilar a imagem.

### Subindo a aplicação com Docker Compose

```bash
docker compose up
```

Isso vai fazer build da imagem e iniciar os 3 serviços:
- **bia** (aplicação Node.js) → http://localhost:3001
- **database** (PostgreSQL 17.1) → localhost:5434
- **redis** (Valkey) → localhost:6379

Para rodar em background (detached mode):
```bash
docker compose up -d
```

### Parando a aplicação

```bash
docker compose down
```

### Ver logs

```bash
docker compose logs -f
```

### Rodando migrations no banco de dados

```bash
docker compose exec server bash -c 'npx sequelize db:migrate'
```

---

## Notas Técnicas

### Mapeamento de Portas

O arquivo `compose.yml` mapeia as portas da seguinte forma:

```yaml
ports:
  - 3001:8080  # Host:Container
```

**Como acessar:**
- De fora do container: `http://localhost:3001`
- De dentro do container: `http://localhost:8080`

### Exemplo de Uso

### Entendimento sobre o acesso externo e dentro do container -->  ports: - 3001:8080 (no compose.yml)

O mapeamento de portas `3001:8080` significa:
- **Acesso EXTERNO** (de fora do container, do seu computador): use a porta **3001**
  - Exemplo: `curl http://localhost:3001/api/versao`
- **Acesso INTERNO** (dentro do container): use a porta **8080**
  - Exemplo: `curl http://localhost:8080/api/versao`

wasilva@Dell:~/formacaoaws/bia$ docker ps

CONTAINER ID   IMAGE                      COMMAND                  CREATED          STATUS         PORTS                                         NAMES
080bfba1cf69   68644b5c42bd               "docker-entrypoint.s…"   25 minutes ago   Up 3 minutes   0.0.0.0:3001->8080/tcp, [::]:3001->8080/tcp   bia
5bc5781b7c7d   postgres:17.1              "docker-entrypoint.s…"   25 minutes ago   Up 3 minutes   0.0.0.0:5434->5432/tcp, [::]:5434->5432/tcp   database
a38455a28e0b   valkey/valkey:8.1-alpine   "docker-entrypoint.s…"   25 minutes ago   Up 3 minutes   0.0.0.0:6379->6379/tcp, [::]:6379->6379/tcp   redis

docker exec -ti 080bfba1cf69 bash

root@080bfba1cf69:/usr/src/app# curl http://localhost:8080/api/versao
Bia 4.3.0