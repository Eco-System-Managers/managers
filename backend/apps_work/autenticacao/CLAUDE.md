# apps_work/autenticacao — CLAUDE.md

Entrada no sistema pelo lado do **negócio**, e a criação de um tenant novo.

É o par B2B do `apps_serv/autenticacao`. Aqui o usuário é um `User` do Django
dentro de um tenant; lá é um `Consumidor` no schema público.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `services.py` | `OnboardingService` — cria tenant, schema, domínio, usuário e assinatura de trial numa tacada. E `RecuperacaoSenhaService` |
| `views.py` | Cadastro, login, refresh por cookie, logout e as três etapas de recuperação de senha |
| `models.py` | `LastActivity` (relógio de inatividade) e `CodigoRecuperacao` |
| `serializers.py` | Validação do cadastro, incluindo o slug do schema a partir do nome da empresa |
| `urls.py` | Rotas sob `/auth/` — fora do prefixo `/api/` |

## Tabelas

### `LastActivity` — o relógio de inatividade

| Coluna | Tipo | O que é |
|---|---|---|
| `user` | `OneToOne → auth.User` `CASCADE` | Uma linha por usuário |
| `ultimo_acesso` | `DateTimeField` | Escrito pelo `InactivityMiddleware`, com amortização de 60s |

### `CodigoRecuperacao` — recuperação de senha

| Coluna | Tipo | O que é |
|---|---|---|
| `user` | `FK → auth.User` `CASCADE` | |
| `codigo` | `CharField(8)` | |
| `criado_em` | `DateTime` `auto_now_add` | |
| `expira_em` | `DateTimeField` | Definido no `save()`: 15 minutos após a criação |
| `usado` | `Boolean` = `False` | Impede reuso do mesmo código |

Ordenação padrão por `-criado_em`. A propriedade `expirado` compara com o
horário atual — não há campo booleano para isso.

## O cadastro cria um tenant inteiro

`OnboardingService.registrar_empresa` é a operação mais pesada do app: gera o
`schema_name` a partir do nome da empresa, cria o `Tenant` (o django-tenants
materializa o schema no Postgres e roda as migrations nele), o `Domain`, o
`User`, o `UserTenant` e uma `Assinatura` em trial.

Empresa nova sempre nasce com `onboarding_concluido=False` — é isso que faz o
frontend mandar o usuário para o wizard em vez do painel.

## Login por e-mail

Não há username separado: o campo `username` do `User` **guarda o próprio
e-mail**. O JWT sai com dois claims customizados, `schema_name` e `empresa`, e é
por eles que o `JWTTenantMiddleware` descobre em qual schema trabalhar quando o
domínio não resolve (desenvolvimento e app mobile).

O refresh sai em cookie httpOnly **e** no corpo — o corpo existe para o app
mobile, que não gerencia cookie como navegador.

## `LastActivity`

Uma linha por usuário, com o horário do último acesso. É lida e escrita pelo
`InactivityMiddleware` a cada requisição autenticada, com escrita amortizada
(só grava fora de uma janela de 60s). Sessão parada além de
`INACTIVITY_TIMEOUT_MINUTES` recebe 401 com `code: inactivity_timeout`.

## O que é fácil errar aqui

- **Este app é compartilhado** (`SHARED_APPS`), não de tenant. Faz sentido: o
  `LastActivity` precisa funcionar antes de o schema ser resolvido.
- **Usuário inativo é barrado na autenticação, não na permissão.** Desativar
  colaborador sincroniza `User.is_active=False`, e o SimpleJWT recusa o token em
  toda requisição — não só no login.
- **As rotas daqui estão isentas do controle de inatividade**, senão renovar
  sessão exigiria sessão válida.
