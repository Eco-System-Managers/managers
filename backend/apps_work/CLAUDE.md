# apps_work — CLAUDE.md

O lado **B2B**: o painel que o negócio usa para se gerenciar.

Quatorze apps, ~5.200 linhas. Quase todos são **apps de negócio**: os modelos
herdam de `core.tenant.TenantModel` e cada linha carrega `tenant_id` — cada
negócio tem os próprios clientes, agenda e caixa, isolados pelo manager (que
filtra pelo tenant atual) e pelo Row Level Security do Postgres (`core/rls.py`).

## Os quatorze apps

**Operação do dia a dia**

| App | Papel |
|---|---|
| `agenda` | Agendamento por horário marcado. Um dos dois modos |
| `kanban` | Agendamento por esteira. O outro modo |
| `servicos` | O catálogo: o que o negócio vende, por quanto, em quanto tempo |
| `clientes` | A ficha do cliente e seus pets/veículos |
| `financeiro` | A comanda do cliente e o fechamento de caixa |

**Conta e configuração**

| App | Papel |
|---|---|
| `autenticacao` | Login do negócio, e a criação do tenant no cadastro |
| `usuarios` | Colaboradores, papéis e convites |
| `empresa` | Configuração do negócio: nichos, endereço, logo, horários |
| `billing` | A assinatura do negócio na plataforma |

**Apoio**

| App | Papel |
|---|---|
| `contratos` | Modelos, geração e assinatura pública |
| `dashboard` | Visão de leitura sobre os outros. Sem model próprio |
| `notificacoes` | Avisos no painel. O menor app |
| `paginas` | As páginas HTML dos links que abrem no navegador: convite, contrato e volta do checkout. Sem model; as regras são dos services de `usuarios`, `contratos` e `billing` |
| `uso` | Os eventos de uso (cada escrita, cada erro, cada abertura do app) e o `relatorio_uso`, para acompanhar os testadores |

## Sobre as tabelas

Cada app documenta as próprias colunas no `CLAUDE.md` dele.

Duas convenções valem para todas e não se repetem lá: **toda tabela tem `id`**
`BigAutoField` implícito (`DEFAULT_AUTO_FIELD`), e campo `blank=True` significa
opcional no formulário e no serializer — não necessariamente `NULL` no banco,
que para texto costuma ser string vazia.

## Os dois modos de agenda

A decisão mais estruturante do produto. O negócio usa **um** dos dois, gravado
em `EmpresaConfig.tipo_agenda`. Nos nichos conhecidos, o nicho decide; no nicho
`outro`, o dono escolhe (`empresa/services.py`, `ModoAgendaService`). Depois do
onboarding, o modo não muda mais:

| Modo | Para quem | Como funciona |
|---|---|---|
| `horario` | barbearia, salão, clínica | Horário marcado com profissional. Conflito é sobreposição na agenda de alguém |
| `kanban` | lava-rápido, banho & tosa | O objeto (veículo ou pet, em `EmpresaConfig.tipo_objeto`) entra numa fila de etapas. Status é derivado da coluna |

Boa parte da complexidade do backend vem de os dois coexistirem: caixa, painel,
pendências de cobrança e a agenda do cliente no app precisam ler os dois.

## Quais são públicos

Nem todos são de negócio. `autenticacao`, `billing`, `paginas` e `uso` têm
modelos comuns, sem `tenant` (`paginas` porque responde fora de um negócio e
entra no do token do link com `com_tenant`):

- `autenticacao` porque o relógio de inatividade precisa funcionar antes de o
  tenant ser resolvido
- `billing` porque a cobrança é da plataforma para o negócio, não um dado de
  dentro do negócio
- `uso` porque o relatório lê os eventos de todos os negócios de uma vez

Os demais são de negócio (`core.rls.APPS_DE_NEGOCIO`). O tenant atual vem do
`TenantMiddleware` (Host ou JWT) numa requisição, e de `com_tenant(...)` em
serviço, task ou comando. Fora de um tenant, consultar modelo de negócio é
erro (`TenantIndefinido`), não lista vazia.

## A relação com o `apps_serv`

A dependência anda **numa direção só**: o `apps_serv` conhece estes apps, e
estes apps não conhecem o `apps_serv`.

Quando algo daqui precisa aparecer no app do cliente, o caminho é sinal. Cinco
deles atravessam a fronteira, e todos são escutados em
`apps_serv/vitrine/handlers.py`:

| Sinal | Declarado em |
|---|---|
| `empresa_config_atualizada` | `empresa/signals.py` |
| `cliente_servicemanage_removido` | `clientes/signals.py` |
| `agendamento_status_alterado` | `agenda/signals.py` |
| `atendimento_kanban_falta_alterada` | `kanban/signals.py` |
| `cobranca_registrada` | `financeiro/signals.py` (disparado pelo `cobrar` da agenda e do kanban) |

## O que é fácil errar aqui

- **O contrato da API está em `openapi/README.md`.** Erro sempre
  `{detail, code, fields?}`: levante `ErroDeNegocio(msg, code)` no service, ou use
  `erro()` (`core/excecoes.py`) quando a view precisar montar a resposta. Coleção
  de recurso sai paginada (`core/paginacao.py`); dinheiro sai como string.
- **APIView nova precisa de `@extend_schema`** (entrada e saída), senão fica fora
  do schema e do client Dart. Depois de mudar view ou serializer, rode
  `manage.py gerar_openapi` e versione `openapi/` — `tests/test_openapi.py` falha
  se os `.yaml` estiverem desatualizados.
- **Alterar por `.update()` no queryset pula os sinais.** O registro muda no
  tenant e o app do cliente continua mostrando o estado antigo.
- **Modelo de negócio novo herda de `TenantModel`** e ganha política de RLS
  na migration (chame `core.rls.aplicar_politicas` num `RunPython`). Unique
  que é "por negócio" leva `tenant` junto (`UniqueConstraint`).
- **`bulk_create` e SQL direto não passam pelo `save()`**: o queryset do
  manager preenche o tenant no `bulk_create`; SQL direto precisa pôr
  `tenant_id` à mão (o RLS recusa a linha sem ele).
- **Regra de negócio vai em `services.py`**, não em view nem serializer. Views
  recebem, delegam e devolvem.
- **Escrita sensível exige `IsProprietario`** — etapas do kanban, configuração,
  billing e gestão da equipe. Estar autenticado não basta. O papel vem do
  `Membro.papel` — o `Colaborador` não tem papel. **Na esteira o parceiro toca
  o negócio com o dono** (`IsProprietarioOuParceiroDaEsteira` em serviços e
  modelos de contrato, a função `eh_proprietario_ou_parceiro_da_esteira` no
  bloqueio do negócio; `IsProprietarioOuParceiro` nas ações do quadro e na
  capacidade do dia) e o colaborador comum só move os cards
  (`NaoEhColaboradorDaEsteira`). A tabela inteira está em `usuarios/CLAUDE.md`.
- **Autenticado significa autenticado neste tenant.** A autenticação padrão é a
  `core.authentication.TenantJWTAuthentication`, que recusa token de outro
  negócio e usuário sem `Membro` no tenant atual. A checagem não pode ir
  para `DEFAULT_PERMISSION_CLASSES`: quase toda view declara as próprias
  permissões e a ignoraria.
- **`force_authenticate` nos testes pula a autenticação** — e com ela a
  checagem de vínculo. Teste de acesso entre tenants precisa de token real.
