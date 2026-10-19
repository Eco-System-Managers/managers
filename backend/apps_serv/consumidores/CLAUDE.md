# apps_serv/consumidores — CLAUDE.md

A **conta do cliente final** e tudo que se pendura nela.

Vive no schema público: o cadastro é único e serve todos os negócios da
plataforma. Não há cópia por tenant — os negócios vinculados recebem um espelho
sincronizado, nunca a fonte.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `models.py` | Cinco modelos, descritos abaixo. É onde mora a forma dos dados do lado B2C |
| `services.py` | Registro, login, recuperação de senha e — o mais importante — `SincronizarClienteService`, que empurra o perfil para todos os tenants vinculados |
| `views.py` | Perfil (`/me/`), foto, agenda do cliente, vínculos e os objetos (pets/veículos). Views finas, exceto o cadastro de objeto, que valida ali mesmo |
| `serializers.py` | Representação e validação. `ConsumidorUpdateSerializer` define o que o cliente pode editar do próprio cadastro |
| `urls.py` | Rotas sob `/api/sm/` |

## Os cinco modelos

| Modelo | Para que serve |
|---|---|
| `Consumidor` | A conta. Guarda a ficha completa (nome, telefone, CPF, endereço, foto). Tem `set_password`/`check_password` próprios — não herda de `AbstractUser` |
| `CodigoRecuperacaoConsumidor` | Código de recuperação de senha, com expiração de 15min e trava após 5 tentativas |
| `VinculoConsumidor` | Liga cliente a negócio. **Soft delete**: desvincular marca `ativo=False`, nunca apaga — assim revincular reativa em vez de duplicar |
| `ObjetoConsumidor` | O pet ou veículo do cliente, em `JSONField`. É a fonte; o `Pet`/`Veiculo` do tenant é cópia |
| `AgendamentoConsumidor` | A agenda do cliente, atravessando todos os negócios. Guarda `schema_name` + `agendamento_id` (referência solta ao registro no tenant) e um **snapshot** dos serviços |

## Tabelas

### `Consumidor` — a conta

| Coluna | Tipo | O que é |
|---|---|---|
| `email` | `EmailField` **único** | Credencial de login. Não editável pelo app |
| `password` | `CharField(128)` | Hash do Django (`set_password`/`check_password` próprios) |
| `nome` | `CharField(255)` | |
| `telefone` | `CharField(20)` obrigatório | É por ele que o negócio fala com quem agendou |
| `cpf` | `CharField(14)` vazio | Único por conta, validado no serializer |
| `data_nascimento` | `DateField` nulo | |
| `cep` · `endereco` · `numero_endereco` | `CharField` vazios | |
| `foto_chave` | `CharField(255)` vazio | Caminho no S3, **não** URL — a foto é privada e a URL sai assinada, válida por uma hora |
| `is_active` | `Boolean` = `True` | |
| `criado_em` | `DateTime` `auto_now_add` | |
| `sessoes_validas_desde` | `DateTimeField` nulo | Preenchido na troca de senha. Token com `iat` anterior é recusado |

### `RefreshRevogadoConsumidor` — refresh que não vale mais

| Coluna | Tipo | O que é |
|---|---|---|
| `jti` | `CharField(64)` único | O id do refresh. O `unique` barra renovação dupla simultânea |
| `expira_em` | `DateTimeField` | Quando o token expiraria de qualquer forma. Depois disso a linha pode ser apagada |
| `revogado_em` | `DateTime` `auto_now_add` | |

Gravado ao renovar (o refresh usado) e no logout. Ver `../autenticacao/CLAUDE.md`.

### `CodigoRecuperacaoConsumidor`

| Coluna | Tipo | O que é |
|---|---|---|
| `consumidor` | `FK → Consumidor` `CASCADE` | |
| `codigo_hash` | `CharField(128)` | Hash do código (`make_password`). O código em claro só existe no e-mail |
| `criado_em` | `DateTime` `auto_now_add` | |
| `expira_em` | `DateTimeField` | 15 minutos, definido no `save()` |
| `usado` | `Boolean` = `False` | |
| `tentativas` | `PositiveSmallInteger` = 0 | Trava em 5 (`MAX_TENTATIVAS`) |

Ordenação por `-criado_em`. `expirado` e `bloqueado` são propriedades, não
colunas. Crie com `CodigoRecuperacaoConsumidor.emitir(consumidor)` e confira
com `registro.confere(codigo)`. O e-mail sai por task (`core/email.py`).

### `VinculoConsumidor` — cliente ↔ negócio

| Coluna | Tipo | O que é |
|---|---|---|
| `consumidor` | `FK → Consumidor` `CASCADE` | |
| `schema_name` | `CharField(63)` | Qual negócio. Referência solta — não há FK para tenant aqui |
| `ativo` | `Boolean` = `True` | **Soft delete.** Desvincular marca `False` |
| `criado_em` | `DateTime` `auto_now_add` | |
| `desvinculado_em` | `DateTimeField` nulo | Quando saiu. Volta a nulo se revincular |

Único por `(consumidor, schema_name)` — é o que faz revincular reativar em vez
de duplicar.

### `ObjetoConsumidor` — o pet ou veículo

| Coluna | Tipo | O que é |
|---|---|---|
| `consumidor` | `FK → Consumidor` `CASCADE` | |
| `tipo` | `CharField(20)` | `veiculo` ou `pet` |
| `dados` | `JSONField` | Os atributos, sem esquema fixo. É a **fonte**; o `Pet`/`Veiculo` do tenant é cópia |
| `nome_exibicao` | `CharField(255)` | Montado na criação (ex.: "Honda Civic · ABC1D23") |
| `criado_em` | `DateTime` `auto_now_add` | Ordenação por `-criado_em` |

### `AgendamentoConsumidor` — a agenda do cliente

| Coluna | Tipo | O que é |
|---|---|---|
| `consumidor` | `FK → Consumidor` `CASCADE` | |
| `schema_name` | `CharField(63)` | Em qual negócio |
| `agendamento_id` | `PositiveInteger` | Referência solta ao `Agendamento` ou `AtendimentoKanban` no tenant |
| `origem` | `CharField(10)` = `agenda` | `agenda` ou `kanban`. Decide qual tabela do tenant o id aponta |
| `negocio_nome` | `CharField(255)` | Snapshot |
| `nicho` | `CharField(50)` vazio | Snapshot |
| `servicos` | `JSONField` = `[]` | Snapshot: nome, duração, preço e taxa de cada serviço |
| `profissional_nome` | `CharField(255)` vazio | Snapshot. Vazio na esteira |
| `data_hora` | `DateTimeField` | Ordenação por `-data_hora` |
| `duracao_total` | `PositiveInteger` | Em minutos. Define o prazo de cancelamento gratuito |
| `valor_total` | `Decimal(10,2)` | Snapshot |
| `valor_taxa_cancelamento` | `Decimal(10,2)` = 0 | Snapshot da taxa no momento do agendamento |
| `status` | `CharField(20)` = `agendado` | `agendado`, `confirmado`, `concluido`, `cancelado`, `faltou` |
| `objeto_dados` | `JSONField` nulo | Snapshot do pet/veículo |
| `criado_em` | `DateTime` `auto_now_add` | |

**Não há coluna de logo.** Ela é resolvida ao vivo no serializer: logo troca por
upload, e um snapshot mostraria a marca antiga para sempre.

## Por que o agendamento guarda snapshot

`servicos`, `negocio_nome`, `valor_total` são copiados no momento do
agendamento. Se o negócio mudar o preço ou renomear o serviço depois, o
histórico do cliente continua mostrando o que foi combinado.

A exceção é a **logo**, que é resolvida ao vivo no serializer: logo troca por
upload, e um snapshot mostraria a marca antiga para sempre.

## O que é fácil errar aqui

- **`SincronizarClienteService` engole exceção de propósito.** Salvar o perfil
  não pode falhar porque um tenant está fora do ar — cada tenant que falha se
  acerta no próximo salvamento.
- **O e-mail não é mais a chave de ligação** com o `Cliente` do tenant; quem faz
  isso é `Cliente.consumidor_id`. O e-mail continua bloqueado para edição, mas
  agora por ser credencial de login, não por ser chave.
- **`ObjetosConsumidorView.post` valida apenas presença dos campos**, não o
  formato. Existe um `_placa_valida` no arquivo que nunca é chamado — placa
  inválida cadastrada aqui chega ao banco do negócio sem passar por serializer.
