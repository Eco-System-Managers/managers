# apps_work/financeiro — CLAUDE.md

A **comanda do cliente** e o fechamento de caixa do negócio.

Atenção ao nome: aqui não há carteira nem saldo pré-pago do cliente. A
plataforma não intermedeia o dinheiro do serviço — o pagamento é presencial, no
negócio. O que existe é um saldo de crédito **dentro de cada negócio**.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `models.py` | `TransacaoCredito` — o extrato da comanda, uma linha por movimento. `Despesa` — o custo do próprio negócio |
| `services.py` | `SaldoService` (o saldo e seus lançamentos), `CaixaService` (o fechamento por período), `DespesaService` (o resumo de despesas por categoria) e os ajudantes da cobrança dos dois modos (`conferir_total_da_cobranca`, `snapshot_do_servico`, `notificar_cobranca`) |
| `views.py` | Saldo de um cliente, os dados de caixa e o CRUD de despesas |
| `serializers.py` | Representação do extrato e da despesa, e o `CobrancaSerializer` — a entrada do `cobrar/` da agenda e do kanban |
| `signals.py` | Declara `cobranca_registrada`, que a vitrine escuta |

## Tabela

### `TransacaoCredito` — uma linha do extrato

| Coluna | Tipo | O que é |
|---|---|---|
| `cliente` | `FK → clientes.Cliente` `CASCADE` | Apagar o cliente leva o extrato junto |
| `tipo` | `CharField(10)` | `credito` ou `debito` |
| `valor` | `Decimal(10,2)` | Sempre positivo — quem define o sinal é o `tipo` |
| `origem` | `CharField(20)` = `manual` | `troco`, `manual`, `b2c`, `desconto_aplicado`, `taxa_cancelamento` |
| `descricao` | `CharField(255)` vazio | Texto exibido no extrato |
| `atendimento_kanban` | `FK → kanban.AtendimentoKanban` `SET_NULL`, nulo | De qual atendimento veio, quando veio de um |
| `agendamento` | `FK → agenda.Agendamento` `SET_NULL`, nulo | Idem, para o outro modo de agenda |
| `criado_em` | `DateTime` `auto_now_add` | |

As duas FKs de origem são `SET_NULL`: a linha do extrato precisa sobreviver ao
atendimento que a gerou. Ordenação padrão por `-criado_em`.

### `Despesa` — o custo do próprio negócio

| Coluna | Tipo | O que é |
|---|---|---|
| `descricao` | `CharField(255)` | Texto exibido na lista |
| `valor` | `Decimal(10,2)` | Sempre positivo — serializer rejeita `<= 0` |
| `categoria` | `CharField(30)` = `outros` | Lista fixa em `CATEGORIA_DESPESA_CHOICES` (`aluguel`, `agua_luz`, `internet_telefone`, `produtos`, `equipamentos`, `salarios`, `impostos`, `marketing`, `manutencao`, `outros`) |
| `data` | `DateField` | Competência: o dia em que a despesa ocorreu, não o de cadastro. Editável |
| `observacao` | `TextField` vazio | Opcional |
| `criado_em` / `atualizado_em` | `DateTime` | `auto_now_add` / `auto_now` |

Ordenação padrão por `-data, -criado_em`. Não tem FK — despesa é custo do
negócio, standalone (sem vínculo a cliente/colaborador). Lançamento avulso: não
há recorrência.

`DespesaService.resumo(data_inicio, data_fim)` devolve o total do período e a
quebra por categoria (`categoria`, `categoria_label`, `total`, `percentual`),
ordenada do maior gasto para o menor. O resultado do período
(receita − despesa) é calculado no cliente, cruzando este total com o
`CaixaService`.

CRUD em `/api/v1/financeiro/despesas/` (`DespesaViewSet`, paginado pela paginação padrão),
com filtros de query `data_inicio`/`data_fim`/`categoria`; o resumo em
`/api/v1/financeiro/despesas/resumo/`. Escrita exige `IsProprietario`.

## Como o saldo funciona

Não existe campo de saldo. Ele é **somado do extrato** a cada consulta:
créditos menos débitos. Isso evita o clássico problema de um contador que
dessincroniza do histórico.

| Origem | Quando acontece |
|---|---|
| `troco` | Crédito. O cliente pagou a mais e optou por deixar na comanda |
| `desconto_aplicado` | Débito. O saldo foi usado para abater um atendimento |
| `taxa_cancelamento` | Débito. Cancelou fora do prazo pelo app |
| `manual` | Lançamento do próprio negócio |
| `b2c` | Crédito vindo do app |

## O caixa

`CaixaService.obter_dados` junta pagamentos dos **dois modos** de agenda
(`PagamentoAgendamento` da agenda e `PagamentoAtendimento` da esteira) num período.

Filtrar por colaborador vale nos dois modos: na esteira o profissional do card é
opcional, então só entram os atendimentos atribuídos a ele.

Os kpis trazem `repasse` (a soma do que ficou congelado em cada pagamento como
comissão do parceiro) e `casa` (`total - repasse`). Cada pagamento traz o
próprio `repasse`.

O **avulso** da esteira (atendimento sem veículo nem pet, só com a
identificação; ver `kanban`) entra no caixa como qualquer outro, e a linha dele
traz `cliente_nome` = identificação ("Hilux branca"). Ele não tem comanda: a
cobrança recusa `credito_aplicado` e `troco_credito` (400 `avulso_sem_credito`,
no `kanban`), então nenhuma `TransacaoCredito` nasce dele.

Quem é o quê (`core/permissions.py`): o parceiro fecha **só o próprio caixa** (a
view troca o `colaborador` pedido pelo dele, `colaborador_aplicado`) e recebe
`casa` nulo — a parte da casa é assunto do dono. O colaborador comum não vê o
caixa: 403 `sem_acesso_a_valores`. Sem perfil de colaborador, 404
`sem_colaborador`.

## A cobrança (agenda e kanban)

O `cobrar/` dos dois modos recebe o mesmo `CobrancaSerializer`: `pagamentos`,
`desconto`, `credito_aplicado`, `troco_credito` e, desde o modo esteira com
horário, `acrescimo` (>= 0), `acrescimo_motivo` (até 60 caracteres) e
`servico_ids` (opcional, nunca vazio). A regra do total mora aqui, em
`conferir_total_da_cobranca`, para os dois modos fazerem a mesma conta:

```
total = serviços (depois da troca) + acrescimo − desconto
pagamentos + credito_aplicado == total      (senão 400 soma_invalida)
```

Cada modo faz a troca de serviço do seu jeito (um serviço na esteira, a lista
na agenda — ver o CLAUDE.md de cada um) e, no fim, chama `notificar_cobranca`,
que dispara `cobranca_registrada` com o total, o acréscimo, o motivo e o
retrato dos serviços (`snapshot_do_servico`: `{nome, nicho, duracao, preco,
taxa_cancelamento}`, dinheiro em string — o formato do `AgendamentoConsumidor`).
A esteira manda o mesmo sinal ao desfazer, com o acréscimo zerado.

## O que é fácil errar aqui

- **Aplicar crédito valida saldo disponível** e levanta `ValidationError` com
  `code: saldo_insuficiente` — o frontend depende desse código.
- **O acréscimo já está nos pagamentos.** Caixa e painel somam o `valor` dos
  pagamentos, então o acréscimo entra sozinho e não há o que somar por fora; só
  quem calcula por preço − desconto (as pendências, na `agenda`) precisa do
  `+ acrescimo`.
- **Taxa de cancelamento entra sem checar saldo.** É pendência, não consumo:
  pode deixar o saldo negativo, e é isso que se espera.
- **O saldo é por tenant.** O mesmo cliente pode ter crédito num negócio e
  dívida em outro; não há nada global.
- **`atendimento.objeto` pode ser nulo (o avulso da esteira).** No caixa, leia
  `atendimento.rotulo` ou `atendimento.cliente`, nunca `objeto.cliente` direto.
