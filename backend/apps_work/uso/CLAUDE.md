# apps_work/uso — CLAUDE.md

Os dados para acompanhar **como os negócios usam o app**: quem usou, o quê,
onde travou e o que demorou. Nasceu para a fase dos testadores, junto com o
que eles contam por WhatsApp.

Vive no schema público (`SHARED_APPS`): o relatório lê todos os negócios de
uma vez.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `models.py` | `EventoDeUso`, uma linha por ação |
| `registro.py` | O que vira evento e com que nome (`deve_registrar`, `nome_do_evento`), e o `registrar`, chamado pelo `RequisicaoMiddleware` |
| `relatorio.py` | `montar()`: os números do período e o funil de cada negócio |
| `management/commands/relatorio_uso.py` | Imprime o relatório: `manage.py relatorio_uso --dias 7 [--empresa <schema>]` |
| `admin.py` | A lista de eventos no `/admin/`, só leitura, com o negócio e o e-mail ao lado e o filtro por resultado (sucesso, 4xx, 5xx) |

## Como o evento nasce

O `core.middleware.RequisicaoMiddleware` mede cada requisição da API e monta o
retrato dela (`core/requisicao.py`). O retrato vira a linha do log (todas as
requisições) e, nas rotas do Work Manage (`/api/v1/`), passa pelo
`registrar`. **Nenhum service chama nada**: o evento sai do nome da rota.

- coleção do router (`agendamento-list`): POST vira `agendamento.criar`
- item (`agendamento-detail`): PUT/PATCH vira `.editar`, DELETE vira `.remover`
- as outras: o nome da rota no POST (`agendamento-cobrar`, `auth-login`) e
  com o método nos demais (`kanban-capacidade.put`, `empresa-config.patch`)
- `GET colaboradores/me/` com sucesso vira `app.aberto`: a casca do app chama
  ao entrar

Entra toda escrita, todo erro (4xx e 5xx, de qualquer método) e o
`app.aberto`. Ficam de fora as leituras de sucesso (a maior parte do tráfego),
a renovação da sessão (`auth-token-refresh` e o 401 `token_invalido` que a
provoca), endereços que não existem e o Service Manage.

## Tabela

### `EventoDeUso`

| Coluna | Tipo | O que é |
|---|---|---|
| `criado_em` | `DateTime` `auto_now_add`, índice | |
| `schema_name` | `CharField(63)`, índice | O negócio. Vazio quando não há (login que falhou) |
| `user_id` | `PositiveInteger` null, índice | Quem fez. Null sem login |
| `papel` | `CharField(20)` | `proprietario` ou `colaborador` (o `Membro.papel`), quando a autenticação do DRF rodou |
| `evento` | `CharField(80)`, índice | O nome acima |
| `metodo` | `CharField(7)` | |
| `objeto_id` | `CharField(40)` | O `pk` (ou `cliente_id`...) da URL: segue a vida de um card ou agendamento |
| `status` | `PositiveSmallInteger` | |
| `codigo` | `CharField(60)` | O `code` do erro (`horario_conflito`, `dia_lotado`...) |
| `duracao_ms` | `PositiveInteger` | |
| `plataforma` | `CharField(10)` | `mobile` (o `X-Client-Platform`) ou `web` |
| `versao_app` | `CharField(30)` | O cabeçalho `X-App-Version`. **O app ainda não manda**: fica vazio até mandar |

Índice composto em `(schema_name, criado_em)`. Negócio e pessoa ficam **sem
FK**, de propósito: o evento é registro do que aconteceu e não pode travar a
exclusão do negócio nem sumir por cascata. Quem apaga é o
`ExclusaoContaService`, junto com o resto: os do negócio inteiro, ou só os da
pessoa.

## O relatório

`relatorio_uso` mostra, no período (padrão 7 dias, contando hoje):

- **Por dia:** pessoas e negócios ativos, ações e erros
- **Negócios:** o último uso de sempre (quem largou aparece no fim, com "há N
  dias") e o que fez no período; e o **funil**, contado nos dados do schema
  (onboarding, serviços, clientes, atendimentos, cobrados, equipe, contratos),
  então vale também para o que aconteceu antes de os eventos existirem
- **Ações mais usadas**, **erros de regra** (4xx por evento e `code`), **erros
  do servidor** (5xx, com hora, para achar o traceback no log do Railway) e as
  **mais lentas** (média e máximo)

## O que é fácil errar aqui

- **Nada do conteúdo entra.** Nem o corpo, nem a query string (a busca de
  clientes manda nome e telefone por ela), nem o token dos links de convite e
  contrato (`core/requisicao.py` troca por `:token`). Campo novo no evento
  segue a mesma regra: o tipo da ação, nunca o dado.
- **Gravar nunca derruba a requisição:** o `registrar` roda num savepoint e
  engole a falha com um aviso no log.
- **Rota sem `name` não vira evento.** Toda rota nova precisa de nome (o
  router já dá).
