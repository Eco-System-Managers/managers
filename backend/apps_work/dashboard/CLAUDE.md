# apps_work/dashboard — CLAUDE.md

A **tela inicial do painel** ("Início" no app): os números de um período,
comparados com o período anterior, com filtro por profissional.

App mínimo — sem model e sem migration. Ele não guarda nada, só lê e agrega o
que os outros apps já registraram.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `services.py` | `DashboardService.obter_resumo(data_inicio, data_fim, colaborador_id)` — toda a lógica está aqui |
| `views.py` | Uma view só: valida os parâmetros, aplica a trava do colaborador e delega |
| `serializers.py` | Só o formato de saída, para o OpenAPI |
| `urls.py` | Uma rota: `dashboard/resumo/` |

## O contrato

`GET dashboard/resumo/?data_inicio&data_fim&colaborador`

- Sem datas, o período é **hoje**. `data_fim < data_inicio` ou data mal formada
  → 400 `parametros_invalidos`.
- `periodo` devolve o intervalo aplicado e o de comparação
  (`anterior_inicio..anterior_fim`): mesmo tamanho, terminando na véspera. Hoje
  compara com ontem; uma semana, com a semana anterior.
- `colaborador` devolve o id aplicado — o que o dono pediu, ou o próprio para
  quem não é proprietário.
- `agendamentos_hoje` é sempre o dia de hoje, independente do período: é "o
  que vem agora", não um relatório.

## A trava do colaborador

Quem não é proprietário (`Membro.papel`) vê **só os próprios números**: a view
troca o `colaborador` pedido pelo `request.user.colaborador.id`, seja o que for
que veio na query (`core.permissions.colaborador_aplicado`, a mesma trava do
caixa). Usuário sem `Colaborador` → 404 `sem_colaborador`. A trava fica no
backend porque na tela bastaria trocar o parâmetro.

## Por que não tem `models.py` nem `apps.py`

Porque não há dado próprio. Ele é uma **visão de leitura** sobre agenda, kanban,
financeiro e clientes. Guardar número consolidado aqui criaria um segundo lugar
onde a verdade pode divergir. Por isso também não aparece em `TENANT_APPS` —
só as `urls` são incluídas no `core/urls.py`.

## A variação percentual

`_var(atual, anterior)` compara o período corrente com o anterior. Devolve
`None` quando não há base de comparação — o app usa isso para não mostrar
"+∞%" no primeiro dia do negócio.

## O que é fácil errar aqui

- **Faturamento e atendimentos seguem a definição do caixa**
  (`financeiro.services.pagamentos_efetivados()` e a data do atendimento:
  agenda por `data_hora`, esteira por `criado_em`). Somar todo
  `PagamentoAgendamento` contava o pagamento provisório da vitrine, e contar por
  data do pagamento fazia painel e caixa divergirem. `test_bugs_inventario.py`
  garante que os dois concordam.
- **Com filtro por profissional a esteira fica de fora**, como no caixa: o
  atendimento kanban não tem colaborador. E `clientes_novos` sai `null`: cliente
  novo é do negócio, não de alguém.
- **Ele lê os dois modos de agenda.** Um negócio usa agenda ou esteira, então
  metade das consultas volta vazia — e está correto assim.
- **É o app mais sensível a mudança alheia.** Renomear campo ou status em
  `agenda`, `kanban` ou `financeiro` quebra aqui, silenciosamente, porque ele
  agrega sem serializer no meio.
