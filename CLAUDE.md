# CLAUDE.md — Work Manage

Monorepo: API Django em `backend/` e app Flutter em `frontend/apps/workmanage/`,
cada um com o próprio `CLAUDE.md`.

## Lançamento nas lojas com assinatura — decisões e onde paramos

Já na `main` e na `dev`, e no ar. Estado em 2026-11-05, à noite.

O `LANCAMENTO.md` (seção 4) ainda fala em Mercado Pago e em iPhone sem compra
no app: vale o que está aqui.

### Como conduzir este assunto

**Uma coisa por vez, em passo a passo.** Em 2026-11-05 a conversa misturou
lojas, impostos, ME, preços e infraestrutura na mesma resposta, e o Wilson
disse que era "muita informação ao mesmo tempo, desorganizado", a ponto de
pensar em desistir do projeto.

- Responder curto: só o próximo passo e a única pergunta que ele precisa
  responder.
- O que pode esperar não entra na resposta. Nada de tabelas, opções e
  cenários empilhados.
- Quem conduz a ordem é o Claude; o Wilson avisa quando um passo termina.
- Passo feito em tela (Apple, Google, RevenueCat): detalhado, campo por campo,
  quando ele pedir.

### Decisões

- **Cobrar desde o lançamento**, com a compra dentro do app pelas lojas (App
  Store e Google Play), unificada pelo **RevenueCat**. O Mercado Pago fica no
  código, desligado. Os testadores atuais ganham **acesso vitalício**.
- **Planos.** A equipe conta colaboradores e parceiros ativos, sem o dono.
  - **Pro:** só o dono.
  - **Business:** até 5 na equipe.
  - **Enterprise:** até 10 (teto pedido pelo Wilson, por segurança).
  - O teste grátis de 28 dias vale como Business, e o vitalício vale como
    Enterprise.
  - Plano menor não desativa ninguém: só impede a equipe de crescer.
- **Preços de lançamento**, de "fundador" (quem assina agora mantém o valor):

  | Plano | Mensal | Semestral | Anual |
  |---|---|---|---|
  | Pro | R$ 39,90 | R$ 219,90 | R$ 399,90 |
  | Business | R$ 69,90 | R$ 389,90 | R$ 699,90 |
  | Enterprise | R$ 119,90 | R$ 669,90 | R$ 1.199,90 |

  Mensal e anual são os principais; o semestral é a isca para o anual. A base
  foi o preço dos concorrentes do nicho, já descontados os 15% da loja.
- **Sem CNPJ por enquanto.** MEI não aceita software, e a ME custa de R$ 300 a
  500 por mês sem receita. Abrir a ME dos dois quando o lucro passar de uns
  R$ 2 a 3 mil por mês e transferir o app para ela. Usar a empresa da mãe do
  sócio foi descartado.
- **Titular das lojas e do dinheiro:** o CPF do sócio, que não é CLT.
- **Google Play:** conta **pessoal** do sócio (a de organização exige CNPJ e
  D-U-N-S). Conta pessoal nova exige um teste fechado com **12 testadores por
  14 dias seguidos**: serão os vitalícios. Corre em paralelo com o resto.
- **Apple:** a conta já paga está no nome do Wilson. Lançar nela e, perto da
  renovação, transferir o app para uma conta do sócio (e trocar a chave da App
  Store no RevenueCat).

### O que está feito

- **Código e servidor:** a venda pelas lojas, a migration do billing (`0002`),
  a chave pública do iPhone no app (`Env.revenueCatIos`), o preço por mês na
  moeda da loja e a página `/suporte`, tudo na `main` e na `dev` e no ar. No
  Railway: `REVENUECAT_SECRET_KEY` (a secreta da API **v1**),
  `REVENUECAT_WEBHOOK_AUTH` e **`ASSINATURA_ABERTA=True`** (a venda está
  aberta). Como funciona: `backend/apps_work/billing/CLAUDE.md` ("Venda nas
  lojas") e a feature `assinatura` no `CLAUDE.md` do app.
- **Testadores:** todos com **acesso vitalício** no admin. O APK antigo do
  Android (`1.0.0+2`), com a venda aberta, mostra o item Assinatura do Mercado
  Pago (o botão dá erro, nada cobra); o APK novo esconde, porque ainda não tem
  a chave do Android.
- **Apple:** contrato Paid Apps **ativo**. Pedido de inscrição no **Small
  Business Program** enviado (comissão de 15%), esperando o e-mail.
  - **Produtos:** um grupo de assinaturas, "Work Manage", com os 9 planos.
    IDs `pro_mensal`, `pro_semestral`, `pro_anual`, `business_*` e
    `enterprise_*` (os mesmos períodos); preço-base no Brasil, os da tabela
    acima. Níveis do grupo: Enterprise 1, Business 2, Pro 3, cada um com os
    três períodos no mesmo nível. Compra por empresa (Apple Business,
    multiseat) não combina com a assinatura do negócio.
  - **Avisos da Apple** (App Store Server Notifications, versão 2) para o
    RevenueCat, em produção e sandbox. A chave de compra (`.p8`, In-App
    Purchase) fica com o Wilson, fora do repositório.
- **RevenueCat** (conta do Wilson): projeto Work Manage com o app **Work
  Manage iOS** (`br.com.workmanage.app`); entitlements `pro`, `business` e
  `enterprise`, cada um com os três produtos dele; offerings com os mesmos
  nomes e os pacotes Monthly, Six Month e Annual; webhook em
  `https://api.workmanage.com.br/api/v1/billing/webhook/revenuecat/`, em
  produção e sandbox.
- **Compra testada** no TestFlight: a loja cobra, o app libera na hora
  (`sincronizar/`) e o webhook grava a cobrança. No TestFlight o mês dura um
  dia, e as renovações de teste param sozinhas depois de alguns dias.
- **Revisão da Apple enviada** em 2026-11-05: a versão 1.0 (build
  `1.0.0+4`), os 9 planos e o grupo, com **liberação manual**. O negócio da
  conta do revisor está em **Trial até 31/12/2027**, e não vitalício, porque
  o vitalício não mostra os planos e o revisor precisa comprar um. Textos,
  prints e respostas da página: `TEXTOS_DA_LOJA.md`.
- **Google:** a conta do Renan está criada e o status de comerciante foi
  declarado (União Europeia), com o `contato@workmanage.com.br`.

### Onde paramos

A Apple está revisando. A conta do Google espera a verificação da identidade
do Renan, para depois verificar o telefone.

### Próximos passos

1. **Apple respondeu:** se aprovou, vocês escolhem o dia e publicam (a
   liberação é manual). Se reprovou, a mensagem diz o motivo. Enquanto a
   revisão corre, a conta do revisor e o `ASSINATURA_ABERTA` não mudam.
2. **Small Business Program aprovado:** no RevenueCat, no app Work Manage
   iOS, ligar a opção do programa com a data da aprovação (só muda os
   relatórios).
3. **Google**, quando a verificação sair, em ordem:
   1. o Renan verifica o telefone e convida o e-mail do Wilson como
      administrador;
   2. o app no Play Console e o primeiro build (AAB) num teste fechado, porque
      o Google só deixa criar assinatura depois de um build;
   3. as assinaturas `pro`, `business` e `enterprise`, cada uma com os planos
      básicos mensal, semestral e anual, e o perfil de comerciante do Renan
      (conta bancária e dados fiscais);
   4. no RevenueCat, o app Android (com a conta de serviço do Google) e os
      produtos do Google nos pacotes que já existem; os entitlements, as
      offerings e o webhook servem às duas lojas;
   5. a chave pública do Android (`goog_...`) no `defaultValue` de
      `REVENUECAT_ANDROID_KEY`, num build novo;
   6. o teste fechado com 12 testadores por 14 dias seguidos, e uma compra de
      teste.
4. **Testadores do Android:** um APK novo (o atual é o `1.0.0+2`).
5. **Termos de uso:** revisar o rascunho de `/termos`.
