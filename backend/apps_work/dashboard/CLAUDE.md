# apps_work/dashboard — CLAUDE.md

A **tela inicial do painel**: números do negócio e comparação com o período
anterior.

App mínimo — 3 arquivos, sem model e sem migration. Ele não guarda nada, só lê
e agrega o que os outros apps já registraram.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `services.py` | `DashboardService.obter_resumo()` — toda a lógica está aqui |
| `views.py` | Uma view só, que delega e devolve |
| `urls.py` | Uma rota |

## Por que não tem `models.py` nem `apps.py`

Porque não há dado próprio. Ele é uma **visão de leitura** sobre agenda, kanban,
financeiro e clientes. Um `AppConfig` só seria necessário para registrar sinais
ou modelos, e não há nenhum dos dois.

Isso também significa que ele não aparece em `TENANT_APPS` — só as `urls` são
incluídas no `core/urls.py`.

## Tabelas

**Nenhuma.** É o único app do backend sem `models.py`, e isso é decisão de
arquitetura, não omissão: ele agrega o que `agenda`, `kanban`, `financeiro` e
`clientes` já guardam. Guardar número consolidado aqui criaria um segundo lugar
onde a verdade pode divergir.

## A variação percentual

`_var(atual, anterior)` compara o período corrente com o anterior. Devolve
`None` quando não há base de comparação — o frontend usa isso para não mostrar
"+∞%" no primeiro mês do negócio.

## O que é fácil errar aqui

- **Faturamento usa a mesma definição de receita do caixa:**
  `financeiro.services.pagamentos_efetivados()` (kanban pago, agendamento
  concluído). Somar todo `PagamentoAgendamento` contava o pagamento provisório que a
  vitrine cria ao agendar pelo app — e o dashboard divergia do caixa.

- **Ele lê os dois modos de agenda.** Um negócio usa agenda ou esteira, então
  metade das consultas volta vazia — e está correto assim.
- **É o app mais sensível a mudança alheia.** Renomear campo ou status em
  `agenda`, `kanban` ou `financeiro` quebra aqui, silenciosamente, porque ele
  agrega sem serializer no meio.
