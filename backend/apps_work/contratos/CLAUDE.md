# apps_work/contratos — CLAUDE.md

Contrato entre o negócio e o cliente: **gerar a partir de um modelo, enviar e
colher a assinatura**.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `models.py` | `ModeloContrato` (o texto com variáveis) e `Contrato` (a instância gerada para um cliente) |
| `services.py` | Substituição de variáveis, geração, envio por e-mail, assinatura e recusa |
| `views.py` | ViewSets de modelo e contrato, mais a view **pública** de assinatura |
| `serializers.py` | Representação, incluindo a versão pública, que expõe menos |
| `urls.py` | Rotas privadas sob `/api/v1/contratos/` e a pública em `/api/v1/contratos/publico/` |

## Tabelas

### `ModeloContrato` — o texto reaproveitável

| Coluna | Tipo | O que é |
|---|---|---|
| `titulo` | `CharField(255)` | |
| `corpo` | `TextField` | Texto com variáveis: `{{cliente_nome}}`, `{{cliente_email}}`, `{{cliente_cpf}}`, `{{data}}`, `{{negocio_nome}}` |
| `ativo` | `Boolean` = `True` | |
| `criado_em` | `DateTime` `auto_now_add` | Também a ordenação (`-criado_em`) |
| `atualizado_em` | `DateTime` `auto_now` | |

### `Contrato` — a instância gerada para um cliente

| Coluna | Tipo | O que é |
|---|---|---|
| `modelo` | `FK → ModeloContrato` `SET_NULL`, nulo | `SET_NULL` porque o contrato sobrevive à remoção do modelo — o texto já está congelado |
| `cliente` | `FK → clientes.Cliente` `CASCADE` | |
| `titulo` | `CharField(255)` | Cópia do modelo no momento da geração |
| `corpo` | `TextField` | **Texto congelado**, com as variáveis já substituídas |
| `status` | `CharField(20)` = `pendente` | `pendente`, `enviado`, `assinado`, `recusado` |
| `token` | `UUIDField` único, não editável | A única credencial da página pública de assinatura |

Registro da assinatura:

| Coluna | Tipo | O que é |
|---|---|---|
| `nome_assinante` | `CharField(255)` vazio | Quem digitou o nome ao assinar |
| `ip_assinante` | `GenericIPAddressField` nulo | De onde veio a assinatura |
| `assinado_em` | `DateTimeField` nulo | Quando |
| `criado_em` · `atualizado_em` | `DateTime` | Ordenação por `-criado_em` |

## Modelo → contrato

`ModeloContrato.corpo` aceita variáveis (`{{cliente_nome}}`, `{{cliente_cpf}}`,
`{{data}}`, `{{negocio_nome}}`). Ao gerar, `ContratoService` substitui e
**congela o texto** no `Contrato`.

O congelamento importa: mudar o modelo depois não reescreve contratos já
gerados. O que a pessoa assinou continua sendo o que ela viu.

## O fluxo do app (Work Manage)

O app não usa o link de assinatura: ele **gera o PDF** do contrato e abre a
folha de compartilhar do aparelho (WhatsApp, e-mail). O que acontece fora do
sistema o dono registra em `POST contratos/{id}/marcar/` com `status`:

| De | Para | Regra |
|---|---|---|
| `pendente` | `enviado` | PDF compartilhado. De outro status → 400 `contrato_ja_enviado` |
| `pendente`/`enviado` | `assinado` | `nome_assinante` opcional (vazio usa o nome do cliente); `ip_assinante` fica nulo: a assinatura não veio pelo link |
| `pendente`/`enviado` | `recusado` | |
| `assinado`/`recusado` | qualquer | 400 `contrato_finalizado` |

`DELETE contratos/{id}/` recusa contrato assinado (400 `contrato_assinado`).
A lista filtra por `?cliente=` e `?status=`; modelos filtram por `?ativo=`.

**Modelo só o proprietário escreve** (`IsProprietario` em criar, editar e
apagar); qualquer um da equipe lista e gera contrato com ele. O app não apaga
modelo: inativa por `PATCH ativo`, como faz com serviço.

## A parte pública

`ContratoPublicoView` fica em `/api/v1/contratos/publico/<schema>/<token>/`,
sem autenticação, e é acessada por `schema_name` + `token` (UUID) na URL. Está
isenta do bloqueio de assinatura (`core/middleware.py`): quem assina é o
cliente, não o negócio. É assim que o cliente abre e
assina o contrato sem ter conta no sistema.

A assinatura registra nome e IP de quem assinou, mais o horário.

O link do e-mail (`/contrato/<schema>/<token>`) abre a página HTML de
`apps_work/paginas`, que lê e assina pelos mesmos caminhos da API:
`contrato_publico()` (a checagem de schema e token, em `services.py`) e
`ContratoService.assinar`/`recusar`.

## O que é fácil errar aqui

- **O `schema_name` da rota pública é entrada do usuário.** `ContratoPublicoView`
  só troca de schema se ele passar em `core.schemas.schema_valido` (formato, e
  nunca `public`) e existir um `Tenant` com ele; senão responde 404. Antes, um
  schema inexistente dava 500.

- **A view pública recebe `schema_name` da URL** e troca de schema com ele. É
  entrada de usuário e precisa ser tratada como tal.
- **O token é a única credencial** do contrato público. Ele é UUID e único —
  vazar o link é vazar o contrato.
- **A listagem é paginada e ordenada por `-criado_em, -id`.** O desempate por id
  não é decorativo: sem ele, contratos gerados no mesmo instante podem repetir
  numa página e sumir de outra.
