# apps_work/agenda — CLAUDE.md

Agendamento **por horário marcado** — o modo de agenda de quem trabalha com hora
marcada (barbearia, salão, clínica).

É um dos dois modos do produto. O outro é o `kanban` (esteira), usado por
lava-rápido e banho & tosa. Cada negócio usa **um** dos dois, definido por
`EmpresaConfig.tipo_agenda`.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `models.py` | `Agendamento`, `AgendamentoServico` (o N:N com preço congelado), `PagamentoAgendamento` e `Bloqueio` |
| `services.py` | Cinco serviços: dias com registro, pendências de cobrança, grade de horários livres, bloqueios e o `AgendamentoService` (a regra de conflito e a cobrança, com acréscimo e troca de serviço) |
| `views.py` | `AgendamentoViewSet`, `BloqueioViewSet` e três views de leitura (slots, dias do mês, pendências) |
| `serializers.py` | Representação; o `create` monta agendamento e serviços juntos |
| `signals.py` | Declara `agendamento_status_alterado`, que a vitrine escuta |
| `urls.py` | Rotas sob `/api/v1/agendamentos/` e afins |

## Os quatro modelos

| Modelo | Papel |
|---|---|
| `Agendamento` | O compromisso: cliente, colaborador, data/hora, status |
| `AgendamentoServico` | Quais serviços, com `preco_cobrado` **congelado** no momento do agendamento — mudar a tabela de preços depois não reescreve o passado |
| `PagamentoAgendamento` | Como foi pago (dinheiro, PIX, crédito, débito, QR Code). Um agendamento pode ter mais de um |
| `Bloqueio` | Um período em que o profissional não atende (imprevisto, folga, férias, almoço). Tira o trecho da grade. Sem colaborador é o **negócio inteiro** que fecha: vale na agenda de todos e na esteira |

## Tabelas

### `Agendamento` — o compromisso

| Coluna | Tipo | O que é |
|---|---|---|
| `cliente` | `FK → clientes.Cliente` `PROTECT` | Não dá para apagar cliente com agendamento |
| `colaborador` | `FK → usuarios.Colaborador` `PROTECT`, nulo | Nulo é permitido: sem profissional, não há conflito de agenda a checar |
| `data_hora` | `DateTimeField` | Início do compromisso. A duração vem dos serviços |
| `status` | `CharField(20)` = `agendado` | `agendado`, `confirmado`, `concluido`, `cancelado`, `faltou` |
| `desconto` | `Decimal(8,2)` = 0 | Desconto no total |
| `acrescimo` | `Decimal(8,2)` = 0 | O que o atendimento custou a mais, acertado com o cliente na cobrança ("tempo excedido"). Só o `cobrar/` mexe |
| `acrescimo_motivo` | `CharField(60)` vazio | O motivo do acréscimo, que o cliente vê no app |
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

Só `agendado` e `confirmado` ocupam o horário (`STATUS_QUE_OCUPAM`), aqui e na
grade: concluído e faltou já tiveram desfecho, e o horário fica livre para
quem chegar. Antes a regra só ignorava o cancelado, e a grade mostrava livre
um horário que o salvar recusava.

## Filtros da listagem

`?data=` (um dia), `?colaborador=` e `?cliente=`, documentados no OpenAPI. A
listagem exclui os cancelados; o detalhe (`/agendamentos/<id>/`) não. O app
cancela por `PATCH status=cancelado` — o `DELETE` apaga o registro e não
dispara o sinal de status.

Nos bloqueios (`agenda/bloqueios/`), `?data=` traz os que valem no dia (o fixo
entra) e `?colaborador=` traz **os dele e os do negócio** (colaborador nulo):
são os que valem na agenda daquele profissional.

## Paginação

A listagem é sempre paginada (`core/paginacao.py`), inclusive com `?data=` —
antes o dia saía como array e a mesma rota tinha dois formatos. A grade do dia
monta a linha do tempo com todos os agendamentos daquela data, então o front
pede `?page_size=100` e **segue o `next`** se ele vier: uma página que não chega
faria horário sumir da tela sem erro nenhum.

## A cobrança (`agendamentos/{id}/cobrar/`)

A entrada é o `CobrancaSerializer` do `financeiro`. O total a cobrar é **a soma
dos `preco_cobrado` mais o `acrescimo` menos o `desconto`**, e pagamentos +
`credito_aplicado` têm de bater com ele (400 `soma_invalida`,
`conferir_total_da_cobranca`, no `financeiro`). Cobrar conclui o agendamento e
dispara dois sinais: `agendamento_status_alterado` e `cobranca_registrada` (do
`financeiro`), que leva ao app do cliente o total cobrado, o acréscimo e o
retrato dos serviços.

Dois acertos em comum acordo com o cliente só acontecem aqui:

- **Acréscimo** (`acrescimo`, `acrescimo_motivo`): manter o serviço e cobrar o
  que custou a mais ("tempo excedido"). Os dois campos são só leitura no
  serializer — por PATCH são ignorados.
- **Troca de serviço** (`servico_ids`): os `AgendamentoServico` são substituídos
  pelos serviços da lista, com `preco_cobrado` = **preço atual** de cada um — o
  congelado era do que foi combinado, e o que foi feito é outro. Id inexistente
  ou serviço inativo: 400 `servico_invalido` (`servicos_ativos`, em `servicos`).

Sem nenhum dos dois, cobra o combinado. Tudo roda num `atomic`: soma errada
desfaz a troca junto. A agenda não tem "desfazer cobrança".

## O que é fácil errar aqui

- **Status alterado aqui precisa chegar ao app do cliente.** Quem faz isso é o
  sinal `agendamento_status_alterado`, escutado por `apps_serv/vitrine/handlers.py`.
  Alterar status por `.update()` direto no queryset pula o sinal.
- **`acrescimo` e `acrescimo_motivo` só mudam pelo `cobrar/`.** Preço é acordo
  com o cliente, não ajuste de tela. As pendências fazem a mesma conta da
  cobrança (serviços + acréscimo − desconto): um agendamento cobrado que volte
  para confirmado fica pendente pelo que foi cobrado.
- **Agendamento nascido no app tem contraparte no schema público.** O que nasce
  no balcão não tem — o filtro do handler simplesmente não encontra nada, e está
  certo assim.
- **Duração vem dos serviços, não do agendamento.** Não existe campo de duração;
  ela é sempre a soma dos serviços vinculados.
- **As pendências juntam a esteira, e o avulso dela não tem cliente:**
  `cliente_id` sai nulo e `cliente_nome` é a identificação ("Hilux branca").
  Leia `at.rotulo`/`at.cliente` do kanban, nunca `at.objeto.cliente`.

## A grade de horários (`agenda/slots/`)

`SlotsAgendaService` devolve só os horários **livres** de um profissional
para um serviço num dia. Os candidatos são a grade de 15 em 15 minutos a
partir da abertura (o passo da agenda do app) mais o fim de cada
agendamento já marcado: acabou um às 9:20, o 9:20 é oferecido. Entra quem
cabe inteiro, antes do fechamento e sem bater em ninguém; `disponivel` vem
sempre `True` (o campo fica pelo contrato comum com os slots do kanban, que
ainda marcam os ocupados). A ocupação é por profissional: a agenda de um não
interfere na do outro.

O cálculo mora em `livres()`, que recebe a duração e um `nao_antes_de`. É o
mesmo que o app do cliente usa (`apps_serv/vitrine`), com a soma dos serviços
e a antecedência de 30 min; a empresa não passa `nao_antes_de`.

## Bloqueios (`agenda/bloqueios/`)

Um `Bloqueio` tira um trecho da agenda de um profissional. É o que substitui
pausa fixa e buffer: a agenda não reserva intervalo nenhum sozinha. **Sem
colaborador é o negócio inteiro que fecha** (o almoço de todos, o imprevisto,
o dia que desandou): vale na agenda de todo profissional e na esteira, que
não tem agenda individual (`kanban`, "A capacidade do dia").

| Coluna | Tipo | O que é |
|---|---|---|
| `colaborador` | `FK → usuarios.Colaborador` `CASCADE`, nulo | De quem é a agenda bloqueada. **Nulo é o negócio inteiro**; `colaborador_nome` sai nulo |
| `data_inicio` | `DateField` | Hoje ou depois |
| `data_fim` | `DateField` nulo | Nulo é o **fixo**: vale todos os dias a partir do início (o almoço). "Uma semana" e "um mês" são a tela preenchendo a data |
| `hora_inicio` / `hora_fim` | `TimeField` nulos | Os dois nulos: o dia inteiro |
| `motivo` | `CharField(60)` vazio | Texto livre ("Almoço", "Férias") |
| `criado_em` | `DateTime` `auto_now_add` | |

- **Só listar, criar e excluir.** Sem editar: para mudar, exclui e cria de novo.
- **Quem pode** (`exigir_poder_bloquear`): o dono bloqueia a agenda de todos; o
  parceiro, só a própria; o colaborador comum só vê (403 `sem_permissao_bloquear`).
  **O do negócio é só do dono** (`exigir_poder_bloquear_em`, em `views.py`):
  criar e excluir por quem não é proprietário é 403 `sem_permissao`.
- **Não bloqueia em cima de cliente.** Criar procura atendimento ainda por
  acontecer (`agendado`/`confirmado`) dentro do período e da faixa; no fixo,
  em todas as datas a partir do início. Achou: 400 `bloqueio_com_cliente`. O
  do negócio olha a agenda de **todos** os profissionais e também a esteira:
  os `AtendimentoKanban` com hora (`data` + `horario_entrada`, ocupando a
  `duracao_prevista`), sem os que faltaram. O card sem hora não impede, nem no
  dia inteiro: ele continua marcado, só não entra mais ninguém.
- **Vale para todo mundo.** Sai da grade do Work Manage e do app do cliente
  (`_intervalos_ocupados`), e a regra de conflito recusa marcar ou remarcar em
  cima dele (400 `horario_bloqueado`), inclusive para o dono.
  `intervalos_do_dia(data, colaborador_id)` devolve os do profissional **mais
  os do negócio**, então a agenda por horário respeita o fechamento sozinha;
  `intervalos_do_negocio(data)` são só os do negócio, para a esteira.
- **O de profissional é só do modo horário.** A esteira não tem agenda
  individual; o que ela usa é o do negócio.
