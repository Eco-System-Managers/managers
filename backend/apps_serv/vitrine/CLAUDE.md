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
| `urls.py` | Rotas sob `/api/sm/v1/negocios/` |

## As seis classes de `services.py`

| Classe | Responsabilidade |
|---|---|
| `CrossTenantQueryService` | Lê dados **dentro** do tenant: serviços, equipe, horários, disponibilidade. Só leitura — agendar, cancelar e vincular também entram no schema do negócio, cada um no próprio service, sempre por `schema_context` |
| `StatusKanbanAgendamentosService` | Descobre em que coluna do quadro cada atendimento está. Agrupa por schema para trocar de schema uma vez por negócio, não uma por agendamento |
| `AgendamentoTenantService` | Cria o agendamento nos dois lados. O método mais delicado do backend |
| `CancelarAgendamentoService` | Cancela e, fora do prazo, lança a taxa como pendência na comanda do cliente dentro do tenant |
| `VincularNegocioService` | Cria, reativa e desfaz o vínculo. Ao vincular, copia a ficha inteira (`Cliente.CAMPOS_ESPELHADOS`); ao desfazer, apaga os dados pessoais (`Cliente.CAMPOS_PESSOAIS`) e mantém nome, telefone e histórico |
| `SincronizarVitrineService` | Publica ou despublica o negócio na vitrine a partir do `EmpresaConfig` |

## Tabela

### `NegocioPublico` — o perfil do negócio na vitrine

| Coluna | Tipo | O que é |
|---|---|---|
| `schema_name` | `CharField(63)` único, indexado | O tenant que este perfil representa. É a chave que o app B2C usa em toda rota |
| `nome` | `CharField(255)` | Nome exibido no mapa |
| `nichos` | `ArrayField(CharField(50))` | Slugs (`barbearia`, `banho_tosa`…), de 1 a 4, copiados de `EmpresaConfig.nichos`. O filtro `?nicho=` acha o negócio por qualquer um deles. Os rótulos legíveis vivem nos apps |
| `tipo_agenda` | `CharField(20)` | `horario` ou `kanban`. Define o fluxo de agendamento no app |
| `tipo_objeto` | `CharField(20)` nulo | `veiculo` ou `pet`, copiado de `EmpresaConfig.tipo_objeto`. Nulo no modo horário |
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
| `cobranca_registrada` | Espelha o que a cobrança decidiu — o serviço trocado, o acréscimo com o motivo e o total cobrado — nos dois modos, pelo `origem` + `agendamento_id` |

## O que o cliente pode marcar

- **Modo horário:** a disponibilidade é a mesma grade do Work Manage
  (`SlotsAgendaService.livres`, de 15 em 15 min mais o fim de cada atendimento),
  com a duração somada dos serviços. O profissional é obrigatório
  (`colaborador_obrigatorio`): a agenda é individual.
- **Janela do cliente:** pelo menos 30 min de antecedência (`antecedencia_minima`)
  e até 30 dias à frente (`fora_do_limite`), pelo relógio do servidor. Vale nos
  dois modos. A empresa não tem janela.
- **Esteira: o porte.** A lista de serviços aceita `?porte=` (os do porte e os
  sem porte), e `criar()` recusa serviço de outro porte
  (`servico_de_outro_porte`) pelo porte que o cliente declarou no pet ou
  veículo (`_porte_declarado`, que também lê o rótulo antigo dos pets,
  "Médio"). O `Pet`/`Veiculo` do tenant sem porte ganha o declarado; o porte
  que o negócio já informou não é tocado.
- **A lista é a regra.** `criar()` só aceita, no modo horário, um horário que
  esteja na grade naquele momento (`horario_indisponivel`). É essa conferência
  que barra conflito com outro cliente, horário fora do expediente e qualquer
  pedido montado à mão.

## O que é fácil errar aqui

- **`criar()` grava nos dois schemas dentro de um `atomic()`.** Efeito colateral
  que pode falhar (sincronizar perfil, notificar o negócio) precisa de savepoint
  próprio: engolir a exceção sem ele deixa a transação abortada e derruba o
  agendamento **depois** de já ter escrito no tenant.
- **Status de esteira é lido ao vivo, status de agenda é espelhado.** Confundir
  os dois faz o cliente ver o estado errado. Falta é a exceção que se espelha.
  A cobrança (serviço trocado, acréscimo, total) é espelhada nos dois modos, e
  o filtro leva `origem` junto com `agendamento_id`: o id de um atendimento da
  esteira não pode bater num agendamento da agenda.
- **Endpoint público recebe `schema_name` pela URL.** Sempre passar por
  `_schema_valido` antes — ele vira troca de schema logo em seguida.
- **O recorte por área é caixa, não círculo.** Exagera nos cantos de propósito,
  para não trazer PostGIS só para filtrar pino de mapa.
