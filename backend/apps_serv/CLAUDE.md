# apps_serv — CLAUDE.md

O lado **B2C**: tudo que o cliente final usa pelo app Service Manage.

Três apps, ~2.100 linhas. Todos vivem no **schema público** (`SHARED_APPS`) —
uma conta de cliente não pertence a negócio nenhum, ela atravessa a plataforma
inteira.

## Os três apps

| App | Papel |
|---|---|
| `autenticacao` | Login e sessão do cliente final. Não usa o `User` do Django nem o SimpleJWT — tem JWT próprio |
| `consumidores` | A conta em si: cadastro, perfil, pets/veículos, agenda do cliente e vínculos com negócios |
| `vitrine` | O que o cliente enxerga dos negócios: mapa, busca, e a criação do agendamento. É o único que atravessa schemas |

## Sobre as tabelas

Cada app documenta as próprias colunas no `CLAUDE.md` dele.

Duas convenções valem para todas e não se repetem lá: **toda tabela tem `id`**
`BigAutoField` implícito (`DEFAULT_AUTO_FIELD`), e campo `blank=True` significa
opcional no formulário e no serializer — não necessariamente `NULL` no banco,
que para texto costuma ser string vazia.

## Por que existe separado de `apps_work`

São dois públicos com necessidades opostas. O `apps_work` atende o **negócio**,
dentro do schema dele, com dados isolados por tenant. O `apps_serv` atende a
**pessoa**, que usa vários negócios e não pode estar presa a nenhum schema.

Misturar os dois faria a conta do cliente ter que ser duplicada em cada tenant —
que é exatamente o problema que o schema público resolve.

## A fronteira entre os dois mundos

Todo o tráfego cross-schema passa por `vitrine/services.py` e por
`consumidores/services.py`. Nenhuma view troca de schema por conta própria.

O par entre os dois lados é `Cliente.consumidor_id` (no tenant) apontando para
`Consumidor.id` (no público). É referência solta, sem `ForeignKey` — um FK de
verdade amarraria a migration de cada tenant à tabela pública.

Os apps de negócio **não conhecem** o `apps_serv`. A comunicação de volta é por
sinal: `vitrine/handlers.py` escuta o que acontece no tenant e reflete no
público. Assim a dependência anda só numa direção.

## O que é fácil errar aqui

- **Operação que grava nos dois lados precisa ser atômica.** Criar agendamento
  escreve no tenant e no público. Efeito colateral que pode falhar sem derrubar
  o agendamento (sincronizar perfil, notificar) roda em savepoint próprio —
  engolir exceção sem savepoint aborta a transação inteira.
- **Autenticação de consumidor não é a do Django.** `request.user` aqui é um
  `Consumidor`, não um `User`. Permissão que assuma o contrário quebra.
- **`schema_name` vindo da URL é entrada de usuário.** As views da vitrine
  validam o formato antes de usar (`_schema_valido`), porque ele acaba virando
  troca de schema.
