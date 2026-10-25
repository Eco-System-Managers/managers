# apps_work/kanban — CLAUDE.md

Agendamento **por esteira** — o modo de quem recebe o objeto, trabalha nele e
devolve (lava-rápido, banho & tosa).

É o outro modo de agenda, alternativo ao app `agenda`. Aqui não existe "horário
do profissional": existe uma fila de etapas, e o atendimento anda por ela.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `models.py` | `EtapaKanban` (as colunas do quadro), `AtendimentoKanban` (o card) e `PagamentoAtendimento` |
| `services.py` | Traduz posição no quadro em status, cria etapas padrão, reordena colunas e cria o atendimento com checagem de horário |
| `views.py` | Os dois ViewSets, mais as ações `mover`, `cobrar`, `desfazer_cobranca` e `marcar_falta` |
| `serializers.py` | Representação do quadro |
| `signals.py` | Declara `atendimento_kanban_falta_alterada`, escutado pela vitrine |
| `urls.py` | Rotas sob `/api/v1/kanban/` |

## Tabelas

### `EtapaKanban` — as colunas do quadro

| Coluna | Tipo | O que é |
|---|---|---|
| `nome` | `CharField(100)` | Livre. O negócio nomeia as próprias etapas |
| `ordem` | `PositiveInteger` = 0 | **Define o status que o cliente vê** — primeira coluna é `aguardando`, última é `concluido` |
| `cor` | `CharField(7)` vazio | Hex, para o quadro |
| `criado_em` | `DateTime` `auto_now_add` | |

Ordenação padrão por `ordem`.

### `AtendimentoKanban` — o card

| Coluna | Tipo | O que é |
|---|---|---|
| `etapa` | `FK → EtapaKanban` `PROTECT` | Onde o card está agora. Não há campo de status |
| `objeto` | `FK → clientes.ObjetoCliente` `PROTECT` | O pet ou veículo — o cliente vem por ele |
| `servico` | `FK → servicos.Servico` `PROTECT` | Um só, diferente da agenda, que aceita vários |
| `observacao` | `TextField` vazio | |
| `data` | `DateField` nulo | Opcional: dá para receber sem hora marcada |
| `horario_entrada` | `TimeField` nulo | Idem |
| `pago` | `Boolean` = `False` | |
| `faltou` | `Boolean` = `False` | Estado à parte do avanço no quadro — falta não é coluna |
| `desconto` | `Decimal(8,2)` = 0 | |
| `criado_em` | `DateTime` `auto_now_add` | Também a ordenação padrão |

**Restrição de unicidade:** `data` + `horario_entrada`, aplicada só quando os
dois estão preenchidos. É o que impede dois atendimentos no mesmo horário sem
proibir o atendimento sem hora marcada.

### `PagamentoAtendimento`

| Coluna | Tipo | O que é |
|---|---|---|
| `atendimento` | `FK → AtendimentoKanban` `CASCADE` | Aceita vários pagamentos |
| `forma` | `CharField(20)` | `dinheiro`, `pix`, `credito`, `debito`, `qr_code` |
| `valor` | `Decimal(8,2)` | |
| `criado_em` | `DateTime` `auto_now_add` | |

## Como o status é derivado

Não existe campo de status no atendimento. `StatusClienteService` calcula a
partir da **posição da etapa no quadro**: primeira coluna vira `aguardando`,
última vira `concluido`, o meio vira `em_atendimento`.

A consequência é que renomear ou reordenar colunas muda o que o cliente vê no
app, sem migration nenhuma. É por isso que o app B2C lê esse status ao vivo em
vez de guardar cópia.

## A exceção: falta

Falta não é coluna do quadro, então não seria capturada pela leitura ao vivo.
Por isso `marcar_falta` dispara sinal e o público é atualizado explicitamente.
Ao desfazer, volta para `agendado` — e o ponto do quadro volta a valer.

## Filtros e ações

`kanban/atendimentos/?data=` é o quadro de um dia e `?cliente=` o histórico de
um cliente (pelos objetos dele); os dois estão no OpenAPI. As ações do card
são `POST .../{id}/mover/` (`{etapa_id}`), `cobrar/` (o `CobrancaSerializer`
do financeiro), `desfazer_cobranca/`, `marcar_falta/` e `desfazer_falta/`.
`kanban/etapas/reordenar/` recebe os ids na ordem final (`{"ordem": [3, 1,
2]}`; a posição vira a `ordem`) e ainda aceita a forma antiga `[{id, ordem}]`.
Remover etapa com atendimentos dentro responde 400 `etapa_com_atendimentos`
(`EtapaService.remover`): o FK é PROTECT, e sem isso a view caía em 500.

## O que é fácil errar aqui

- **O quadro do dia também vem paginado**, como a agenda: o front pede
  `?data=...&page_size=100` e segue o `next`. Página que não chega faria card
  sumir da coluna sem erro.
- **A grade de horas de entrada (`kanban/slots/`) depende da `capacidade`** do
  `HorarioFuncionamento` do dia: sem capacidade, nenhuma hora é oferecida e o
  atendimento só entra sem hora marcada.
- **Cobrar gera troco como crédito.** O excedente vira `TransacaoCredito` na
  comanda do cliente (app `financeiro`), não dinheiro devolvido.
- **Não dá para marcar falta em atendimento já pago** — a regra está em
  `ERRO_FALTA_EM_PAGO`.
- **O `AtendimentoKanban` pode nascer pelo app B2C**, via
  `apps_serv/vitrine/services.py`, criando `Pet`/`Veiculo` no tenant direto pelo
  ORM — sem passar pelos serializers deste app, portanto sem as validações deles.
