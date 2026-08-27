# Design: `.gitignore` raiz para `desafios_fundamentais`

## Objetivo

Evitar que artefatos locais de desenvolvimento sejam versionados no diretório `desafios_fundamentais`, começando pelo diretório `.idea/` e por arquivos temporários comuns de editor e sistema operacional.

## Escopo

Criar um arquivo `.gitignore` na raiz de `desafios_fundamentais` com regras para:

- `.idea/`
- `.DS_Store`
- `Thumbs.db`
- `*.swp`
- `*.swo`

## Fora de escopo

- Alterar `bia/.gitignore`
- Alterar `bia/.dockerignore`
- Alterar `.idea/.gitignore`
- Adicionar regras para arquivos de ambiente, dependências ou builds de `bia`

## Abordagem escolhida

Adicionar um `.gitignore` local e enxuto na raiz de `desafios_fundamentais`. Essa abordagem resolve o problema solicitado sem duplicar nem misturar regras específicas do projeto `bia`, que já possui seus próprios arquivos de ignore.

## Impacto esperado

- O Git deixará de sugerir arquivos locais de IDE e sistema nesse diretório de estudos.
- O comportamento do subprojeto `bia` permanece inalterado.

## Validação

Após criar o arquivo, verificar se o diretório `.idea/` e os padrões adicionados passam a ser ignorados pelo Git em `desafios_fundamentais`.
