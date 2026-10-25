# CLAUDE.md

## Commits

- **Sempre siga o Conventional Commits:** `tipo(escopo): descrição`, com a descrição em português e no imperativo (ex.: `feat(auth): adiciona tela de recuperação de senha`).
- **Mensagens curtas e claras:** só a linha do título, sem corpo. Diga o que mudou em poucas palavras (ex.: `refactor(auth): remove register() sem uso`).
- **Um commit por mudança:** mudanças independentes vão em commits separados.
- **Nunca coloque referência ao Claude ou à Anthropic** no commit: nada de `Co-Authored-By`, "Generated with" ou similares.
- **Fluxo de aprovação:** proponha no chat a mensagem e a lista de arquivos, e só faça o commit depois da aprovação.
- **Nunca faça push.** O push é sempre feito pelo desenvolvedor.

## Validação de formulários

- **Sempre use o [`validatorless`](https://pub.dev/packages/validatorless)** no `validator` dos campos (`required`, `email`, `min`, `max`, `number`, `cpf`, `cnpj`, `date`, `compare`, `between`...).
- **Não escreva validador à mão** para algo que o pacote já oferece (ex.: regex de e-mail no lugar de `Validatorless.email`).
- **Vários critérios no mesmo campo:** combine com `Validatorless.multiple([...])`.
- **`Validatorless.regex` só para regras sem equivalente no pacote**, como bloquear um campo preenchido só com espaços.

## Arquitetura (Clean Architecture)

Organização por feature: cada feature tem suas camadas dentro de `lib/features/<feature>/`. O que é compartilhado fica em `lib/core/`.

### Camadas e pastas

- `lib/core/` — compartilhado entre features: tema, widgets comuns, utils (e, quando existir, client HTTP e erros).
- `lib/features/<feature>/domain/entities/` — entidades do negócio, Dart puro, sem `fromJson`.
- `lib/features/<feature>/domain/repositories/` — contratos (classes abstratas) dos repositórios.
- `lib/features/<feature>/domain/usecases/` — um caso de uso por ação (`LoginUseCase`, `SendRecoveryCodeUseCase`), com um único método `call`.
- `lib/features/<feature>/data/models/` — DTOs da API/armazenamento, com `fromJson`/`toJson`.
- `lib/features/<feature>/data/datasources/` — fala com uma fonte (API, storage). Retorna models.
- `lib/features/<feature>/data/repositories/` — implementação dos repositórios: usa datasources e converte model → entidade.
- `lib/features/<feature>/presentation/providers/` — estado da tela (`ChangeNotifier`); chama **apenas** use cases.
- `lib/features/<feature>/presentation/pages/` — as telas.
- `lib/features/<feature>/presentation/widgets/` — widgets usados só por essa feature.
- `lib/features/<feature>/<feature>_provider.dart` — injeção de dependências com Riverpod; único lugar que conhece a implementação do repository.

### Regra de dependência

- `presentation` → `domain` ← `data`. O `domain` não importa Flutter, `data` nem `presentation`.
- Providers de tela nunca usam repositories, datasources ou services diretamente.
- Pages nunca acessam nada além do seu provider de tela.

### Nomenclatura

- Arquivos em `snake_case`, com sufixo da camada: `auth_remote_datasource.dart`, `auth_repository.dart` (contrato), `auth_repository_impl.dart`, `login_use_case.dart`, `login_provider.dart`, `login_page.dart`.

## Core

O que o `lib/core/` oferece a toda feature (fase 0 do MVP):

- `config/env.dart` — `API_BASE_URL` vem de `--dart-define` (padrão `http://127.0.0.1:8000/api/v1/`). Aparelho Android por USB: `adb reverse tcp:8000 tcp:8000` faz o `127.0.0.1:8000` do aparelho chegar na máquina, sem define nem IP (refazer ao reconectar o cabo). Emulador Android: `http://10.0.2.2:8000/api/v1/`; aparelho por Wi-Fi: o IP da máquina, com o `runserver 0.0.0.0:8000`.
- `session/` — `Sessao` (access, refresh, `schema_name`, empresa), `SessaoRepository` (armazenamento seguro) e `SessaoController`, a sessão em memória do app inteiro. Login e cadastro chamam `entrar`; logout e 401 definitivo chamam `sair`. O router usa o controller em `redirect` e `refreshListenable`: tela privada sem sessão volta ao login sozinha.
- `network/` — `dioProvider` (base URL, `X-Client-Platform: mobile`, `AuthInterceptor`) e `paginacao.dart` (`Pagina<T>` e `buscarTudo`, que segue o `next` com `page_size=100`). O interceptor renova em 401 `token_invalido` (uma vez, com o refresh compartilhado entre requisições) e encerra a sessão nos outros 401; as rotas `auth/` ficam de fora.
- `error/` — `Failure` carrega `message` (o `detail` da API) e `code`. `failureFrom(DioException)` é a única tradução: 400 `invalido` → `ValidationFailure(fields)`, 401 → `AuthFailure`, 402 → `SubscriptionFailure`, 403 → `PermissionFailure`, 404 → `NotFoundFailure`, sem resposta → `NetworkFailure`. **O fluxo da tela é decidido pelo `code`, nunca pelo texto.**
- `cep/` — `ViaCepDataSource` (viacep.com.br): a API não tem busca de endereço por CEP.
- `utils/` — `dinheiro.dart` (`Decimal` ⇄ `"45.50"`, `formatarDinheiro`; nunca `double`) e `datas.dart` (data, data-hora com fuso, hora).

### Padrões das telas

- Estado de tela é um `ChangeNotifier` em `presentation/providers/<tela>_provider.dart`, exposto por `Provider.autoDispose` no `<feature>_provider.dart`. A page lê com `ref.watch` e redesenha com `ListenableBuilder`; nunca cria o provider na mão (o router redesenha as rotas quando a sessão muda).
- Erro de validação da API (`ValidationFailure.fields`) vai para o campo, com `forceErrorText`, como no cadastro. O resto vai para a mensagem da tela.
- Depois do login, `context.go('/splash')`: a splash decide entre onboarding e home. Depois do cadastro confirmado, direto `/onboarding`.
- Testes: provider com use case mockado (`mocktail`) e datasource com o `FakeAdapter` de `test/helpers/`, que passa pelo Dio de verdade.
