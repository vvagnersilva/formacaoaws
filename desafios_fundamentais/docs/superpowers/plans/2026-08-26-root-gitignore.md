# Root `.gitignore` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Criar um `.gitignore` na raiz de `desafios_fundamentais` para impedir que artefatos locais de IDE e sistema sejam versionados.

**Architecture:** A mudança fica isolada na raiz de `desafios_fundamentais`, sem tocar nos arquivos de ignore já existentes dentro de `bia/` ou `.idea/`. A validação usa o próprio Git para confirmar que os padrões passaram a ser ignorados.

**Tech Stack:** Git, `.gitignore`

## Global Constraints

- Criar apenas `desafios_fundamentais/.gitignore`.
- Incluir exatamente os padrões `.idea/`, `.DS_Store`, `Thumbs.db`, `*.swp` e `*.swo`.
- Não alterar `bia/.gitignore`.
- Não alterar `bia/.dockerignore`.
- Não alterar `.idea/.gitignore`.
- Não adicionar regras para ambientes, dependências ou builds de `bia`.

---

### Task 1: Criar o `.gitignore` da raiz

**Files:**
- Create: `desafios_fundamentais/.gitignore`
- Verify: `desafios_fundamentais/.idea/`
- Verify: `desafios_fundamentais/docs/superpowers/specs/2026-08-26-root-gitignore-design.md`

**Interfaces:**
- Consumes: Nenhuma interface de código; usa apenas o estado atual do diretório `desafios_fundamentais`.
- Produces: Arquivo `desafios_fundamentais/.gitignore` com o conteúdo:

```gitignore
.idea/
.DS_Store
Thumbs.db
*.swp
*.swo
```

- [ ] **Step 1: Confirmar o estado atual**

Run:

```bash
cd /home/wasilva/formacaoaws/desafios_fundamentais && find . -maxdepth 2 \( -name '.gitignore' -o -name '.ignore' -o -name '.dockerignore' \) | sort
```

Expected: mostrar `./bia/.gitignore`, `./bia/.dockerignore` e `./.idea/.gitignore`, sem `.gitignore` na raiz.

- [ ] **Step 2: Criar o arquivo com o conteúdo mínimo**

Write `desafios_fundamentais/.gitignore` with:

```gitignore
.idea/
.DS_Store
Thumbs.db
*.swp
*.swo
```

- [ ] **Step 3: Verificar se o diretório `.idea/` passou a ser ignorado**

Run:

```bash
cd /home/wasilva/formacaoaws/desafios_fundamentais && git check-ignore -v .idea/workspace.xml
```

Expected: saída apontando para `desafios_fundamentais/.gitignore` e a regra `.idea/`.

- [ ] **Step 4: Verificar se as outras regras foram registradas corretamente**

Run:

```bash
cd /home/wasilva/formacaoaws/desafios_fundamentais && cat .gitignore
```

Expected: o arquivo contém exatamente `.idea/`, `.DS_Store`, `Thumbs.db`, `*.swp` e `*.swo`, uma regra por linha.

- [ ] **Step 5: Revisar o impacto no Git**

Run:

```bash
cd /home/wasilva/formacaoaws && git --no-pager status --short --ignored -- desafios_fundamentais
```

Expected: `.idea/` aparece como ignorado, e não há mudanças em `bia/.gitignore`, `bia/.dockerignore` ou `.idea/.gitignore`.

- [ ] **Step 6: Commit**

```bash
cd /home/wasilva/formacaoaws && git add desafios_fundamentais/.gitignore && git commit -m "chore: ignore local IDE files in desafios_fundamentais" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```
