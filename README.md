# MINASGRAN - API no Netlify DB

Substitui o Supabase mantendo as mesmas URLs (`/rest/v1/...` e `/auth/v1/token`), então o painel e os programas da fábrica mudam só o endereço e a chave.

## Passo a passo

1. No Netlify, crie um site (pode ser o próprio site do painel) e adicione um **Netlify DB** em *Extensions/Database*.
2. Copie a pasta `netlify/functions/` e o `package.json` para a raiz do projeto do site. Rode `npm install @netlify/database` (isso grava a dependência com versão fixa). Faça o deploy.
3. Em *Site settings > Environment variables*, crie:
   - `AUTH_SECRET`: texto longo e aleatório (ex.: 64 caracteres).
   - `SERVICE_KEY`: outra chave longa e aleatória. Ela vai no `config.json` dos programas da fábrica.
4. Crie o banco: rode no SQL do Netlify DB, nesta ordem:
   - `sql/01-banco.sql` (tabelas + funções)
   - `sql/02-login-painel.sql` (login sem devolver senha)
   - `sql/03-conta-painel.sql` (edite email e senha antes)
5. Teste: `GET https://SEU-SITE/rest/v1/config_balanca` com o cabeçalho `Authorization: Bearer SERVICE_KEY` deve devolver `[]`.

## Regras de acesso

- Tabelas `acesso_painel` e `acesso_admin` não são expostas pela API.
- `PATCH` e `DELETE` exigem filtro (não apagam a tabela inteira).
- O painel recebe um token que vale 1 hora e renova por 30 dias.
- Os programas usam `SERVICE_KEY` e têm acesso total, como antes com a `service_role`.

## Pendências conhecidas

- Encarregados sem senha definida entram com o próprio nome como senha (comportamento antigo, mantido). Para trocar, use `definir_senha_encarregado` ou a aba de Configuração.
- Funções `medias_diarias_ihm_v2` e `media_ihm_periodo` não estavam no export; o painel usa fallback.
- Histórico será carregado depois, a partir da planilha.
- Os arquivos de `sql/` ainda não foram executados num banco real.
