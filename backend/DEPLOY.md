# Deploy — Railway

A API roda no Railway; o domínio é **`api.workmanage.com.br`** (DNS na
Hostinger). Atenção ao nome: **workmanage**, sem "r" — `workmanager.com.br` é
de outra pessoa.

Este arquivo guarda o que está configurado fora do código e o que falta para
lançar. Nada de senha ou chave aqui: os valores ficam só nas variáveis do
Railway.

## O serviço da API

O projeto do Railway tem três serviços: a API (este repositório), **Postgres**
e **Redis**.

A configuração da API fica **no painel** (Settings do serviço), não em arquivo:
o Railway descontinuou o Config as Code (`railway.toml`/`railway.json`) e
serviço que nunca usou não consegue mais ativar.

| Onde | Campo | Valor |
|---|---|---|
| Source | Root Directory | `/backend` |
| Build | Custom Build Command | `python manage.py collectstatic --noinput` |
| Deploy | Pre-deploy Command | `python manage.py migrate_schemas` |
| Deploy | Custom Start Command | `gunicorn core.wsgi:application` |
| Deploy | Restart Policy | On Failure, 5 tentativas |
| Networking | Custom Domain | `api.workmanage.com.br` (porta 8080) |

- O builder é o Railpack; ele lê a versão do Python de `.python-version`.
- O **pre-deploy** roda antes de cada deploy entrar no ar e migra o `public` e
  todos os tenants. Se falhar, o deploy é abortado e a versão anterior continua
  servindo. Sem ele, migration nova não chega ao banco.
- O gunicorn escuta em `0.0.0.0:$PORT` sozinho e lê o número de workers de
  `WEB_CONCURRENCY`.
- O **build** gera os estáticos do `/admin/`, servidos pelo WhiteNoise. Sem
  ele, o admin abre sem estilo.

## Variáveis de ambiente

A lista completa, com os valores de exemplo, está em `.env.example`. Em
produção:

| Variável | Valor | Observação |
|---|---|---|
| `SECRET_KEY` | gerada uma vez | Nunca trocar depois de no ar |
| `HTTPS` | `True` | Liga redirect, cookies seguros e HSTS |
| `NUM_PROXIES` | `1` | O proxy do Railway na frente. Sem ela, com `HTTPS=True`, o redirect entra em laço |
| `DB_NAME` · `DB_USER` · `DB_PASSWORD` · `DB_HOST` · `DB_PORT` | `${{Postgres.PGDATABASE}}` · `PGUSER` · `PGPASSWORD` · `PGHOST` · `PGPORT` | Referências à rede privada |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` | |
| `ALLOWED_HOSTS` | `api.workmanage.com.br` | O domínio `*.up.railway.app` entra sozinho (`RAILWAY_PUBLIC_DOMAIN`) |
| `TENANT_DOMAIN_SUFFIX` | `tenants.workmanage.com.br` | **Nunca** o domínio da API nem um pai dele: uma empresa chamada "Api" ganharia `api.<sufixo>` |
| `LINKS_BASE_URL` | `https://api.workmanage.com.br` | Links de convite, contrato e volta do checkout |
| `MERCADOPAGO_BACK_URL` | `https://api.workmanage.com.br` | Fixada no plano do MP ao rodar `configurar_plano` |
| `PRIVACIDADE_RESPONSAVEL` · `PRIVACIDADE_EMAIL` | o seu nome (ou a empresa) e o e-mail de privacidade | Aparecem na política de privacidade (`/privacidade`), que as lojas exigem |
| `ASSINATURA_ABERTA` | `False` | `True` só com o Mercado Pago pronto. Desligada, o app mostra "Em breve" e a API recusa o checkout (`assinatura_em_breve`) |
| `AWS_ACCESS_KEY_ID` · `AWS_SECRET_ACCESS_KEY` · `AWS_STORAGE_BUCKET_NAME` · `AWS_S3_REGION_NAME` | | Obrigatórias: os uploads vão sempre para o S3, e o disco do Railway é apagado a cada deploy |
| `MERCADOPAGO_ACCESS_TOKEN` · `MERCADOPAGO_PUBLIC_KEY` | `APP_USR-...` | Credenciais de **produção**, não `TEST-` |
| `MERCADOPAGO_WEBHOOK_SECRET` | | A assinatura secreta do webhook |
| `RESEND_API_KEY` | `re_...` | O Railway bloqueia SMTP nos planos Trial e Hobby |
| `DEFAULT_FROM_EMAIL` | `Work Manage <noreply@workmanage.com.br>` | Domínio verificado no Resend |

`DEBUG` fica sem definir (o padrão é `False`).

## Terminal no servidor

No painel: botão direito no serviço da API → **Copy SSH Command**. Lá dentro o
`python` não está no PATH; ative o venv antes:

```bash
source /app/.venv/bin/activate
```

Conferências úteis:

```bash
python manage.py check --deploy
python manage.py showmigrations > /tmp/m.txt && (grep "\[ \]" /tmp/m.txt || echo "tudo migrado")
python manage.py shell -c "from django.core.cache import cache; cache.set('t', 1); print(cache.get('t'), cache.__class__.__name__)"
```

O esperado: nenhum problema, `tudo migrado` e `1 RedisCache`.

## O que é fácil errar

- **Referência com nome de serviço errado vira valor vazio, sem aviso.**
  `${{Postgres.PGDATABASE}}` só funciona se o serviço se chamar exatamente
  `Postgres`. Com o nome errado, `DB_NAME` chega vazio e o Django falha com
  `settings.DATABASES is improperly configured`. Ao digitar `${{` no editor,
  o Railway sugere os nomes certos.
- **Variável nova não chega a uma sessão SSH já aberta.** Salvar variável faz
  deploy num container novo; saia e entre de novo.
- **Rede privada, não pública.** A API usa `PGHOST`/`REDIS_URL` (endereços
  `*.railway.internal`). `DATABASE_PUBLIC_URL` é só para acessar o banco do
  seu computador.

## Para lançar

Estado em 2026-10-27:

- [x] Postgres e Redis ligados; migrations aplicadas; `check --deploy` limpo;
  superusuário criado
- [x] Comandos de build, pre-deploy e start no painel
- [x] DNS de `api.workmanage.com.br` na Hostinger (CNAME `api` e TXT
  `_railway-verify.api`, os valores que o Railway mostra) e certificado
  emitido: a API responde em HTTPS (conferido em 2026-10-29)
- [ ] Variáveis restantes (tabela acima)
- [ ] **Resend:** adicionar `workmanage.com.br`, criar os registros DNS na
  Hostinger, gerar a chave → `RESEND_API_KEY` e `DEFAULT_FROM_EMAIL`
- [ ] **Webhook do Mercado Pago** (modo produção):
  `https://api.workmanage.com.br/api/v1/billing/webhook/mercadopago/`, eventos
  **Pagamentos** e **Planos e assinaturas** → `MERCADOPAGO_WEBHOOK_SECRET`
- [ ] **Preço do plano**, só com o domínio verde e `MERCADOPAGO_BACK_URL`
  certa: `python manage.py configurar_plano --preco 49,90` no SSH. Conferir
  que a URL de retorno impressa começa com `https://api.workmanage.com.br`.
  Mudar o preço depois é rodar de novo (ver `apps_work/billing/CLAUDE.md`)
- [x] App Flutter apontando para `https://api.workmanage.com.br` (o padrão do `env.dart`)
- [ ] Teste de ponta a ponta: cadastro (o e-mail chega?), convite com criação
  de senha pelo link, assinatura real e liberação do acesso
- [x] **Variáveis da política de privacidade:** `PRIVACIDADE_RESPONSAVEL`
  e `PRIVACIDADE_EMAIL` (`contato@workmanage.com.br`, que já recebe). Depois
  do deploy, abrir `https://api.workmanage.com.br/privacidade` e conferir
- [x] **Cron diário da exclusão de contas** (serviço `cron-exclusao`, criado
  em 2026-10-29). Sem ele, quem pede para excluir a conta fica travado e nunca é
  apagado de verdade. Ver "O cron da exclusão de contas" abaixo
- [ ] Backup do Postgres: ativar na aba Backups do serviço, se o plano oferecer

## O cron da exclusão de contas

Quem pede para excluir a conta pelo app fica travado na hora e é apagado de
vez 30 dias depois, pelo comando `excluir_contas_vencidas`. Rodar no console
uma vez não basta: ele precisa rodar todo dia sozinho. No Railway isso é um
**segundo serviço**, com o mesmo código da API, que roda o comando e desliga.

1. No projeto: **+ New › GitHub Repo**, o mesmo repositório da API. Nome
   sugerido: `cron-exclusao`.
2. **Settings** do serviço novo:
   - Root Directory: `/backend`, e a mesma branch da API
   - Custom Build Command: `python manage.py collectstatic --noinput`
   - Pre-deploy Command: **vazio** (as migrations já rodam na API)
   - Custom Start Command: `python manage.py excluir_contas_vencidas`
   - Cron Schedule: `0 9 * * *` (o Railway usa UTC: é 6h em Brasília)
   - Restart: **Never** (o cron termina sozinho)
3. **Variables**, por referência às do serviço da API (`${{<nome do
   serviço>.VAR}}`; nome errado vira variável vazia, sem aviso): as `DB_*`,
   `SECRET_KEY`, `REDIS_URL` e `MERCADOPAGO_ACCESS_TOKEN` (para cancelar uma
   assinatura recorrente do dono que pediu a exclusão).
4. Conferir na aba **Deployments** do cron: cada execução termina com
   `N conta(s) excluída(s).`
