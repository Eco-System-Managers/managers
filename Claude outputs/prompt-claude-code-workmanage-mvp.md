# Prompt para o Claude Code — app Flutter do Work Manage (MVP)

> Cole o texto abaixo no Claude Code, aberto na raiz do repositório `managers`.
> Antes de colar, preencha os dois campos entre colchetes na seção "Decisões já tomadas".

---

Você vai construir o MVP do aplicativo Flutter do **Work Manage**, o painel que o pequeno negócio (barbearia, salão, lava-rápido, banho e tosa) usa para gerenciar agenda, clientes, serviços e caixa. O app fica em `frontend/apps/workmanage`. O backend Django já está pronto e é a fonte de verdade: você não inventa endpoint, campo ou regra de negócio; tudo vem do contrato OpenAPI.

## 1. Leia antes de escrever qualquer código

Nesta ordem, e sem pular:

1. `frontend/apps/workmanage/CLAUDE.md` — regras de commit, validação com `validatorless` e Clean Architecture. Elas valem para todo o trabalho.
2. `backend/openapi/README.md` — autenticação, paginação, formato de erro, dinheiro, datas.
3. `backend/openapi/workmanage.yaml` — o contrato completo dos 76 endpoints. Toda chamada que você escrever deve bater com ele (caminho, método, campos, tipos).
4. `backend/apps_work/CLAUDE.md` e o `CLAUDE.md` de cada app em `backend/apps_work/<app>/` — explicam o domínio: os dois modos de agenda, o objeto vinculado (veículo/pet), papéis, billing.
5. As features já existentes no app: `lib/core/`, `lib/features/auth`, `register`, `onboarding`, `splash` e `lib/routing/app_router.dart`. Elas são o padrão a seguir: mesma estrutura de pastas, mesma nomenclatura, mesmo estilo de provider (`ChangeNotifier` que só chama use cases), mesma injeção com Riverpod em `<feature>_provider.dart`.

Se algo no contrato parecer errado ou faltar, não contorne no front: pare e me pergunte.

## 2. Decisões já tomadas (não reabra)

- **Modo de agenda do lançamento:** `[horario | kanban]`. Construa primeiro as telas desse modo. O outro modo entra na última fase, só depois que tudo do primeiro estiver pronto. O app decide quais telas mostrar lendo `EmpresaConfig.tipo_agenda` (`GET /empresa/config/`), nunca por flag hardcoded.
- **Nicho de referência para testar e para os textos de exemplo:** `[barbearia | lava_rapido | ...]`.
- **Plataforma:** app mobile (Android e iOS) com Flutter. Mande `X-Client-Platform: mobile` em toda requisição e trate o refresh token no corpo, como o README da API descreve.
- **Fora do MVP, não construa:** contratos, despesas, notificações no painel, nicho `outro` no onboarding (esconda a opção), qualquer tela do Service Manage.
- **Idioma:** tudo em português do Brasil, incluindo nomes de classes de domínio quando já forem assim no código (`EmpresaConfig`, `HorarioFuncionamento`), comentários e mensagens ao usuário.

## 3. Fundação primeiro (fase 0)

Antes de qualquer tela nova, deixe o `core` capaz de sustentar o app inteiro. Hoje o login e o onboarding são simulados; isso acaba aqui.

- **Sessão.** Crie em `lib/core/session/` o armazenamento seguro de `access` e `refresh` (`flutter_secure_storage`), um `SessionRepository` e um provider que expõe o estado (autenticado / não autenticado). A splash passa a decidir a rota por ele: sem sessão → login; com sessão e `onboarding_concluido == false` → onboarding; caso contrário → home.
- **Dio.** Evolua `lib/core/network/dio_client.dart`: `baseUrl` vinda de `--dart-define=API_BASE_URL` (padrão `http://127.0.0.1:8000/api/v1/` para desenvolvimento); interceptor que injeta `Authorization: Bearer` e `X-Client-Platform: mobile`; interceptor que, num 401 com `code == "nao_autenticado"`, faz **um** `POST auth/token-refresh/`, guarda o novo par e repete a requisição original uma vez; se o refresh falhar, limpa a sessão e volta ao login. Cada refresh vale uma vez, então nunca dispare dois em paralelo (use um lock/futuro compartilhado).
- **Erros.** Em `lib/core/error/`, mapeie o corpo padrão da API (`{detail, code, fields?}`) para `Failure`s: `ServerFailure(detail)` genérico, `ValidationFailure(detail, fields)` para `code == "invalido"`, `AuthFailure` para 401, `PermissionFailure` para 403, `SubscriptionFailure` para 402 / `assinatura_bloqueada`, `NetworkFailure` para falha de rede. **O fluxo da tela é decidido pelo `code`, nunca pelo texto.** A mensagem exibida ao usuário é o `detail` que a API mandou.
- **Tipos.** Dinheiro chega como string `"45.50"`: converta para `Decimal` (pacote `decimal`), nunca `double`. Data `"2026-10-19"`, data-hora ISO 8601 com fuso, hora `"10:30"`. Centralize parse e formatação em `lib/core/utils/`.
- **Paginação.** Helper em `lib/core/network/` que lê `{count, next, previous, results}` e, quando a tela precisa do conjunto inteiro (agenda e kanban do dia), pede `page_size=100` e segue o `next`.
- **Substitua as simulações.** `AuthRepositoryImpl` passa a usar um `AuthRemoteDataSource` real (`auth/login/`, `auth/recuperar-senha/`, `auth/verificar-codigo/`, `auth/nova-senha/`, `auth/logout/`). O `confirm` do cadastro e o login guardam a sessão. O onboarding troca `OnboardingFakeDataSource` pelo `OnboardingRemoteDataSource` apontando para `empresa/config/`, `empresa/horarios/` e `empresa/geocodificar/`. Remova os `TODO` e os `Future.delayed` de simulação.
- **Validators.** Os validators que hoje estão escritos à mão em providers (ex.: regex de e-mail no `LoginProvider`) passam para `Validatorless`, conforme o `CLAUDE.md`.

Só avance para a fase 1 quando: login real funciona, sessão sobrevive a fechar e abrir o app, refresh automático funciona, onboarding grava na API e `flutter analyze` está limpo.

## 4. As telas do MVP (fases 1 a 4)

Para cada feature, a estrutura completa: `domain/entities`, `domain/repositories`, `domain/usecases` (um por ação, método único `call`, retorno `Either<Failure, T>`), `data/models` (com `fromJson`/`toJson`), `data/datasources`, `data/repositories`, `presentation/providers`, `presentation/pages`, `presentation/widgets`, e o `<feature>_provider.dart` com a injeção. Rota nova em `app_router.dart`.

**Fase 1 — Casca e configuração**

- `home`: scaffold com navegação inferior (Agenda, Clientes, Serviços, Caixa, Mais). A aba "Mais" leva a Configurações, Equipe e Assinatura.
- `empresa` (configurações): `GET/PUT empresa/config/`, `POST empresa/config/logo/`, `GET/PUT empresa/horarios/`. Reaproveite os widgets do onboarding. O modo de agenda **não** pode ser alterado depois do onboarding (a API devolve `modo_agenda_bloqueado`); não mostre o campo como editável.
- `servicos`: lista, criar, editar, inativar. `GET/POST servicos/`, `GET/PUT/DELETE servicos/{id}/`. Campos: nome, duração em minutos, preço, taxa de cancelamento (tipo e valor), colaboradores que executam. Só o proprietário escreve: trate `sem_permissao` escondendo os botões para quem não é proprietário (papel vem de `colaboradores/me/`).

**Fase 2 — Clientes**

- `clientes`: lista paginada com busca, ficha, criar, editar. `GET/POST clientes/`, `GET/PUT/DELETE clientes/{id}/`. Nome e telefone obrigatórios (`Validatorless.required`, telefone com máscara BR). Cliente com `origem == "servicemanage"` tem os campos espelhados travados (a API já recusa; o front mostra como somente leitura).
- Se `tipo_agenda == "kanban"`: na ficha do cliente, a lista de objetos (`GET clientes/{id}/objetos/`) e cadastro de veículo (`veiculos/`: placa validada com `validar_placa_br` equivalente, marca, modelo, cor) ou pet (`pets/`: nome, espécie, raça, porte, nascimento), conforme `EmpresaConfig.tipo_objeto`. Nunca mostre os dois ao mesmo tempo.

**Fase 3 — Operação do modo escolhido**

Se o modo for `horario`:

- `agenda`: visão do dia com os agendamentos por colaborador, navegação por data, marcadores dos dias com registro (`GET agenda/dias-com-registro/`). Criar agendamento: cliente, um ou mais serviços, colaborador, data e horário escolhidos a partir de `GET agenda/slots/`. Detalhe: alterar status, remarcar, cancelar (`PUT/PATCH/DELETE agendamentos/{id}/`), cobrar (`POST agendamentos/{id}/cobrar/`, forma de pagamento e desconto). Pendências de cobrança (`GET agenda/pendencias/`) como atalho na tela.

Se o modo for `kanban`:

- `kanban`: quadro com as etapas (`GET kanban/etapas/`), cards por atendimento (`GET kanban/atendimentos/` com `page_size=100` e seguindo `next`), mover entre etapas (`POST kanban/atendimentos/{id}/mover/`), marcar e desfazer falta, cobrar e desfazer cobrança. Criar atendimento: cliente → objeto do cliente → serviço → data/horário opcional (`GET kanban/slots/`). O status que o cliente vê é derivado da coluna, então a ordem das etapas importa: proprietário pode criar, renomear e reordenar (`kanban/etapas/`, `kanban/etapas/reordenar/`).

Em ambos:

- `financeiro`: caixa do dia (`GET financeiro/caixa/`) com total por forma de pagamento e lista do que foi cobrado; saldo do cliente (`GET financeiro/clientes/{id}/saldo/`) na ficha. Despesas ficam fora.
- `dashboard`: `GET dashboard/resumo/` — faturamento do mês e variação, atendimentos do mês, ticket médio, próximos do dia. Leia `tipo_agenda` da resposta para rotular corretamente.

**Fase 4 — Equipe e assinatura**

- `usuarios` (equipe): lista de colaboradores, ativar/desativar, remover (`colaboradores/*`), convites por e-mail (`convites/`, `convites/{id}/`) e aceite por link (`convites/aceitar/{token}/`, `convites/info/{token}/`) — o aceite abre uma tela pública, sem sessão. Só o proprietário gerencia. Se o nicho escolhido for mono-profissional, esta feature pode ficar por último.
- `billing` (assinatura): `GET billing/assinatura/` mostra plano, status (`trial`, `ativa`, `inadimplente`, `cancelada`) e dias restantes; `POST billing/assinatura/iniciar/` devolve o link de checkout do Mercado Pago, abra em `url_launcher` e, no retorno, chame `POST billing/assinatura/confirmar/`; `GET billing/pagamentos/` lista o histórico; cancelar com confirmação. Quando qualquer chamada devolver 402 / `assinatura_bloqueada`, o app leva para esta tela com a mensagem da API.

**Fase 5 — O segundo modo de agenda** (só depois de tudo acima): a tela de operação do outro modo, seguindo o mesmo padrão.

## 5. Regras que valem para todas as telas

- `presentation` → `domain` ← `data`. Page só fala com o seu provider; provider só chama use cases; regra de negócio não existe no front, ela está na API.
- Toda tela tem três estados visíveis: carregando (`WorkManageLoader` já existe em `core/widgets`), vazio (texto curto e ação para criar o primeiro item) e erro (o `detail` da API e botão de tentar de novo).
- Erro de validação (`fields`) vai para o campo correspondente do formulário, não para um snackbar genérico.
- Formulários usam `Form` + `Validatorless` em todo `validator`; máscara de telefone, CPF/CNPJ, CEP e placa com o `MascaraFormatter` que já existe no onboarding ou extensão dele.
- Nunca faça `.update()`-style: depois de criar ou editar, recarregue a lista a partir da API em vez de confiar no estado local.
- Tema: use `lib/core/theme/theme.dart` e `google_fonts` já configurados. Sem cores soltas no código.
- Nada de pacote novo sem necessidade real. Os que você precisa adicionar: `flutter_secure_storage`, `decimal`, `url_launcher`, `intl`. Se achar que precisa de outro, justifique antes.
- Teste de provider para cada feature (use case mockado, verifica estados loading/sucesso/erro) e teste de datasource com `dio` mockado para pelo menos um endpoint por feature. `flutter analyze` sem warnings e `flutter test` verde antes de cada commit.

## 6. Como trabalhar

- Uma fase por vez. Ao terminar cada fase, me mostre o que foi feito e aguarde antes de seguir.
- Commits pequenos, Conventional Commits em português no imperativo (`feat(agenda): adiciona criação de agendamento`), um por mudança, sem corpo, sem qualquer referência a Claude ou Anthropic. Proponha a mensagem e os arquivos no chat e só faça o commit depois da minha aprovação. Nunca faça push.
- Se um endpoint do `workmanage.yaml` não se comportar como o schema diz, não remende no front: me avise com o caminho, o payload e a resposta.
- Antes de começar a fase 0, me mande um plano curto: a lista de arquivos que vai criar no `core`, os pacotes que vai adicionar e as dúvidas que tiver sobre o contrato.
