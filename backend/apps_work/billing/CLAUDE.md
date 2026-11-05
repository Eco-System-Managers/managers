# apps_work/billing — CLAUDE.md

A **assinatura do negócio** na plataforma, vendida nas lojas (App Store e
Google Play) pelo RevenueCat. O Mercado Pago continua no código, desligado.

Cuidado para não confundir com o `financeiro`: aquele é o dinheiro entre o
negócio e os clientes dele. Este é o dinheiro entre o negócio e **nós**.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `models.py` | `Plano`, `Assinatura` (com `bloqueada`, `vitalicia`, `plano_vigente` e `limite_da_equipe`), `PagamentoAssinatura` e `LIMITE_DA_EQUIPE` |
| `revenuecat.py` | A compra nas lojas: `sincronizar(tenant)` lê no RevenueCat o que o negócio comprou e acerta a `Assinatura`; `processar_webhook` valida o segredo e sincroniza os negócios do evento |
| `services.py` | `GatewayPagamento` e `MercadoPagoGateway` (o checkout antigo), `plano_do_tipo`/`plano_do_trial`, e o acesso vitalício |
| `views.py` | Assinatura atual, `sincronizar/`, histórico paginado, os webhooks, e o iniciar/confirmar/cancelar do Mercado Pago (fechados com a venda nas lojas) |
| `serializers.py` | Representação |
| `admin.py` | Plano, assinatura e pagamentos no `/admin/`, com as ações de acesso vitalício |

## Planos e limite da equipe

| Plano | Equipe (sem o dono) |
|---|---|
| `pro` | 0: só o dono |
| `business` | até 5 |
| `enterprise` | até 10 |

Conta quem está **ativo** na equipe, colaborador ou parceiro, com ou sem login
(`ColaboradorService.equipe_ativa`). O limite está em `LIMITE_DA_EQUIPE`, no
código, e não no `Plano.limite_colaboradores` do banco (que não é lido).

`Assinatura.plano_vigente` é o plano que vale para as regras: **o teste grátis
é sempre Business** (é com ele que o negócio nasce, `plano_do_trial`) e **o
vitalício é sempre Enterprise**, seja qual for o plano gravado.

A trava (`ColaboradorService.garantir_vaga`, 400 `limite_da_equipe`) vale ao
cadastrar, reativar, convidar sem cadastro e aceitar o convite. **Ninguém é
desativado sozinho** quando o plano diminui: a equipe que passou do limite só
não cresce até caber de novo.

A assinatura (`billing/assinatura/`) traz `plano`, `plano_nome`, `vitalicia`,
`limite_equipe` e `equipe_ativa`: o app mostra só os planos que comportam a
equipe.

## Venda nas lojas (RevenueCat)

Quem cobra é a loja; o RevenueCat confere as compras das duas e avisa. O
negócio é o cliente: o app entra no RevenueCat com o `schema_name` do tenant
como `appUserID`, e a compra vale em qualquer aparelho logado no negócio.

- **O estado nunca vem do corpo do webhook.** Ele só diz quem mudou; a verdade
  é lida na API do RevenueCat (`GET /v1/subscribers/{schema}`). Evento
  repetido, fora de ordem ou perdido não deixa a assinatura errada.
- **`sincronizar/`** (POST, do proprietário) é a mesma leitura, chamada pelo
  app logo depois de comprar ou restaurar: o acesso libera sem esperar o
  webhook. Loja fora do ar é 503 `loja_indisponivel`; no webhook, o 503 faz o
  RevenueCat reenviar.
- **O mapeamento:** o maior entitlement vigente (`pro` < `business` <
  `enterprise`, contando a carência de cobrança) vira o plano, com
  `proximo_vencimento` no fim dele. Cancelado na loja (`unsubscribe_detected_at`)
  é `cancelada`, que vale até o fim do período pago. Nenhum vigente com compra
  antiga é `cancelada` vencida (bloqueia), a não ser que o teste grátis ainda
  não tenha acabado. Sem compra nenhuma, nada muda. O vitalício nunca é tocado.
- **Cobranças:** `INITIAL_PURCHASE`, `RENEWAL` e `NON_RENEWING_PURCHASE` (fora
  do período de teste da loja) entram em `PagamentoAssinatura`, únicas pelo
  `transaction_id`.
- **Compra de teste (sandbox) vale.** O revisor da Apple compra em sandbox
  contra a produção; recusar faria o app ser reprovado. O efeito colateral é
  que testador do TestFlight assina de graça.

**Configuração.** No painel do RevenueCat:
1. Os entitlements `pro`, `business` e `enterprise`.
2. As offerings `pro`, `business` e `enterprise`, cada uma com os pacotes
   **Monthly**, **Six Month** e **Annual** ligados aos produtos das lojas (o app
   lê por esses nomes). Na App Store, os 9 produtos num **grupo de assinaturas
   só**, para a troca de plano ser da loja.
3. O webhook em `https://<api>/api/v1/billing/webhook/revenuecat/`, com um
   valor no cabeçalho Authorization.

No servidor: `BILLING_GATEWAY=revenuecat` (o padrão), `REVENUECAT_SECRET_KEY`
(a chave secreta da API v1) e `REVENUECAT_WEBHOOK_AUTH` (o mesmo valor do
cabeçalho, inteiro). No app, as chaves públicas por `--dart-define`
(`REVENUECAT_IOS_KEY`, `REVENUECAT_ANDROID_KEY`).

**O preço está na loja.** `Plano.preco_mensal` é só referência no admin.

## Assinar pelo app fechado (`ASSINATURA_ABERTA`)

Na fase de testes a assinatura sai com `checkout_aberto: false`, e o app não
fala de venda (nem consulta a loja). Ligar é só a variável
`ASSINATURA_ABERTA=True`, sem atualizar o app. O `sincronizar/` não passa por
ela: só lê o que a loja já cobrou.

Com `BILLING_GATEWAY=revenuecat`, o `iniciar/`, o `confirmar/` e o `cancelar/`
do Mercado Pago respondem 403 `assinatura_pela_loja`: um app antigo não abre
uma segunda forma de pagar. Cancelar é na loja do celular.

## Acesso vitalício

`conceder_acesso_vitalicio()` (`services.py`, ou a ação no admin) deixa a
assinatura `ativa`, no plano Enterprise, sem `id_externo` e com vencimento em
`VENCIMENTO_VITALICIO` (31/12/2099) — é essa combinação que
`Assinatura.vitalicia` reconhece. Não há status novo: `ativa` já não bloqueia.
Recusa quem paga recorrência (com `id_externo`): cancele antes na loja, senão
ela continua cobrando. `revogar_acesso_vitalicio()` desfaz. A sincronização
com a loja não mexe no vitalício.

## Mercado Pago (desligado)

O checkout antigo, no navegador, segue no código para uma venda pela web no
futuro: `BILLING_GATEWAY=mercadopago` o religa. O preço vivia em dois lugares —
`Plano.preco_mensal` e o plano no Mercado Pago — e quem acertava os dois era
`python manage.py configurar_plano --preco 69.90`.

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
- **O `back_url` do preapproval é fixado na criação do plano** e aponta para
  `MERCADOPAGO_BACK_URL` + `billing/retorno/` — o domínio da API, com https.
  Esse endpoint repassa a pessoa para `/app/pagamentos` (`core/links.py`), a
  página que manda voltar ao app. Mudar o domínio exige rodar
  `configurar_plano` de novo.
