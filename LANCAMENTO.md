# Lançamento para testadores — Android e iPhone

O roteiro para pôr o Work Manage na mão dos primeiros testadores. Estado em
2026-10-29: o código está pronto para os dois; o que falta é publicar o
servidor, gerar os aplicativos e testar nos aparelhos.

A ordem importa: **o servidor vem primeiro**. O app novo fala com rotas que
só existem depois do deploy (excluir conta, política de privacidade, bloqueios
da agenda), e o APK aponta para a produção.

## O que o código já cobre

- Agenda: regras do cliente (15 min, 30 min de antecedência, até 30 dias),
  conflito conferido no servidor e bloqueios.
- Assinatura fechada na fase de testes (`ASSINATURA_ABERTA=False`): o servidor
  recusa o checkout; o Android mostra "Em breve"; o iPhone não mostra compra
  nenhuma. Bloqueado, ninguém fica preso: a tela de assinatura tem **Sair** e
  **Excluir conta**, com aviso neutro.
- O que as lojas exigem: excluir a conta pelo app (Mais › Excluir conta, com
  30 dias para desistir), política de privacidade pública (`/privacidade`,
  link em Mais), identificador `br.com.workmanage.app` nos dois, declaração de
  criptografia no iOS e ícones sem transparência.
- Android: release assinado com a chave própria (`android/key.properties`,
  fora do git).

## 1. Servidor (Railway) — antes de qualquer teste

O checklist completo está em `backend/DEPLOY.md` ("Para lançar"). Para os
testes, o mínimo é:

- [ ] **Push da `main` e deploy.** O pre-deploy roda as migrations novas
  (`agenda.0003_bloqueio` e `autenticacao_work.0003_exclusao_conta`).
- [ ] **Variáveis:** `PRIVACIDADE_RESPONSAVEL` (Wilson Geraldo Donizeti
  Pereira Júnior) e `PRIVACIDADE_EMAIL` (`contato@workmanage.com.br`).
  `ASSINATURA_ABERTA` fica sem definir (é `False`).
- [ ] **Conferir** `https://api.workmanage.com.br/privacidade`: o nome e o
  e-mail aparecem.
- [ ] **E-mail do cadastro (Resend):** um cadastro de teste recebe o código.
  Sem isso, ninguém consegue se cadastrar.
- [ ] **Cron diário da exclusão de contas** — passo a passo em
  `backend/DEPLOY.md`, "O cron da exclusão de contas". Só depois do deploy.
- Não precisa para os testes: Mercado Pago (a assinatura está fechada) e S3
  (sem ele, só o envio da logo falha; peça aos testadores para não enviar).
- Os negócios novos nascem em período de teste. Se ele acabar antes do fim
  dos testes, marque o testador como acesso vitalício no admin.

## 2. Android (APK)

1. **Backup da chave**, antes de tudo: `C:\Users\Melina\keystores\workmanage-upload.jks`
   e `frontend/apps/workmanage/android/key.properties` (tem a senha). Num
   lugar seguro, fora deste computador. Sem eles nenhuma atualização instala
   por cima, e a Play Store não aceita a mesma app depois.
2. **Gerar numa máquina com o `key.properties`** (sem ele o Gradle avisa e
   assina com a chave de debug, que não serve):
   ```
   cd frontend/apps/workmanage
   flutter build apk --release
   ```
   Sem `--dart-define`: o padrão já é a API de produção. O arquivo sai em
   `build/app/outputs/flutter-apk/app-release.apk`.
3. **Testar você mesmo num celular, contra a produção:** cadastro e código
   por e-mail, onboarding, serviço, cliente, agendamento, bloqueio, cobrança,
   caixa, política de privacidade e excluir conta (numa conta de teste).
   Performance só vale no release: o `flutter run` comum é debug e é mais lento.
4. **Distribuir:** mandar o `.apk` por WhatsApp ou Drive. O testador libera
   "instalar apps desconhecidos"; se o Play Protect avisar "app não
   verificado", é "Instalar mesmo assim".
5. **Roteiro e canal de feedback:** uma lista curta do que testar e um grupo
   para os problemas ("manda print e o que fez antes").
6. **Atualizações:** subir o `+N` do `version` no `pubspec.yaml` (`1.0.0+1`
   → `1.0.0+2`) e gerar de novo, com a mesma chave. Instala por cima.

## 3. iPhone (TestFlight)

O app nunca foi compilado para iOS: a primeira compilação no Mac pode pedir
algum ajuste (versão mínima de um pacote, CocoaPods).

1. **Conta Apple Developer** (US$ 99/ano; pessoa física serve e sai em 1–2
   dias): developer.apple.com/programs/enroll, com um Apple ID com verificação
   em duas etapas.
2. **Preparar o Mac:** Xcode pela App Store (abrir uma vez e baixar a
   plataforma iOS), `sudo xcodebuild -license accept`, Homebrew e
   `brew install cocoapods`, Flutter na **mesma versão** do Windows. No
   projeto: `flutter pub get` e `flutter doctor` com ✓ no Xcode. No Xcode,
   Settings › Accounts com o Apple ID da conta.
3. **Cadastrar o app no App Store Connect** (appstoreconnect.apple.com ›
   Apps › + › Novo app): plataforma iOS, nome (único na loja; se "Work Manage"
   estiver ocupado, algo como "Work Manage Agenda"), idioma português (Brasil),
   ID do pacote **`br.com.workmanage.app`** (registrar antes em
   developer.apple.com › Identifiers, se não aparecer), SKU `workmanage-ios`.
4. **Assinatura no Xcode** (uma vez): abrir
   `frontend/apps/workmanage/ios/Runner.xcworkspace`, alvo Runner › Signing &
   Capabilities › Automatically manage signing e escolher o Team.
5. **Gerar e enviar:**
   ```
   cd frontend/apps/workmanage
   flutter build ipa --release
   ```
   Arrastar o `.ipa` de `build/ios/ipa/` para o app **Transporter** e
   entregar. Em 10–30 min aparece em App Store Connect › TestFlight. Cada envio
   precisa de um `+N` novo no `pubspec.yaml`.
6. **Testar como interno** (até 100 pessoas da equipe no App Store Connect,
   sem revisão da Apple): TestFlight › Testes internos, criar o grupo e
   adicionar a versão.
7. **Testadores externos** (até 10.000, com a revisão do beta, de horas a 1
   dia):
   - Informações de teste: descrição do beta, e-mail de feedback e o link
     `https://api.workmanage.com.br/privacidade`.
   - Revisão do beta: contato e uma **conta de teste** que funcione na
     produção (negócio preenchido, serviços cadastrados, em período de teste
     ou vitalícia), com usuário e senha para o revisor.
   - Criar o grupo externo, adicionar a versão, enviar para revisão e, depois
     de aprovado, ligar o **link público**.
8. **O testador:** instala o app TestFlight, abre o link e instala. Cada
   versão vale 90 dias.

O que a revisão olha e como estamos: abre sem travar (testar antes); login
com a conta de teste e servidor no ar; permissões explicadas (câmera e fotos,
ok); política de privacidade (ok, depois do deploy); excluir conta pelo app
(ok); nenhuma compra com pagamento de fora (ok); criptografia declarada (ok).

## 4. Antes de liberar a assinatura (depois dos testes)

- Mercado Pago em produção: credenciais, webhook, `MERCADOPAGO_BACK_URL` e
  `configurar_plano --preco X` (ver `backend/DEPLOY.md`).
- `ASSINATURA_ABERTA=True` no Railway. O Android libera o "Assinar" sozinho,
  sem atualizar o app.
- iPhone: continua sem compra no app (a Apple exige a compra pela própria
  Apple, com 15–30%, para vender lá dentro). Para o dono que só tem iPhone,
  falta uma **página de assinatura no site**, que o app não pode citar nem
  linkar.

## 5. Pendências técnicas

- A suíte completa do backend não terminou nesta máquina (parou por falta de
  memória); as partes alteradas passaram. Rodar de novo antes do deploy:
  `cd backend && .venv\Scripts\python.exe -m pytest` (com `SECRET_KEY` e
  `DEBUG=True` no ambiente ou num `backend/.env`).
- Nada foi testado ainda num aparelho em modo release.
