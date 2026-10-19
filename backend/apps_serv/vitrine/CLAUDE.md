# apps_serv/vitrine — CLAUDE.md

O que o cliente final enxerga da plataforma: **descobrir negócios e agendar**.

É o app mais pesado do backend (~1.050 linhas) e o único que atravessa os dois
schemas de propósito. Toda a fronteira entre o mundo público e o mundo do tenant
passa por aqui.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `models.py` | Um modelo só: `NegocioPublico`, o perfil do negócio no schema público. É cópia sincronizada do `EmpresaConfig` do tenant, e existe para o app achar negócios sem conhecer tenant nenhum |
| `services.py` | O coração, com quatro responsabilidades separadas em classes — ver abaixo |
| `views.py` | Endpoints públicos (mapa, busca, perfil do negócio) e autenticados (vincular, agendar). Inclui o recorte geográfico `_filtrar_por_area` |
| `handlers.py` | A ponte de volta: escuta sinais do lado do negócio e reflete no público |
| `serializers.py` | Representação do `NegocioPublico` |
| `urls.py` | Rotas sob `/api/sm/negocios/` |

## As quatro classes de `services.py`

| Classe | Responsabilidade |
|---|---|
| `CrossTenantQueryService` | Lê dados **dentro** do tenant: serviços, equipe, horários, disponibilidade. É o único lugar que entra no schema do negócio para consultar |
| `StatusKanbanAgendamentosService` | Descobre em que coluna do quadro cada atendimento está. Agrupa por schema para trocar de schema uma vez por negócio, não uma por agendamento |
| `AgendamentoTenantService` | Cria o agendamento nos dois lados. O método mais delicado do backend |
| `CancelarAgendamentoService` | Cancela e, fora do prazo, lança a taxa como pendência na comanda do cliente dentro do tenant |
| `VincularNegocioService` | Cria, reativa e desfaz o vínculo, e espelha o perfil do cliente no `Cliente` do tenant |
| `SincronizarVitrineService` | Publica ou despublica o negócio na vitrine a partir do `EmpresaConfig` |

## Tabela

### `NegocioPublico` — o perfil do negócio na vitrine

| Coluna | Tipo | O que é |
|---|---|---|
| `schema_name` | `CharField(63)` único, indexado | O tenant que este perfil representa. É a chave que o app B2C usa em toda rota |
| `nome` | `CharField(255)` | Nome exibido no mapa |
| `nicho` | `CharField(50)` | Slug (`barbearia`, `banho_tosa`…). Os rótulos legíveis vivem nos apps |
| `tipo_agenda` | `CharField(20)` | `horario` ou `kanban`. Define o fluxo de agendamento no app |
| `tipo_objeto` | `CharField(20)` nulo | `veiculo` ou `pet`. Nulo quando o nicho não exige objeto |
| `latitude` | `Decimal(9,6)` | Obrigatória — sem ela o negócio não entra na vitrine |
| `longitude` | `Decimal(9,6)` | Idem |
| `logo_url` | `URLField` vazio | URL pública no S3 |
| `descricao` | `TextField` vazio | Texto livre |
| `cidade` | `CharField(100)` vazio | Alimenta o filtro de cidade e o endpoint `/cidades/` |
| `ativo` | `Boolean` = `True` | Despublicar é `False`, nunca apagar — o vínculo dos clientes continua existindo |
| `atualizado_em` | `DateTime` `auto_now` | Última sincronização vinda do `EmpresaConfig` |

Ordenação padrão por `nome`.

## O caminho de volta: `handlers.py`

Os apps de negócio **não conhecem** o `apps_serv`. Quando algo muda lá e precisa
aparecer aqui, o caminho é sinal:

| Sinal | Efeito |
|---|---|
| `empresa_config_atualizada` | Republica o `NegocioPublico` |
| `cliente_servicemanage_removido` | Desfaz o vínculo, para o negócio sair de "Seus negócios" |
| `agendamento_status_alterado` | Espelha o status no `AgendamentoConsumidor` |
| `atendimento_kanban_falta_alterada` | Espelha a falta — que não é coluna do quadro, então não seria lida ao vivo |

## O que é fácil errar aqui

- **`criar()` grava nos dois schemas dentro de um `atomic()`.** Efeito colateral
  que pode falhar (sincronizar perfil, notificar o negócio) precisa de savepoint
  próprio: engolir a exceção sem ele deixa a transação abortada e derruba o
  agendamento **depois** de já ter escrito no tenant.
- **Status de esteira é lido ao vivo, status de agenda é espelhado.** Confundir
  os dois faz o cliente ver o estado errado. Falta é a exceção que se espelha.
- **Endpoint público recebe `schema_name` pela URL.** Sempre passar por
  `_schema_valido` antes — ele vira troca de schema logo em seguida.
- **O recorte por área é caixa, não círculo.** Exagera nos cantos de propósito,
  para não trazer PostGIS só para filtrar pino de mapa.
