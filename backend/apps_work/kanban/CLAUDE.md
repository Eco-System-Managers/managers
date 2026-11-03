# apps_work/kanban — CLAUDE.md

Agendamento **por esteira** — o modo de quem recebe o objeto, trabalha nele e
devolve (lava-rápido, banho & tosa).

É o outro modo de agenda, alternativo ao app `agenda`. Aqui não existe "horário
do profissional": existe uma fila de etapas, e o atendimento anda por ela.

**A esteira é de operação compartilhada.** O quadro é um só, do negócio: quem é
convidado não ganha quadro, etapas nem agenda próprios, o card não tem
profissional, e o Início, o quadro e o caixa não têm recorte por pessoa. O
vínculo (`usuarios`) diz o que cada um pode fazer, não de quem é o atendimento
(ver "Quem pode o quê").

## Arquivos

| Arquivo | O que faz |
|---|---|
| `models.py` | `EtapaKanban` (as colunas do quadro), `AtendimentoKanban` (o card) e `PagamentoAtendimento` |
| `services.py` | Traduz posição no quadro em status, cria etapas padrão, reordena colunas, cria o atendimento (com objeto ou avulso) com checagem de capacidade, do fechamento do negócio, de porte e da identificação, e cobra (com acréscimo e troca de serviço) |
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
| `pronto` | `Boolean` = `False` | **A etapa em que o carro ou o pet está pronto**; as depois dela também contam. Uma só por negócio (constraint parcial). Sem nenhuma marcada vale a última |
| `criado_em` | `DateTime` `auto_now_add` | |

Ordenação padrão por `ordem`.

### `AtendimentoKanban` — o card

| Coluna | Tipo | O que é |
|---|---|---|
| `etapa` | `FK → EtapaKanban` `PROTECT` | Onde o card está agora. Não há campo de status |
| `objeto` | `FK → clientes.ObjetoCliente` `PROTECT`, nulo | O pet ou veículo — o cliente vem por ele. Nulo no **avulso** |
| `identificacao` | `CharField(80)` vazio | O avulso: o texto que diz de quem é o carro ou o pet no pátio ("Hilux branca", "ABC-1234"). Ou ele ou o `objeto` |
| `servico` | `FK → servicos.Servico` `PROTECT` | Um só, diferente da agenda, que aceita vários |
| `colaborador` | `FK → usuarios.Colaborador` `PROTECT`, nulo | **Não é mais escrito nem lido pela API**: a esteira não tem profissional no card. A coluna fica porque tirar coluna é migration em todos os schemas, sem nada a ganhar |
| `observacao` | `TextField` vazio | |
| `data` | `DateField` nulo | Opcional: dá para receber sem hora marcada |
| `horario_entrada` | `TimeField` nulo | Idem |
| `pago` | `Boolean` = `False` | |
| `faltou` | `Boolean` = `False` | Estado à parte do avanço no quadro — falta não é coluna |
| `desconto` | `Decimal(8,2)` = 0 | |
| `acrescimo` | `Decimal(8,2)` = 0 | O que o atendimento custou a mais, acertado com o cliente na cobrança ("tempo excedido"). Só o `cobrar/` mexe; `desfazer_cobranca/` zera |
| `acrescimo_motivo` | `CharField(60)` vazio | O motivo do acréscimo, que o cliente vê no app |
| `minutos_extras` | `PositiveInteger` = 0 | O tempo a mais previsto ("esse vai levar mais 1h"), somado à duração do serviço em `duracao_prevista`. É do pátio: não mexe no preço |
| `pronto_em` | `DateTime` nulo | Quando o card chegou na etapa de pronto; volta a nulo se ele voltar. É o que libera a vaga |
| `criado_em` | `DateTime` `auto_now_add` | Também a ordenação padrão |

Não há mais a restrição de unicidade `data` + `horario_entrada` (saiu na
migration 0003): com `vagas` dois atendimentos na mesma hora são normais. Quem
impede a corrida é o lock do dia em `CapacidadeService.conferir`.

### `AjusteDoDia` — a capacidade de uma data só

| Coluna | Tipo | O que é |
|---|---|---|
| `data` | `DateField` único | A data que foge do padrão da semana ("hoje sou só eu") |
| `capacidade` | `PositiveInteger` nulo | O máximo de atendimentos no dia; nulo é sem máximo |
| `vagas` | `PositiveInteger` = 1 | Quantos andam ao mesmo tempo |

Apagar o ajuste volta a data ao `HorarioFuncionamento` do dia da semana.

### `PagamentoAtendimento`

| Coluna | Tipo | O que é |
|---|---|---|
| `atendimento` | `FK → AtendimentoKanban` `CASCADE` | Aceita vários pagamentos |
| `forma` | `CharField(20)` | `dinheiro`, `pix`, `credito`, `debito`, `qr_code` |
| `valor` | `Decimal(8,2)` | |
| `comissao_percentual` · `repasse` | `Decimal` nulo · `Decimal(8,2)` = 0 | Sempre nulo e zero: na esteira não há comissão, o caixa é do negócio inteiro. As colunas ficam pelo contrato comum com a agenda, onde a comissão congela |
| `criado_em` | `DateTime` `auto_now_add` | |

## Como o status é derivado

Não existe campo de status no atendimento. `StatusClienteService` calcula a
partir da **posição da etapa no quadro**: primeira coluna vira `aguardando`,
última vira `concluido`, o meio vira `em_atendimento`.

A consequência é que renomear ou reordenar colunas muda o que o cliente vê no
app, sem migration nenhuma. É por isso que o app B2C lê esse status ao vivo em
vez de guardar cópia.

## A capacidade do dia

Dois números por dia, do `HorarioFuncionamento` do dia da semana ou do
`AjusteDoDia` da data (`CapacidadeService.limites`): a **capacidade** (o máximo
de atendimentos no dia, com ou sem hora; nulo é sem máximo) e as **vagas**
(quantos andam juntos; dia sem horário cabe 1 por vez). A ocupação é lida do
quadro, não só da previsão (`ocupacoes`): cada card ocupa da entrada (a hora
marcada ou, sem ela, a hora em que foi lançado, se foi no próprio dia) até o
maior entre o fim previsto (`duracao_prevista`) e **agora**, enquanto não chega
na etapa de pronto; chegando, até o `pronto_em`. O "agora" entra arredondado
para a próxima marca de 15 min (`core/grade.proxima_marca`), para a grade
nunca oferecer 10:37:12. A grade (`core/grade.inicios_livres`) anda de 15 em
15 e também oferece o fim de cada ocupação.

**Conferir** (`CapacidadeService.conferir`) é a trava: dia lotado é 400
`dia_lotado`, hora sem vaga é 400 `horario_ocupado`. Antes de ler, ela pega um
`pg_advisory_xact_lock` do `schema:data` (`travar_dia`), e por isso conferir e
gravar andam dentro do mesmo `atomic()` (`criar`, `perform_update` e o `criar`
da vitrine): dois lançamentos ao mesmo tempo não passam os dois pela última
vaga. **Para o negócio o limite é aviso**: `ignorar_limite=true` no POST e no
PATCH passa por cima; para o cliente do app (vitrine) é parede. No PATCH, o
máximo do dia só é conferido quando o `data` muda (o card já tem a vaga dele no
dia que está); mudar hora ou serviço confere só a hora; mexer em pago,
observação ou `minutos_extras` não é barrado. O POST aceita `minutos_extras`
e já ocupa o tempo todo; a vitrine manda o pedido de vários serviços como um
card do primeiro com os outros em `minutos_extras`.

**Fechar horários do negócio** (regra 13: almoço, imprevisto, o dia que
desandou) é um `Bloqueio` da `agenda` **sem colaborador**
(`agenda/bloqueios/`; o dono e o parceiro criam e excluem; 403 `sem_permissao`
para o colaborador comum). Na esteira não há agenda individual: o bloqueio
com `colaborador` é recusado (400 `bloqueio_individual_na_esteira`), só
existe o do negócio. `ocupacoes` soma cada trecho fechado
(`BloqueioService.intervalos_do_negocio`) repetido `vagas` vezes — ocupa
todas as vagas, e a grade não oferece nada ali (o dia inteiro fechado zera a
grade; o fim do trecho vira início oferecido, como o de qualquer ocupação).
`conferir` recusa hora dentro de um trecho fechado com 400
`horario_bloqueado` (o code da agenda), antes de olhar as vagas e mesmo com
`conferir_dia=False`. **Para o bloqueio não há "ignorar"**: `criar` e
`conferir_alteracao` chamam `conferir_bloqueio` também com `ignorar_limite`
(o dono que quer receber ali exclui o bloqueio antes). Só a hora é conferida:
o card sem hora continua entrando (quem chegou), e mexer só em
`minutos_extras` não é barrado. Criar o bloqueio em cima de um card com hora
é 400 `bloqueio_com_cliente`, na agenda. O app do cliente não precisa de nada
disso: a vitrine confere pela grade (`livres`), que já não tem as horas
fechadas.

`kanban/slots/?data=&servico=&excluir=` é a grade de horas de entrada no
formato da agenda (`{horario, disponivel}`): só as horas em que a duração do
`servico` cabe (sem ele, 30 min; serviço inexistente é **404
`nao_encontrado`**, não a grade de 30 min em silêncio), e `excluir` é o card
que está sendo remarcado, que a grade não conta (senão ele barraria a si
mesmo). `kanban/capacidade/?data=` lê `{capacidade, vagas, ajustado,
ocupados}`; o `PUT` (dono e parceiro) grava o ajuste da data e exige **os dois
números** (`capacidade: null` é "sem máximo" de propósito; omitida é 400), o
`DELETE` (dono e parceiro) volta ao padrão.

**A etapa de pronto** (`EtapaService`): `POST kanban/etapas/{id}/pronto/`
(dono) marca uma e desmarca a anterior; `pronto` é só leitura no PATCH da
etapa. A primeira coluna é a espera, então marcá-la é 400
`etapa_pronto_invalida` (reordenar a de pronto para a primeira posição também
é recusado); com uma coluna só não há fim, e nada conta como pronto: o card
segura a vaga até sair do quadro. `ids_prontos()` é a de pronto
e as depois dela (ordem, id); empate de `ordem` desempata pelo id. Marcar ou
reordenar chama `recalcular_pronto_em`, que acerta o `pronto_em` dos cards de
hoje em diante (o passado é história). Chegar numa etapa de pronto, por
`mover/` ou por PATCH de `etapa`, grava `pronto_em`; voltar zera; criado direto
nela já nasce com a hora. Remover a de pronto com outras no quadro é 400
`etapa_pronto`.

## A exceção: falta

Falta não é coluna do quadro, então não seria capturada pela leitura ao vivo.
Por isso `marcar_falta` dispara sinal e o público é atualizado explicitamente.
Ao desfazer, volta para `agendado` — e o ponto do quadro volta a valer.

## O avulso

O cliente que chega e pede "lava aí". Cadastrar cliente e carro nessa hora é
burocracia que ninguém faz, e um "cliente genérico" para todos viraria o maior
cliente do negócio; então o atendimento nasce **sem `objeto`**, só com o
serviço e a `identificacao` ("Hilux branca"). A regra é ou um ou outro: os dois
vazios é 400 `avulso_sem_identificacao` (`conferir_identificacao`, no `criar` e
no PATCH que tira o objeto ou apaga o texto). No serializer, `avulso` (só
leitura) diz que não há objeto, e `objeto_detalhe`, `cliente_nome` e
`cliente_telefone` saem nulos. O porte só é conferido quando há objeto; a
capacidade conta o avulso como qualquer outro, e ele ocupa a vaga desde que é
lançado. Ele não tem comanda: `cobrar` recusa `credito_aplicado` e
`troco_credito` acima de zero (400 `avulso_sem_credito`), e o dinheiro entra no
caixa igual. Fora do quadro (caixa, painel, pendências) ele aparece pelo
`rotulo` do model: o nome do cliente ou, no avulso, a identificação.

## Quem pode o quê

A fila é do negócio; o vínculo diz o que cada um faz (`core/permissions.py`):

| | Dono | Parceiro | Colaborador comum |
|---|---|---|---|
| Ler etapas, quadro, capacidade e os horários fechados | ✅ | ✅ | ✅ |
| Mover o card (`mover/`) e ajustar o tempo (`PATCH minutos_extras`) | ✅ | ✅ | ✅ |
| Ficha do card | inteira | inteira | sem `cliente_telefone` nem valores (`servico_preco`, `desconto`, `acrescimo`, `acrescimo_motivo` nulos; `pagamentos` vazio) |
| Receber (`POST`), remarcar e o resto do `PATCH`, `PUT`, excluir, falta | ✅ | ✅ | 403 `sem_permissao` |
| Cobrar e desfazer | ✅ | ✅ | 403 `sem_permissao` (`pode_cobrar` não pesa aqui) |
| Capacidade do dia (`PUT`/`DELETE`) e fechar horário | ✅ | ✅ | 403 |
| Etapas (criar, editar, reordenar, pronto, remover) | ✅ | 403 | 403 |

A trava das ações é `IsProprietarioOuParceiro` no `AtendimentoKanbanViewSet`
e na `CapacidadeView`: nos endpoints do kanban o vínculo basta, porque a
esteira é o próprio modo. O `PATCH` do colaborador comum com qualquer campo
além de `minutos_extras` é 403 (`perform_update`). O serializer esconde os
campos reservados pelo `request` do contexto, então as ações respondem com
`self.get_serializer(...)`, nunca com o serializer solto. Fora do quadro, o
colaborador comum da esteira recebe 403 em clientes, veículos e pets, serviços,
contratos, painel, saldo do cliente, pendências e na agenda por horário
(`agendamentos/`, slots e dias com registro: `NaoEhColaboradorDaEsteira` /
`exigir_nao_ser_colaborador_da_esteira`); o caixa já era 403 para ele
(`exigir_ver_valores`), e a equipe é só do dono na esteira (`usuarios`).

## Filtros e ações

`kanban/atendimentos/?data=` é o quadro de um dia e `?cliente=` o histórico de
um cliente (pelos objetos dele; o avulso, sem objeto, fica de fora); os dois
estão no OpenAPI. Não há filtro por profissional: o card não tem um. As ações
do card são `POST .../{id}/mover/` (`{etapa_id}`), `cobrar/`,
`desfazer_cobranca/`, `marcar_falta/` e `desfazer_falta/`.

**Cobrar** recebe o `CobrancaSerializer` do `financeiro`. O total é **o preço
do serviço mais o `acrescimo` menos o `desconto`**, e pagamentos +
`credito_aplicado` têm de bater com ele (400 `soma_invalida`). Dois acertos em
comum acordo com o cliente só acontecem aqui: o **acréscimo** com o motivo
("tempo excedido") e a **troca de serviço** por `servico_ids` — **um id só**
(a esteira tem um serviço por card; mais de um é 400 `um_servico_so`), do porte
do veículo ou pet (400 `servico_de_outro_porte`; o avulso não confere) e no
catálogo ativo (400 `servico_invalido`). **Desfazer** apaga os pagamentos e as
transações de crédito e zera desconto e acréscimo; a troca de serviço fica, porque
ela registra o que foi feito, não como foi pago. Os dois disparam
`cobranca_registrada` (`financeiro/signals.py`) para o app do cliente.
`kanban/etapas/reordenar/` recebe os ids na ordem final (`{"ordem": [3, 1,
2]}`; a posição vira a `ordem`) e ainda aceita a forma antiga `[{id, ordem}]`.
Remover etapa com atendimentos dentro responde 400 `etapa_com_atendimentos`
(`EtapaService.remover`): o FK é PROTECT, e sem isso a view caía em 500.

## O que é fácil errar aqui

- **O card não tem profissional, e a cobrança não tem comissão.** `colaborador`
  não está no serializer (mandar no POST ou no PATCH é ignorado), e `cobrar`
  grava cada `PagamentoAtendimento` com `repasse` zero, mesmo que o parceiro
  tenha `comissao_percentual` cadastrada. O caixa e o painel não recortam a
  esteira por pessoa (`colaborador_aplicado` devolve todos).
- **O quadro do dia também vem paginado**, como a agenda: o front pede
  `?data=...&page_size=100` e segue o `next`. Página que não chega faria card
  sumir da coluna sem erro.
- **A grade de horas de entrada (`kanban/slots/`) depende do expediente** do
  `HorarioFuncionamento` do dia (dia fechado ou lotado não tem hora), das
  `vagas` e dos **bloqueios do negócio** (`agenda.Bloqueio` sem colaborador);
  `capacidade` nula é sem máximo, não "nenhuma hora".
- **`horario_bloqueado` não tem `ignorar_limite`.** É a única recusa de hora
  que o dono não passa por cima: para receber ali, exclui o bloqueio.
- **Cobrar gera troco como crédito.** O excedente vira `TransacaoCredito` na
  comanda do cliente (app `financeiro`), não dinheiro devolvido.
- **O serviço tem de servir para o porte do objeto** (`servico_de_outro_porte`,
  ver `servicos`): `AtendimentoKanbanService.criar` confere, e o PATCH que
  troca o serviço ou o objeto também. O app B2C chama `criar` com
  `conferir_porte=False`, porque já conferiu com o porte que o cliente
  declarou: o cadastro do negócio pode ter sido corrigido na chegada, e o
  cliente não teria como resolver a diferença.
- **Não dá para marcar falta em atendimento já pago** — a regra está em
  `ERRO_FALTA_EM_PAGO`.
- **Tempo e preço são coisas separadas.** `minutos_extras` é o tempo a mais
  previsto e não mexe no preço; `acrescimo` é o que o cliente paga a mais,
  acertado na cobrança. `acrescimo` e `acrescimo_motivo` são só leitura no
  serializer: só o `cobrar/` mexe, e `desfazer_cobranca/` zera.
- **Cobrar e desfazer avisam o app do cliente** pelo sinal `cobranca_registrada`:
  o serviço trocado, o acréscimo e o total cobrado — ao desfazer, o preço do
  serviço sem acréscimo. Mexer em `pago`/`acrescimo` por `.update()` pula isso.
- **`objeto` pode ser nulo (o avulso).** Nunca leia `atendimento.objeto.cliente`
  direto: use `atendimento.cliente` (nulo no avulso) ou `atendimento.rotulo` (o
  nome do cliente ou a identificação). O caixa, o painel e as pendências já
  passam por aí; `select_related('objeto__cliente')` continua valendo (vira
  LEFT JOIN). O `__str__` e o `?cliente=` também já tratam.
- **Cobrar o avulso não mexe em comanda:** `credito_aplicado` ou
  `troco_credito` acima de zero é 400 `avulso_sem_credito`, e o `cliente_id`
  das transações de crédito só existe com objeto.
- **O `AtendimentoKanban` pode nascer pelo app B2C**, via
  `apps_serv/vitrine/services.py`, criando `Pet`/`Veiculo` no tenant direto pelo
  ORM — sem passar pelos serializers deste app, portanto sem as validações deles.
