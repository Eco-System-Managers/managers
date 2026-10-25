# apps_work/clientes — CLAUDE.md

A **ficha do cliente** dentro do negócio, e os objetos que pertencem a ele.

Um cliente pode ter duas origens: cadastrado à mão pelo negócio, ou vindo do app
Service Manage. A diferença muda o que o painel pode fazer com ele.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `models.py` | `Cliente` e a hierarquia `ObjetoCliente` → `Veiculo` / `Pet` |
| `validators.py` | Validação de CPF, telefone brasileiro (com lista de DDDs válidos) e placa (formato antigo e Mercosul) |
| `serializers.py` | Representação e validação. Trava campos quando o cadastro pertence ao consumidor |
| `services.py` | `RemocaoClienteService` — remoção que respeita a origem |
| `views.py` | ViewSets de cliente, veículo e pet. Busca por nome, telefone, e-mail ou CPF |
| `signals.py` | Declara `cliente_servicemanage_removido`, escutado pela vitrine |

## Tabelas

### `Cliente` — a ficha

Identificação e contato:

| Coluna | Tipo | O que é |
|---|---|---|
| `nome` | `CharField(255)` | |
| `telefone` | `CharField(20)` obrigatório | É por ele que o negócio fala com o cliente. Cadastros antigos sem telefone continuam no banco, mas não passam numa próxima edição |
| `email` | `EmailField` vazio | **Não é único** — um tenant pode ter dois cadastros com o mesmo e-mail |
| `cpf` | `CharField(14)` vazio | |
| `data_nascimento` | `DateField` nulo | |
| `cep` · `endereco` · `numero_endereco` | `CharField` vazios | |
| `observacao` | `TextField` vazio | |
| `foto_chave` | `CharField(255)` vazio | Caminho no S3, **não** URL — a foto é privada e a URL é assinada a cada resposta |

Campos por nicho (preenchidos conforme o ramo do negócio):

| Coluna | Tipo | Nicho |
|---|---|---|
| `alergia` | `TextField` vazio | Beleza |
| `convenio` · `carteirinha` · `plano_saude` | `CharField` vazios | Saúde |
| `validade_plano_saude` | `DateField` nulo | Saúde |

Controle:

| Coluna | Tipo | O que é |
|---|---|---|
| `visivel` | `Boolean` = `True` | Soft delete. `False` quando o consumidor se desvincula. O registro nunca é apagado, por retenção fiscal |
| `origem` | `CharField(20)` = `manual` | `manual` ou `servicemanage`. Decide se o painel pode editar e o que acontece ao remover |
| `consumidor_id` | `PositiveInteger` **único**, indexado, nulo | Quem é esta pessoa no schema público. Referência solta, sem FK. Nulo em cadastro manual — até o mesmo e-mail se vincular pelo app, quando o cadastro passa a ser do consumidor |
| `criado_em` | `DateTime` `auto_now_add` | |

### `ObjetoCliente` — a base de pet e veículo

| Coluna | Tipo | O que é |
|---|---|---|
| `cliente` | `FK → Cliente` `CASCADE` | |
| `tipo` | `CharField(20)` | `veiculo` ou `pet` |
| `criado_em` | `DateTime` `auto_now_add` | |

Ordenação por `-criado_em`. As duas tabelas abaixo herdam dela por
**multi-table inheritance**: cada uma tem tabela própria com um `ptr` para esta.

### `Veiculo`

| Coluna | Tipo | O que é |
|---|---|---|
| `placa` | `CharField(10)` | Validada por `validar_placa_br` no serializer — mas **não** quando criada pelo fluxo do app B2C |
| `marca` · `modelo` · `cor` | `CharField` | |

### `Pet`

| Coluna | Tipo | O que é |
|---|---|---|
| `nome` | `CharField(100)` | |
| `especie` · `raca` | `CharField` vazios | |
| `porte` | `CharField(10)` vazio | `pequeno`, `medio`, `grande`, `gigante` |
| `data_nascimento` | `DateField` nulo | |

## Os campos que decidem comportamento

| Campo | O que muda |
|---|---|
| `origem` | `manual` ou `servicemanage`. Quem veio do app tem o cadastro **mantido pelo cliente** — o painel não edita, e remover desfaz o vínculo em vez de apagar |
| `visivel` | Soft delete. Vira `False` quando o consumidor se desvincula. O registro nunca é apagado, por retenção fiscal |
| `consumidor_id` | A identidade estável do par com o schema público. Referência solta, sem `ForeignKey` |

## Herança dos objetos

`Veiculo` e `Pet` herdam de `ObjetoCliente` (multi-table inheritance). O tipo de
objeto que um negócio usa está em `EmpresaConfig.tipo_objeto`: lava-rápido usa
veículo, banho e tosa usa pet, e no nicho `outro` o dono escolhe
(`empresa/services.py`, `ModoAgendaService`).

## O que é fácil errar aqui

- **`consumidor_id` é único.** Um tenant não pode ter dois `Cliente` para a
  mesma pessoa: o banco recusa o segundo com `IntegrityError`. Ao *ligar* um
  cadastro existente (`apps_serv/identidade.py`), essa falha é registrada e a
  operação segue com o cadastro encontrado, num savepoint — agendar não pode
  quebrar por causa da ligação.
- **Os campos espelhados do consumidor estão em `Cliente.CAMPOS_ESPELHADOS`** e
  os que saem ao desfazer o vínculo, em `Cliente.CAMPOS_PESSOAIS`. Vincular,
  sincronizar o perfil, travar a edição no painel e remover pelo painel leem
  dessas listas.
- **Remover cliente do app não apaga a linha.** `RemocaoClienteService` marca
  invisível, apaga os dados pessoais (mesma regra do desvínculo pelo app) e
  dispara sinal com o `consumidor_id` para desfazer o vínculo no público. Apagar
  a linha deixaria o vínculo órfão e o cadastro ressurgiria no próximo
  agendamento.
- **A busca (`?search=`) cobre 4 campos** (nome, telefone, e-mail, CPF; documentada
  no OpenAPI) e alimenta os nove autocompletes dos frontends. A listagem usa a
  paginação padrão (`core/paginacao.py`).
- **Remover cliente manual com atendimento responde 400 `cliente_com_atendimentos`.**
  Agendamento e atendimento protegem o cliente (`PROTECT`); antes o `delete()`
  estourava em 500.
- **O cadastro que veio do app é sincronizado de fora.** Editar aqui campo que o
  consumidor controla é trabalho perdido: a próxima sincronização sobrescreve.

## Importação do GENDO

`python manage.py importar_gendo arquivo.csv [--schema <empresa>] [--dry-run]`
traz a base de clientes exportada do GENDO (latin-1, `;`). Sem `--schema`, o
comando lista as empresas e pergunta qual recebe. O que tem campo na ficha vai
para o campo (telefone passa pelo mesmo validador da API; o que não passa fica
na observação); cidade/UF, visitas, faturamento e dívida vão para a observação;
saldo positivo vira crédito manual na comanda; `GENDO #código` na observação é a
chave que impede duplicar numa segunda rodada. O CSV fica em `backend/tmp/`,
que está no `.gitignore`.
