# apps_work/agenda — CLAUDE.md

Agendamento **por horário marcado** — o modo de agenda de quem trabalha com hora
marcada (barbearia, salão, clínica).

É um dos dois modos do produto. O outro é o `kanban` (esteira), usado por
lava-rápido e banho & tosa. Cada negócio usa **um** dos dois, definido por
`EmpresaConfig.tipo_agenda`.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `models.py` | `Agendamento`, `AgendamentoServico` (o N:N com preço congelado) e `PagamentoAgendamento` |
| `services.py` | Quatro serviços: dias com registro, pendências de cobrança, grade de horários livres e a regra de conflito |
| `views.py` | `AgendamentoViewSet` mais três views de leitura (slots, dias do mês, pendências) |
| `serializers.py` | Representação; o `create` monta agendamento e serviços juntos |
| `signals.py` | Declara `agendamento_status_alterado`, que a vitrine escuta |
| `urls.py` | Rotas sob `/api/v1/agendamentos/` e afins |

## Os três modelos

| Modelo | Papel |
|---|---|
| `Agendamento` | O compromisso: cliente, colaborador, data/hora, status |
| `AgendamentoServico` | Quais serviços, com `preco_cobrado` **congelado** no momento do agendamento — mudar a tabela de preços depois não reescreve o passado |
| `PagamentoAgendamento` | Como foi pago (dinheiro, PIX, crédito, débito, QR Code). Um agendamento pode ter mais de um |

## Tabelas

### `Agendamento` — o compromisso

| Coluna | Tipo | O que é |
|---|---|---|
| `cliente` | `FK → clientes.Cliente` `PROTECT` | Não dá para apagar cliente com agendamento |
| `colaborador` | `FK → usuarios.Colaborador` `PROTECT`, nulo | Nulo é permitido: sem profissional, não há conflito de agenda a checar |
| `data_hora` | `DateTimeField` | Início do compromisso. A duração vem dos serviços |
| `status` | `CharField(20)` = `agendado` | `agendado`, `confirmado`, `concluido`, `cancelado`, `faltou` |
| `desconto` | `Decimal(8,2)` = 0 | Desconto no total |
| `observacoes` | `TextField` vazio | Texto livre |
| `criado_em` | `DateTime` `auto_now_add` | |

### `AgendamentoServico` — quais serviços, com preço congelado

| Coluna | Tipo | O que é |
|---|---|---|
| `agendamento` | `FK → Agendamento` `CASCADE` | `related_name='servicos'` |
| `servico` | `FK → servicos.Servico` `PROTECT` | |
| `preco_cobrado` | `Decimal(8,2)` | **Congelado** no agendamento. Mudar a tabela de preços não reescreve o passado |
| `desconto` | `Decimal(8,2)` = 0 | Desconto neste item |

### `PagamentoAgendamento` — como foi pago

| Coluna | Tipo | O que é |
|---|---|---|
| `agendamento` | `FK → Agendamento` `CASCADE` | Um agendamento aceita vários pagamentos |
| `forma` | `CharField(20)` | `dinheiro`, `pix`, `credito`, `debito`, `qr_code` |
| `valor` | `Decimal(8,2)` | |
| `criado_em` | `DateTime` `auto_now_add` | |

## A regra de conflito

Está em `AgendamentoService._verificar_conflito`. Dois agendamentos do **mesmo
colaborador** não podem se sobrepor, considerando a duração dos serviços — não
apenas o horário de início.

Quem não tem colaborador definido não entra na checagem: sem profissional, não
há recurso disputado.

## Filtros da listagem

`?data=` (um dia), `?colaborador=` e `?cliente=`, documentados no OpenAPI. A
listagem exclui os cancelados; o detalhe (`/agendamentos/<id>/`) não. O app
cancela por `PATCH status=cancelado` — o `DELETE` apaga o registro e não
dispara o sinal de status.

## Paginação

A listagem é sempre paginada (`core/paginacao.py`), inclusive com `?data=` —
antes o dia saía como array e a mesma rota tinha dois formatos. A grade do dia
monta a linha do tempo com todos os agendamentos daquela data, então o front
pede `?page_size=100` e **segue o `next`** se ele vier: uma página que não chega
faria horário sumir da tela sem erro nenhum.

## O que é fácil errar aqui

- **Status alterado aqui precisa chegar ao app do cliente.** Quem faz isso é o
  sinal `agendamento_status_alterado`, escutado por `apps_serv/vitrine/handlers.py`.
  Alterar status por `.update()` direto no queryset pula o sinal.
- **Agendamento nascido no app tem contraparte no schema público.** O que nasce
  no balcão não tem — o filtro do handler simplesmente não encontra nada, e está
  certo assim.
- **Duração vem dos serviços, não do agendamento.** Não existe campo de duração;
  ela é sempre a soma dos serviços vinculados.
