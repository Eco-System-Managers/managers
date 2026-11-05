# CLAUDE.md — Work Manage

Monorepo: API Django em `backend/` e app Flutter em `frontend/apps/workmanage/`,
cada um com o próprio `CLAUDE.md`.

## Lançamento nas lojas com assinatura — decisões e onde paramos

Branch `feat/assinatura-lojas`. Estado em 2026-11-05.

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

- **Código:** 3 commits nesta branch, sem push, com os testes passando. A
  compra de verdade não foi testada, porque depende das contas. Como funciona:
  `backend/apps_work/billing/CLAUDE.md` ("Venda nas lojas") e a feature
  `assinatura` no `CLAUDE.md` do app.
- **Apple:** contrato Paid Apps aceito, conta bancária e W-8BEN preenchidos
  (sem tratado: o Brasil não tem com os EUA). Aguardando o status **Ativo**.

### Onde paramos

O sócio estava criando a conta do **Google Play** (pessoal, nome do
desenvolvedor "Work Manage") e tinha chegado ao questionário de experiência.

### Próximos passos, nesta ordem

1. **Google:** o sócio termina a conta (taxa de US$ 25, verificação do
   documento, confirmação pelo app Play Console num celular Android) e, com ela
   aprovada, convida o e-mail do Wilson como administrador.
2. **Apple:** com o contrato Ativo, inscrever no **App Store Small Business
   Program**, que baixa a comissão de 30% para 15%.
3. **RevenueCat:** criar a conta (grátis).
4. **Produtos:** cadastrar os 9 produtos nas lojas e configurar o RevenueCat
   (entitlements, offerings e webhook), pelo roteiro de
   `backend/apps_work/billing/CLAUDE.md`.
5. **Google:** perfil de comerciante do sócio (conta bancária e dados fiscais).
   O endereço dele pode passar a aparecer na página do app.
6. **Migration do billing:** o `gateway` ganhou a opção `revenuecat`, e o
   `makemigrations billing` gera um `AlterField` só das opções, sem mudar o
   banco. Na sessão de 2026-11-05 ficou dito que não precisava: precisa. Quem
   roda é o Wilson.
7. **Servidor:** `REVENUECAT_SECRET_KEY` e `REVENUECAT_WEBHOOK_AUTH` no
   Railway, e o deploy desta branch (o push é do Wilson).
8. **App:** as chaves públicas `REVENUECAT_IOS_KEY` e `REVENUECAT_ANDROID_KEY`.
   Sem elas o app não mostra a venda.
9. **Termos de uso:** revisar o rascunho de `/termos`.
10. **Testes:** o teste fechado do Google (12 testadores, 14 dias) e uma compra
    de teste em cada loja.
11. **Abrir a venda:** `ASSINATURA_ABERTA=True` no Railway, sem atualizar o
    app.
