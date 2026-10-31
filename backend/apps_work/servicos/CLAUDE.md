# apps_work/servicos — CLAUDE.md

O **catálogo do negócio**: o que ele vende, por quanto e em quanto tempo.

App pequeno (~136 linhas), mas alimenta os dois modos de agenda e o app do
cliente final.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `models.py` | `Servico` — nome, duração, preço, quais colaboradores executam, e a taxa de cancelamento |
| `serializers.py` | Validação de preço, duração, o teto da taxa e o nicho do serviço |
| `views.py` | ViewSet. Escrita restrita ao proprietário; leitura liberada para colaborador. A lista filtra por `?search=`, `?ativo=`, `?colaborador=` e `?porte=` (os do porte e os sem porte), documentados no OpenAPI |
| `services.py` | `conferir_porte`: a trava do serviço de um porte só (`servico_de_outro_porte`), usada pelo kanban e pelo agendamento do app do cliente. `servicos_ativos`: os serviços de uma lista de ids, ativos, na ordem pedida e sem repetição (`servico_invalido`), usado pela troca de serviço na cobrança dos dois modos |
| `urls.py` | Rotas sob `/api/v1/servicos/` |

## Tabela

### `Servico` — um item do catálogo

| Coluna | Tipo | O que é |
|---|---|---|
| `nome` | `CharField(255)` | |
| `nicho` | `CharField(50)` | A pasta do serviço: um dos `EmpresaConfig.nichos`. Gravado sempre; a interface só mostra pastas com 2+ nichos |
| `porte` | `CharField(10)` vazio | Só na esteira: o porte do veículo ou do pet que o serviço atende ("Lavagem simples · Moto"). Vazio vale para qualquer porte, e é o único valor no modo horário. O serializer só aceita porte do `tipo_objeto` do negócio |
| `descricao` | `TextField` vazio | |
| `duracao` | `PositiveInteger` | **Em minutos.** É o que define conflito de horário na agenda |
| `preco` | `Decimal(8,2)` | |
| `taxa_cancelamento_tipo` | `CharField(10)` vazio | `valor` ou `percentual`. Vazio significa sem taxa |
| `taxa_cancelamento_valor` | `Decimal(8,2)` = 0 | Reais ou porcentagem, conforme o tipo. Teto de 30% do preço |
| `ativo` | `Boolean` = `True` | Desativar tira da vitrine na hora |
| `colaboradores` | `M2M → usuarios.Colaborador` | Quem executa este serviço. Vazio = qualquer um |

Não há campo de taxa calculada: `calcular_taxa_cancelamento()` resolve a partir
do tipo e do valor.

## A taxa de cancelamento

Dois campos definem: `taxa_cancelamento_tipo` (`valor` fixo ou `percentual`) e
`taxa_cancelamento_valor`. O método `calcular_taxa_cancelamento()` resolve para
um número.

O teto é **30% do preço** nos dois formatos, validado no serializer.

Ela só é cobrada quando o cliente cancela fora do prazo, e vira pendência na
comanda dele dentro do tenant — nunca cobrança automática. O prazo varia com a
duração do serviço (até 30min → 6h de antecedência; até 90min → 12h; acima → 24h)
e está em `apps_serv/vitrine/services.py`.

## O que é fácil errar aqui

- **`duracao` é o que define conflito de horário na agenda.** Alterar a duração
  de um serviço não reescreve agendamentos já feitos — o `AgendamentoServico`
  congela o preço, mas a duração é lida do serviço atual.
- **Só o proprietário edita.** `get_permissions` libera leitura para colaborador
  e exige `IsProprietario` para escrita.
- **`DELETE` apaga de verdade** e estoura se o serviço já foi agendado
  (`AgendamentoServico` protege). O app inativa por `PATCH ativo=false` e não
  chama o `DELETE`.
- **O nicho do serviço tem de ser um dos nichos do negócio.** Com um nicho só,
  pode ser omitido e o serializer usa ele; com mais, é obrigatório
  (`nicho_obrigatorio`). Serviço inativo de um nicho que o negócio deixou
  continua editável, mas só volta a ativo trocando para um nicho atual
  (`nicho_fora_do_negocio`).
- **Tirar um nicho na config inativa os serviços dele** — ver
  `apps_work/empresa/CLAUDE.md`.
- **Serviço de um porte só atende esse porte** (`Servico.serve_para`): sem
  porte atende qualquer um, e objeto sem porte (cadastro antigo) aceita
  qualquer serviço, porque não há com o que comparar. A trava
  (`conferir_porte`) vale ao receber no kanban, ao trocar o serviço do card
  por PATCH e no agendamento do app do cliente.
- **O app B2C lê este catálogo** via `CrossTenantQueryService.listar_servicos`,
  filtrando por `ativo=True`. Desativar serviço o remove da vitrine na hora.
