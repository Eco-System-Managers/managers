# Lançamento para testadores — Android e iPhone

O roteiro para pôr o Work Manage na mão dos primeiros testadores. Estado em
2026-10-29: o código está pronto para os dois e o servidor está no ar; a
chave do Android já está no Mac; a conta Apple Developer está em análise
(pending). Falta gerar os aplicativos e testar nos aparelhos.

A ordem importa: **o servidor vem primeiro**. O app novo fala com rotas que
só existem depois do deploy (excluir conta, política de privacidade, bloqueios
da agenda), e o APK aponta para a produção.

## O que o código já cobre

- Agenda: regras do cliente (15 min, 30 min de antecedência, até 30 dias),
  conflito conferido no servidor e bloqueios.
- Assinatura fechada na fase de testes (`ASSINATURA_ABERTA=False`): o servidor
  recusa o checkout e o app não fala de assinatura, igual no Android e no
  iPhone (sem item no Mais, sem plano, cobranças nem "Em breve"). Bloqueado,
  ninguém fica preso: a tela "Acesso" tem o aviso neutro, **Sair** e
  **Excluir conta**.
- O que as lojas exigem: excluir a conta pelo app (Mais › Excluir conta, com
  30 dias para desistir), política de privacidade pública (`/privacidade`,
  link em Mais), identificador `br.com.workmanage.app` nos dois, declaração de
  criptografia no iOS e ícones sem transparência.
- Android: release assinado com a chave própria (`android/key.properties`,
  fora do git).

## 1. Servidor (Railway) — antes de qualquer teste

O checklist completo está em `backend/DEPLOY.md` ("Para lançar"). Para os
testes, o mínimo é:

- [x] **Push da `main` e deploy** (2026-10-29). O pre-deploy roda as migrations novas
  (`agenda.0003_bloqueio` e `autenticacao_work.0003_exclusao_conta`).
- [x] **Variáveis:** `PRIVACIDADE_RESPONSAVEL` (Wilson Geraldo Donizeti
  Pereira Júnior) e `PRIVACIDADE_EMAIL` (`contato@workmanage.com.br`).
  `ASSINATURA_ABERTA` fica sem definir (é `False`).
- [x] **Conferir** `https://api.workmanage.com.br/privacidade`: o nome e o
  e-mail aparecem.
- [x] **E-mail do cadastro (Resend):** um cadastro de teste recebe o código.
  Sem isso, ninguém consegue se cadastrar.
- [x] **Cron diário da exclusão de contas** (serviço `cron-exclusao`, todo
  dia às 6h de Brasília; testado com `0 conta(s) excluída(s)`). Passo a passo
  em `backend/DEPLOY.md`, "O cron da exclusão de contas".
- Não precisa para os testes: Mercado Pago (a assinatura está fechada) e S3
  (sem ele, só o envio da logo falha; peça aos testadores para não enviar).
- Os negócios novos nascem em período de teste. Se ele acabar antes do fim
  dos testes, marque o testador como acesso vitalício no admin.

## 2. Android (APK)

1. **Backup da chave**, antes de tudo: o `workmanage-upload.jks` e o
   `frontend/apps/workmanage/android/key.properties` (tem a senha), juntos,
   num lugar seguro fora dos computadores. Sem eles nenhuma atualização
   instala por cima, e a Play Store não aceita a mesma app depois.
2. **Onde a chave fica:** o `.jks` fora do repositório (Windows:
   `C:\Users\Melina\keystores\`; Mac: `~/keystores/`) e o `key.properties`
   sempre em `frontend/apps/workmanage/android/`, com o `storeFile` no
   **caminho completo** da máquina (no Mac,
   `/Users/wilsonjunior/keystores/workmanage-upload.jks`; caminho relativo
   é lido a partir de `android/app/`, e `~` não vale). Os dois estão no
   `.gitignore`.
3. **Gerar numa máquina com o `key.properties`:**
   ```
   cd frontend/apps/workmanage
   flutter build apk --release
   ```
   Sem `--dart-define`: o padrão já é a API de produção. O arquivo sai em
   `build/app/outputs/flutter-apk/app-release.apk`.

   **Cuidado:** sem o `key.properties` o build **não falha**: o Gradle só
   avisa no meio do log ("key.properties não encontrado") e assina com a
   chave de debug da máquina. O APK instala num celular limpo, mas não
   atualiza por cima de um com a chave verdadeira (nem o contrário), muda de
   máquina para máquina e a Play Store não aceita. Para conferir a
   assinatura:
   ```
   ~/Library/Android/sdk/build-tools/<versão>/apksigner verify --print-certs \
     build/app/outputs/flutter-apk/app-release.apk
   ```
   Se aparecer `CN=Android Debug`, não distribuir.
4. **Testar você mesmo num celular, contra a produção:** cadastro e código
   por e-mail, onboarding, serviço, cliente, agendamento, bloqueio, cobrança,
   caixa, política de privacidade e excluir conta (numa conta de teste).
   Performance só vale no release: o `flutter run` comum é debug e é mais lento.
5. **Distribuir:** mandar o `.apk` por WhatsApp ou Drive. O testador libera
   "instalar apps desconhecidos"; se o Play Protect avisar "app não
   verificado", é "Instalar mesmo assim".
6. **Roteiro e canal de feedback:** uma lista curta do que testar e um grupo
   para os problemas ("manda print e o que fez antes").
7. **Atualizações:** subir o `+N` (ver "Números de versão") e gerar de novo,
   com a mesma chave. Instala por cima.

## 3. iPhone (TestFlight)

O app nunca foi compilado para iOS: a primeira compilação no Mac pode pedir
algum ajuste (versão mínima de um pacote, CocoaPods). O projeto já tem o
bundle `br.com.workmanage.app`, iOS mínimo 15, os textos de permissão
(câmera e fotos) e a criptografia declarada; o `Podfile` o Flutter cria no
primeiro build.

1. **Conta Apple Developer** (US$ 99/ano; pessoa física serve e sai em 1–2
   dias): developer.apple.com/programs/enroll, com um Apple ID com verificação
   em duas etapas. *Em análise desde 2026-10-29.*
2. **Preparar o Mac** (já tem Xcode 27, CocoaPods e Flutter 3.47.4, a mesma
   versão do Windows): `sudo xcodebuild -license accept`; em Xcode › Settings ›
   **Components**, baixar o **iOS 27.0** (sem ele o Xcode recusa compilar para
   iOS, e ele traz o simulador); `flutter doctor --android-licenses` para o
   doctor ficar limpo; no projeto, `flutter pub get` e `flutter doctor` com ✓
   no Xcode. No Xcode, Settings › Accounts com o Apple ID da conta.
3. **iPhone pronto para desenvolvimento:** no cabo e desbloqueado, "Confiar"
   no Mac, abrir o Xcode › Window › Devices and Simulators e esperar preparar o
   aparelho; depois, no iPhone, Ajustes › Privacidade e Segurança › **Modo
   Desenvolvedor** (só aparece depois do Xcode) e reiniciar.
4. **Enquanto a conta não sai:**
   - **Simulador**, sem conta nenhuma: `open -a Simulator` e `flutter run`.
     Mostra o app inteiro em iOS contra a produção; é debug (performance não
     vale) e não tem câmera.
   - **No próprio iPhone com o Apple ID grátis** (Personal Team): o app
     expira em 7 dias e só vale nos aparelhos ligados ao Mac. **Nunca com o
     bundle de verdade:** a equipe grátis pode prender o
     `br.com.workmanage.app` e a conta paga não consegue mais registrá-lo
     ("App ID not available"). Para isso, trocar só na máquina para
     `br.com.workmanage.app.dev`, sem comitar.
5. **Registrar o identificador** (com a conta aprovada): developer.apple.com ›
   Certificates, IDs & Profiles › Identifiers › + › App IDs, bundle
   **`br.com.workmanage.app`**, descrição "Work Manage", sem capabilities.
6. **Cadastrar o app no App Store Connect** (appstoreconnect.apple.com ›
   Apps › + › Novo app): plataforma iOS, nome (único na loja; se "Work Manage"
   estiver ocupado, algo como "Work Manage Agenda"), idioma português (Brasil),
   ID do pacote `br.com.workmanage.app`, SKU `workmanage-ios`.
7. **Assinatura no Xcode** (uma vez): abrir
   `frontend/apps/workmanage/ios/Runner.xcworkspace`, alvo Runner › Signing &
   Capabilities (aba *All*) › Automatically manage signing e escolher o Team.
   Se o Team pago não aparecer, sair e entrar de novo com o Apple ID em
   Xcode › Settings › Accounts: a conta aprovada nem sempre aparece sozinha.
8. **Primeiro teste no aparelho, em release:** iPhone no cabo e
   `flutter run --release`. Os ajustes da primeira compilação aparecem aqui,
   e não no envio.
9. **Gerar e enviar:**
   ```
   cd frontend/apps/workmanage
   flutter build ipa --release
   ```
   Arrastar o `.ipa` de `build/ios/ipa/` para o app **Transporter** (Mac App
   Store, grátis) e entregar. Em 10–30 min aparece em App Store Connect ›
   TestFlight; a pergunta de criptografia não vem, já está declarada. Cada
   envio precisa de um `+N` novo (ver "Números de versão").
10. **Testar como interno** (até 100 pessoas, que precisam estar em Usuários e
    Acesso no App Store Connect; sem revisão da Apple): TestFlight › Testes
    internos, criar o grupo e adicionar a versão.
11. **Testadores externos** (até 10.000, com a revisão do beta, de horas a 1
    dia):
    - Informações de teste: descrição do beta, e-mail de feedback e o link
      `https://api.workmanage.com.br/privacidade`.
    - Revisão do beta: contato e uma **conta de teste** que funcione na
      produção (negócio preenchido, serviços e clientes cadastrados, em
      período de teste ou vitalícia, para não cair no bloqueio), com usuário e
      senha para o revisor.
    - Criar o grupo externo, adicionar a versão, enviar para revisão e, depois
      de aprovado, ligar o **link público**.
12. **O testador:** instala o app TestFlight, abre o link e instala. Cada
    versão vale 90 dias.

O que a revisão olha e como estamos: abre sem travar (testar antes); login
com a conta de teste e servidor no ar; permissões explicadas (câmera e fotos,
ok); política de privacidade (ok, depois do deploy); excluir conta pelo app
(ok); nenhuma compra com pagamento de fora (ok); criptografia declarada (ok).

## Números de versão

O `version` do `pubspec.yaml` (`1.0.0+1`) tem o **nome** (`1.0.0`, o que
aparece na loja e nos ajustes) e o **número do build** (`+1`, o que o
sistema e as lojas comparam). O Flutter leva os dois para as plataformas:
`versionName`/`versionCode` no Android, `CFBundleShortVersionString`/
`CFBundleVersion` no iPhone.

- **Quando mudar:** só quando o build vai para outras pessoas ou para a Apple.
  Os primeiros APK e `.ipa` saem como `1.0.0+1`; o build que fica no seu
  celular para testar não muda nada.
- **Android:** o celular recusa um número menor por cima do instalado
  (downgrade); a cada APK novo para os testadores, `+1` → `+2` → `+3`.
- **iPhone:** o App Store Connect recusa um número já enviado na mesma
  versão, mesmo que ninguém tenha recebido aquele build: reenviar é sempre
  com um número novo. Builds da mesma `1.0.0` ficam juntos no TestFlight e
  passam rápido na revisão externa; um nome novo (`1.0.1`) pede a revisão
  completa do beta de novo.
- **Nos testes:** o nome fica em `1.0.0` e só o `+N` sobe, o **mesmo número
  nas duas plataformas** ("estou na 1.0.0 (3)" diz qual código é). Subir
  antes de gerar e comitar junto (`chore: sobe a versão para 1.0.0+2`). O
  `+N` nunca volta.

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
