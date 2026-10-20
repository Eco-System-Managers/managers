# apps_work/autenticacao — CLAUDE.md

Entrada no sistema pelo lado do **negócio**, e a criação de um tenant novo.

É o par B2B do `apps_serv/autenticacao`. Aqui o usuário é um `User` do Django
dentro de um tenant; lá é um `Consumidor` no schema público.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `services.py` | `OnboardingService` — cria tenant, schema, domínio, usuário e assinatura de trial numa tacada. `RecuperacaoSenhaService`. E `SessaoService`, que emite, renova e revoga sessões |
| `views.py` | Cadastro, login, refresh por cookie, logout e as três etapas de recuperação de senha |
| `models.py` | `UltimaAtividade` (relógio de inatividade) e `CodigoRecuperacao` |
| `serializers.py` | Validação do cadastro, incluindo o slug do schema a partir do nome da empresa |
| `urls.py` | Rotas sob `/api/v1/auth/` — isentas do bloqueio de assinatura |

## Tabelas

### `UltimaAtividade` — o relógio de inatividade

| Coluna | Tipo | O que é |
|---|---|---|
| `user` | `OneToOne → auth.User` `CASCADE` | Uma linha por usuário |
| `ultimo_acesso` | `DateTimeField` | Escrito pelo `InactivityMiddleware`, com amortização de 60s |

### `CodigoRecuperacao` — recuperação de senha

| Coluna | Tipo | O que é |
|---|---|---|
| `user` | `FK → auth.User` `CASCADE` | |
| `codigo_hash` | `CharField(128)` | Hash do código (`make_password`). O código em claro só existe no e-mail |
| `criado_em` | `DateTime` `auto_now_add` | |
| `expira_em` | `DateTimeField` | Definido no `save()`: 15 minutos após a criação |
| `usado` | `Boolean` = `False` | Impede reuso do mesmo código |
| `tentativas` | `PositiveSmallInteger` = 0 | Trava em 5 (`MAX_TENTATIVAS`) |

Ordenação padrão por `-criado_em`. `expirado` e `bloqueado` são propriedades,
não colunas. Crie com `CodigoRecuperacao.emitir(user)`, que invalida os
códigos anteriores e devolve o código em claro para o e-mail; confira com
`registro.confere(codigo)`.

## O cadastro cria um tenant inteiro

`OnboardingService.registrar_empresa` é a operação mais pesada do app: cria o
`Tenant` (o django-tenants materializa o schema no Postgres e roda as
migrations nele), o `Domain`, o `User`, o `Membro` e uma `Assinatura` em
trial.

O `schema_name` sai de `gerar_schema_name` (`serializers.py`): só `[a-z0-9_]`,
prefixo `e_` quando começaria por dígito, por `pg_` ou seria um nome reservado,
e no máximo 56 caracteres de base. Nome repetido não bloqueia o cadastro: a
segunda "Barbearia Central" vira `barbearia_central_2`. Nome sem nenhuma letra
ou número aproveitável é recusado.

O domínio é `dominio_do_schema`: o `_` do schema vira `-` (underscore é
inválido em nome de host e o Django recusaria a requisição), com o sufixo de
`TENANT_DOMAIN_SUFFIX` (`localhost` por padrão).

Empresa nova sempre nasce com `onboarding_concluido=False` — é isso que faz o
frontend mandar o usuário para o wizard em vez do painel.

## Login por e-mail

Não há username separado: o campo `username` do `User` **guarda o próprio
e-mail** — e é por ele que login e recuperação buscam, porque o `username` é
único e o campo `email` do `User` não é.

O login responde no mesmo tempo com ou sem conta: quando o e-mail não existe,
calcula um hash fictício. Sem isso o tempo de resposta revelaria quem tem conta.

A recuperação nunca diz se o e-mail existe, e o e-mail sai por task
(`core/email.py`), fora da requisição: nem o tempo do SMTP nem um erro dele
aparecem na resposta. A lógica do código fica em `RecuperacaoSenhaService`. O JWT sai com dois claims customizados, `schema_name` e `empresa`, e é
por eles que o `JWTTenantMiddleware` descobre em qual schema trabalhar quando o
domínio não resolve (desenvolvimento e app mobile).

## Sessões

Toda sessão nasce no `SessaoService.emitir` — login, cadastro e aceite de
convite. Os tokens são assinados com chave própria do Work Manage
(`SIMPLE_JWT['SIGNING_KEY']`, derivada da `SECRET_KEY` ou definida em
`JWT_SIGNING_KEY_B2B`) e levam `aud`/`iss` `workmanage`.

- **Cada refresh vale uma vez.** `renovar` revoga o anterior (blacklist do
  SimpleJWT) e emite outro; reusar um refresh já usado dá 401. Renovar também
  confere usuário ativo, senha inalterada e vínculo com o tenant do token.
- **Logout revoga o refresh**, não só apaga o cookie.
- **Troca de senha derruba tudo.** `CHECK_REVOKE_TOKEN` grava um hash da senha
  no token, então access e refresh antigos param de valer na hora; o
  `encerrar_todas` ainda revoga os refresh pendentes. Desativar colaborador
  também chama o `encerrar_todas`.

O refresh vai **ou** no cookie httpOnly (web) **ou** no corpo (mobile), nunca
nos dois. O app mobile se identifica com `X-Client-Platform: mobile` e manda o
refresh no corpo; sem o cabeçalho, o refresh só é lido do cookie
(`core/sessao.py`). Só existe uma rota de refresh: `/api/v1/auth/token-refresh/`.

## `UltimaAtividade`

Uma linha por usuário, com o horário do último acesso. É lida e escrita pelo
`InactivityMiddleware` a cada requisição autenticada, com escrita amortizada
(só grava fora de uma janela de 60s). Sessão parada além de
`INACTIVITY_TIMEOUT_MINUTES` recebe 401 com `code: inactivity_timeout`.

## Rate limiting

Configuração em `REST_FRAMEWORK` (`core/settings.py`); classes em
`core/throttling.py` e `core/limites.py`.

- **Por IP:** escopos `auth_*` nas rotas daqui (B2B). O IP vem do
  `REMOTE_ADDR` (`NUM_PROXIES=0`) — sem isso o DRF usaria o `X-Forwarded-For`,
  que o cliente escreve, e qualquer limite por IP seria burlável.
- **Falhas de login por conta:** `login_work` (`core/limites.py`) bloqueia o
  e-mail com 10 falhas em 15 min, com 429 `muitas_tentativas`. Conta só falhas
  e o acerto zera: um throttle comum deixaria qualquer um travar o login de
  outra pessoa. Vale para qualquer e-mail, exista ou não.
- **Recuperação por conta:** `RecuperacaoPorEmailThrottle`, 5 códigos por hora
  por e-mail, independente do IP.
- O refresh e o logout não têm escopo: ficam com o throttle padrão de anônimo.

## O que é fácil errar aqui

- **Este app é compartilhado** (`SHARED_APPS`), não de tenant. Faz sentido: o
  `UltimaAtividade` precisa funcionar antes de o schema ser resolvido.
- **Usuário inativo é barrado na autenticação, não na permissão.** Desativar
  colaborador sincroniza `User.is_active=False`, e o SimpleJWT recusa o token em
  toda requisição — não só no login.
- **As rotas daqui estão isentas do controle de inatividade**, senão renovar
  sessão exigiria sessão válida.
