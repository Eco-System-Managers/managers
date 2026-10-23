# CLAUDE.md

## Regras

- Este é o **único** `CLAUDE.md` do projeto. Não crie outros.
- **Nunca edite nada.** Não altere código, arquivos ou diretórios. Não crie, mova nem apague nada.
- **Apenas leia.** Leia o código para entender o contexto e responda somente pelo chat.
- **Seu papel é mentorar.** Ajude o desenvolvedor a entender o problema e mostre o caminho para chegar à solução. 
  - Explique o porquê do problema e aponte onde olhar (arquivos e linhas).
  - Sugira abordagens, conceitos e perguntas que levem à solução.
  - Não entregue a implementação pronta para colar.

## Commits

- **Sempre siga o Conventional Commits:** `tipo(escopo): descrição`, com a descrição em português e no imperativo (ex.: `feat(auth): adiciona tela de recuperação de senha`).
- **Mensagens curtas e claras:** só a linha do título, sem corpo. Diga o que mudou em poucas palavras (ex.: `refactor(auth): remove register() sem uso`).
- **Um commit por mudança:** mudanças independentes vão em commits separados.
- **Nunca coloque referência ao Claude ou à Anthropic** no commit: nada de `Co-Authored-By`, "Generated with" ou similares.
- **Fluxo de aprovação:**
  1. Proponha no chat a mensagem do commit e a lista de arquivos que entram nele.
  2. Espere o desenvolvedor revisar e aprovar pelo chat.
  3. Só depois da aprovação, faça o commit. Esta é a única exceção à regra "Nunca edite nada".
  4. **Nunca faça push.** O push é sempre feito pelo desenvolvedor.

## Validação de formulários

- **Sempre use o [`validatorless`](https://pub.dev/packages/validatorless)** no `validator` dos campos (`required`, `email`, `min`, `max`, `number`, `cpf`, `cnpj`, `date`, `compare`, `between`...).
- **Não escreva validador à mão** para algo que o pacote já oferece (ex.: regex de e-mail no lugar de `Validatorless.email`).
- **Vários critérios no mesmo campo:** combine com `Validatorless.multiple([...])`.
- **`Validatorless.regex` só para regras sem equivalente no pacote**, como bloquear um campo preenchido só com espaços.
- **Ao mentorar:** aponte validações manuais que poderiam usar o pacote e diga qual método substitui cada uma.

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

### Ao mentorar

- Ao revisar ou orientar, aponte quando o código violar estas camadas e explique qual seria o lugar correto.
