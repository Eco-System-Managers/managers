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
- **Nunca coloque referência ao Claude ou à Anthropic** no commit: nada de `Co-Authored-By`, "Generated with" ou similares.
- **Fluxo de aprovação:**
  1. Proponha no chat a mensagem do commit e a lista de arquivos que entram nele.
  2. Espere o desenvolvedor revisar e aprovar pelo chat.
  3. Só depois da aprovação, faça o commit. Esta é a única exceção à regra "Nunca edite nada".
  4. **Nunca faça push.** O push é sempre feito pelo desenvolvedor.

## Arquitetura (Clean Architecture)

Toda feature nova segue as camadas abaixo, dentro da estrutura de pastas existente.

### Camadas e pastas

- `lib/data/services/` — clientes técnicos genéricos (HTTP, storage). Sem regra de negócio, sem conhecer features.
- `lib/data/datasources/<feature>/` — acesso aos dados de uma feature (remoto/local), usando os services. Retorna models de `data/model/`.
- `lib/data/model/` — DTOs da API/armazenamento, com `fromJson`/`toJson`.
- `lib/data/repositories/` — implementação dos repositórios: usa datasources e converte DTO → entidade de domínio.
- `lib/domain/models/` — entidades de domínio, Dart puro.
- `lib/domain/repositories/` — contratos (classes abstratas) dos repositórios.
- `lib/domain/use_cases/<feature>/` — um caso de uso por ação (`LoginUseCase`, `SendRecoveryCodeUseCase`), com um único método `call`.
- `lib/ui/<feature>/view_models/` — estado da tela; chama **apenas** use cases.
- `lib/ui/<feature>/providers/` — injeção de dependências com Riverpod.

### Regra de dependência

- `ui` → `domain` ← `data`. O `domain` não importa Flutter, `data` nem `ui`.
- ViewModels nunca usam repositories, datasources ou services diretamente.
- Widgets nunca acessam nada além do seu ViewModel.

### Nomenclatura

- Arquivos em `snake_case`, com sufixo da camada: `auth_remote_datasource.dart`, `auth_repository.dart` (contrato), `auth_repository_impl.dart`, `login_use_case.dart`.

### Ao mentorar

- Ao revisar ou orientar, aponte quando o código violar estas camadas e explique qual seria o lugar correto.
