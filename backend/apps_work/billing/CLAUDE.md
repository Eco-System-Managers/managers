# apps_work/billing — CLAUDE.md

A **assinatura do negócio** na plataforma, integrada ao Mercado Pago.

Cuidado para não confundir com o `financeiro`: aquele é o dinheiro entre o
negócio e os clientes dele. Este é o dinheiro entre o negócio e **nós**.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `models.py` | `Plano`, `Assinatura` (com a propriedade `bloqueada`) e `PagamentoAssinatura` |
| `services.py` | `GatewayPagamento` (a interface do provedor) e `MercadoPagoGateway`, a implementação: criar plano no gateway, gerar link, confirmar, cancelar e processar webhook. `gateway_de_pagamento()` devolve o configurado em `BILLING_GATEWAY` |
| `views.py` | Assinatura atual, iniciar, confirmar, cancelar, histórico paginado e o endpoint de webhook |
| `serializers.py` | Representação |

## Tabelas

### `Plano` — o que a plataforma vende

| Coluna | Tipo | O que é |
|---|---|---|
| `nome` | `CharField(50)` **único** | `pro`, `business`, `enterprise` |
| `preco_mensal` | `Decimal(8,2)` | |
| `limite_colaboradores` | `IntegerField` nulo | Nulo = sem limite |
| `ativo` | `Boolean` = `True` | |
| `gateway` | `CharField(20)` = `mercadopago` | Provedor de pagamento (`Gateway`) |
| `id_externo` | `CharField(100)` vazio | O id do plano no gateway, preenchido na primeira criação |
| `link_checkout` | `URLField(500)` vazio | O link de checkout hospedado pelo gateway. Reaproveitado pela web e pelo app |

**O plano padrão nasce sozinho.** `OnboardingService` cria a `Assinatura` de
trial com `plano_padrao()` (`billing/services.py`), que cria o plano de
`PLANO_PADRAO` (`pro` por padrão) na primeira vez, com o preço de
`PRECO_INICIAL_PLANO`. Banco novo não precisa de seed para o cadastro funcionar
— antes, sem o plano, o tenant nascia sem assinatura e a API inteira respondia 402.

Em desenvolvimento, `python manage.py popular_dev` faz tudo de uma vez: garante
o plano padrão e cria uma empresa de exemplo com o dono e o onboarding concluído
(`dono@demo.com` / `SenhaForte123!`). `--nicho lava_rapido` ou `banho_tosa`
cria a empresa no modo kanban, com as etapas padrão (`dono.lava@demo.com` /
`dono.pet@demo.com`). Só roda com `DEBUG=True`.

### `Assinatura` — o vínculo do negócio com a plataforma

| Coluna | Tipo | O que é |
|---|---|---|
| `tenant` | `OneToOne → tenants.Tenant` `CASCADE` | Um negócio, uma assinatura |
| `plano` | `FK → Plano` `PROTECT` | |
| `status` | `CharField(20)` = `trial` | `ativa`, `cancelada`, `inadimplente`, `trial` |
| `inicio` | `DateField` | |
| `proximo_vencimento` | `DateField` | Usado para decidir até quando uma assinatura cancelada ainda vale |
| `trial_fim` | `DateField` nulo | Fim do período de teste |
| `gateway` | `CharField(20)` = `mercadopago` | |
| `id_externo` | `CharField(100)` nulo | O id da recorrência no gateway (no Mercado Pago, o preapproval). Único junto com `gateway`. É por ele que o webhook encontra a assinatura |

**Não há coluna `bloqueada`** — é propriedade calculada a partir de `status` e
das datas, e o resultado é memorizado em cache por 60s.

### `PagamentoAssinatura` — o histórico de cobranças

| Coluna | Tipo | O que é |
|---|---|---|
| `assinatura` | `FK → Assinatura` `CASCADE` | |
| `valor` | `Decimal(8,2)` | |
| `status` | `CharField(20)` = `pendente` | `pago`, `pendente`, `falhou` |
| `data` | `DateField` | |
| `gateway` | `CharField(20)` = `mercadopago` | |
| `id_externo` | `CharField(100)` nulo | O id do pagamento no gateway. O único com o `gateway` é o que torna o webhook idempotente |

## É app compartilhado, não de tenant

`Assinatura` aponta para `Tenant`, e ambos vivem no schema público. Faz sentido:
a cobrança é da plataforma para o negócio, não um dado de dentro do negócio.

## `bloqueada` é calculado, não guardado

A propriedade decide na hora, a partir de `status` e datas:

| Status | Bloqueia quando |
|---|---|
| `inadimplente` | sempre |
| `trial` | `trial_fim` já passou |
| `cancelada` | `proximo_vencimento` já passou — cancelar não corta o acesso na hora, a pessoa usa o que pagou |
| `ativa` | nunca |

Quem consulta isso é o `AssinaturaBloqueadaMiddleware`, em toda requisição de
API. Como a resposta muda no ritmo de eventos de cobrança e não de requisições,
ela é memorizada por 60s.

## Por que `save()` e `delete()` foram sobrescritos

Para limpar esse cache. A assinatura é salva em vários pontos do fluxo
(confirmação, cancelamento, webhook, retorno do checkout) — invalidar em cada um
deixaria a correção dependendo de ninguém esquecer, e o esquecimento aparece
como **cliente que pagou e continua bloqueado**. No model, o ORM não deixa
driblar.

## O que é fácil errar aqui

- **O webhook valida assinatura HMAC** (`x-signature`) antes de processar. É
  endpoint público: sem essa checagem, qualquer um ativa assinatura. O `ts` da
  assinatura precisa estar a no máximo 10 minutos do relógio
  (`TOLERANCIA_WEBHOOK_SEGUNDOS`, em segundos ou milissegundos), senão uma
  notificação capturada poderia ser reenviada depois. Tem throttle próprio
  (`webhook`), separado do de anônimo.
- **Rotas de billing são isentas do bloqueio**, junto com `/colaboradores/me/` e
  `/empresa/config/` — senão o tenant bloqueado não alcança a tela que resolve.
- **O `back_url` do preapproval é fixado na criação do plano** e aponta para o
  `LINKS_BASE_URL` (`core/links.py`). Por isso o checkout do app mobile retorna pela web, com um
  botão que abre o app de volta.
