## Projeto base para o evento Imersão AWS & IA que irei realizar.

### Período do evento: 01/08 e 02/08/2026 (Online e ao Vivo das 9h30 às 17h30)

[>> Página de Inscrição do evento](https://org.imersaoaws.com.br/github/readme)

---

## Como rodar a aplicação

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
docker compose exec bia bash -c 'npx sequelize db:migrate'
```

