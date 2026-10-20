# apps_work/notificacoes — CLAUDE.md

Avisos para o negócio dentro do painel. **87 linhas** — o menor app do backend.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `models.py` | `Notificacao` — tipo, título, mensagem, cliente relacionado e `lida` |
| `views.py` | ViewSet somente leitura, mais as ações de marcar lida e contar não lidas |
| `serializers.py` | Representação |

## Tabela

### `Notificacao` — o aviso no painel

| Coluna | Tipo | O que é |
|---|---|---|
| `tipo` | `CharField(30)` | `cliente_vinculado` ou `cliente_desvinculado` |
| `titulo` | `CharField(255)` | O texto que aparece na lista |
| `mensagem` | `CharField(500)` vazio | Detalhe opcional |
| `cliente` | `FK → clientes.Cliente` `SET_NULL`, nulo | `SET_NULL` de propósito: a notificação sobrevive à remoção do cliente |
| `lida` | `Boolean` = `False` | Alimenta o badge do sino |
| `criado_em` | `DateTime` `auto_now_add` | |

Ordenação padrão por `-criado_em`.

## Quem cria notificação

Não é este app. Ele só armazena e exibe. Hoje quem escreve aqui é o
`apps_serv/vitrine/services.py`, ao vincular ou desvincular um cliente:

- `cliente_vinculado` — "fulano agora é seu cliente"
- `cliente_desvinculado` — "fulano não é mais seu cliente"

E só na **transição**. Notificar a cada agendamento faria o dono receber "fulano
agora é seu cliente" toda vez que um cliente antigo agendasse.

## O que é fácil errar aqui

- **O ViewSet é `ReadOnly`.** Criar notificação é feito pelo ORM, de dentro de
  outro app — não há endpoint de escrita, e é proposital.
- **`nao-lidas` devolve só a contagem**, não a lista. É o badge do sino, chamado
  com frequência; devolver os objetos seria desperdício.
- **A listagem é paginada** pela paginação padrão do projeto
  (`core/paginacao.py`), como toda coleção de recurso.
