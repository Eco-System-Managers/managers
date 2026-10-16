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
| `urls.py` | Rotas privadas sob `/api/contratos/` e a pública fora do prefixo |

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

## A parte pública

`ContratoPublicoView` fica **fora** do prefixo `/api/`, sem autenticação, e é
acessada por `schema_name` + `token` (UUID) na URL. É assim que o cliente abre e
assina o contrato sem ter conta no sistema.

A assinatura registra nome e IP de quem assinou, mais o horário.

## O que é fácil errar aqui

- **A view pública recebe `schema_name` da URL** e troca de schema com ele. É
  entrada de usuário e precisa ser tratada como tal.
- **O token é a única credencial** do contrato público. Ele é UUID e único —
  vazar o link é vazar o contrato.
- **A listagem é paginada e ordenada por `-criado_em, -id`.** O desempate por id
  não é decorativo: sem ele, contratos gerados no mesmo instante podem repetir
  numa página e sumir de outra.
