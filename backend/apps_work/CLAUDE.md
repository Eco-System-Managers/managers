# apps_work — CLAUDE.md

O lado **B2B**: o painel que o negócio usa para se gerenciar.

Doze apps, ~4.700 linhas. Quase todos vivem no **schema do tenant**
(`TENANT_APPS`) — cada negócio tem os próprios clientes, agenda e caixa, isolados
no nível do banco.

## Os doze apps

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
| `empresa` | Configuração do negócio: nicho, endereço, logo, horários |
| `billing` | A assinatura do negócio na plataforma |

**Apoio**

| App | Papel |
|---|---|
| `contratos` | Modelos, geração e assinatura pública |
| `dashboard` | Visão de leitura sobre os outros. Sem model próprio |
| `notificacoes` | Avisos no painel. O menor app |

## Sobre as tabelas

Cada app documenta as próprias colunas no `CLAUDE.md` dele.

Duas convenções valem para todas e não se repetem lá: **toda tabela tem `id`**
`BigAutoField` implícito (`DEFAULT_AUTO_FIELD`), e campo `blank=True` significa
opcional no formulário e no serializer — não necessariamente `NULL` no banco,
que para texto costuma ser string vazia.

## Os dois modos de agenda

A decisão mais estruturante do produto. `EmpresaConfig.nicho` define
`tipo_agenda`, e o negócio usa **um** dos dois:

| Modo | Para quem | Como funciona |
|---|---|---|
| `horario` | barbearia, salão, clínica | Horário marcado com profissional. Conflito é sobreposição na agenda de alguém |
| `kanban` | lava-rápido, banho & tosa | O objeto entra numa fila de etapas. Status é derivado da coluna |

Boa parte da complexidade do backend vem de os dois coexistirem: caixa, painel,
pendências de cobrança e a agenda do cliente no app precisam ler os dois.

## Quais são compartilhados

Nem todos são de tenant. `autenticacao` e `billing` estão em `SHARED_APPS`:

- `autenticacao` porque o relógio de inatividade precisa funcionar antes de o
  schema ser resolvido
- `billing` porque a cobrança é da plataforma para o negócio, não um dado de
  dentro do negócio

Os demais são de tenant, e migram com `migrate_schemas` — não com `migrate`.

## A relação com o `apps_serv`

A dependência anda **numa direção só**: o `apps_serv` conhece estes apps, e
estes apps não conhecem o `apps_serv`.

Quando algo daqui precisa aparecer no app do cliente, o caminho é sinal. Quatro
deles atravessam a fronteira, e todos são escutados em
`apps_serv/vitrine/handlers.py`:

| Sinal | Declarado em |
|---|---|
| `empresa_config_atualizada` | `empresa/signals.py` |
| `cliente_servicemanage_removido` | `clientes/signals.py` |
| `agendamento_status_alterado` | `agenda/signals.py` |
| `atendimento_kanban_falta_alterada` | `kanban/signals.py` |

## O que é fácil errar aqui

- **Alterar por `.update()` no queryset pula os sinais.** O registro muda no
  tenant e o app do cliente continua mostrando o estado antigo.
- **Migration de app de tenant roda em todos os schemas.** Entre schemas ela
  pode ficar parcialmente aplicada, então o código precisa tolerar o estado
  intermediário.
- **Regra de negócio vai em `services.py`**, não em view nem serializer. Views
  recebem, delegam e devolvem.
- **Escrita sensível exige `IsProprietario`** — serviços, etapas do kanban,
  configuração e billing. Estar autenticado não basta.
