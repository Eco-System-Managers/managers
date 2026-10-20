# apps_work/financeiro — CLAUDE.md

A **comanda do cliente** e o fechamento de caixa do negócio.

Atenção ao nome: aqui não há carteira nem saldo pré-pago do cliente. A
plataforma não intermedeia o dinheiro do serviço — o pagamento é presencial, no
negócio. O que existe é um saldo de crédito **dentro de cada negócio**.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `models.py` | `TransacaoCredito` — o extrato da comanda, uma linha por movimento. `Despesa` — o custo do próprio negócio |
| `services.py` | `SaldoService` (o saldo e seus lançamentos), `CaixaService` (o fechamento por período) e `DespesaService` (o resumo de despesas por categoria) |
| `views.py` | Saldo de um cliente, os dados de caixa e o CRUD de despesas |
| `serializers.py` | Representação do extrato e da despesa |

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

CRUD em `/api/financeiro/despesas/` (`DespesaViewSet`, paginado pela paginação padrão),
com filtros de query `data_inicio`/`data_fim`/`categoria`; o resumo em
`/api/financeiro/despesas/resumo/`. Escrita exige `IsProprietario`.

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
(`Pagamento` da agenda e `PagamentoKanban` da esteira) num período.

Detalhe que já causou confusão: atendimento de esteira não tem colaborador
vinculado. Filtrar o caixa por colaborador exclui esses registros por completo —
por isso o filtro só é aplicado quando um colaborador é informado.

## O que é fácil errar aqui

- **Aplicar crédito valida saldo disponível** e levanta `ValidationError` com
  `code: saldo_insuficiente` — o frontend depende desse código.
- **Taxa de cancelamento entra sem checar saldo.** É pendência, não consumo:
  pode deixar o saldo negativo, e é isso que se espera.
- **O saldo é por tenant.** O mesmo cliente pode ter crédito num negócio e
  dívida em outro; não há nada global.
