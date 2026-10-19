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
| `convenio` · `carteirinha` · `plano` | `CharField` vazios | Saúde |
| `validade_plano` | `DateField` nulo | Saúde |

Controle:

| Coluna | Tipo | O que é |
|---|---|---|
| `visivel` | `Boolean` = `True` | Soft delete. `False` quando o consumidor se desvincula. O registro nunca é apagado, por retenção fiscal |
| `origem` | `CharField(20)` = `manual` | `manual` ou `servicemanage`. Decide se o painel pode editar e o que acontece ao remover |
| `consumidor_id` | `PositiveInteger` **único**, indexado, nulo | Quem é esta pessoa no schema público. Referência solta, sem FK. Nulo em cadastro manual |
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
objeto que um negócio usa vem do nicho: lava-rápido e estética automotiva usam
veículo; banho & tosa usa pet.

## O que é fácil errar aqui

- **`consumidor_id` é único.** Um tenant não pode ter dois `Cliente` para a
  mesma pessoa. Tentar criar o segundo levanta `IntegrityError` — de propósito,
  para falhar alto em vez de duplicar em silêncio.
- **Remover cliente do app não apaga.** `RemocaoClienteService` marca invisível
  e dispara sinal para desfazer o vínculo no público. Apagar a linha deixaria o
  vínculo órfão e o cadastro ressurgiria no próximo agendamento.
- **A busca (`?search=`) cobre 4 campos** e alimenta os nove autocompletes dos
  frontends. A listagem é paginada de 20 em 20.
- **O cadastro que veio do app é sincronizado de fora.** Editar aqui campo que o
  consumidor controla é trabalho perdido: a próxima sincronização sobrescreve.
