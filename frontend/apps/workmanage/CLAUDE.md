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
- `session/` — `Sessao` (access, refresh, `schema_name`, empresa), `SessaoRepository` (armazenamento seguro) e `SessaoController`, a sessão em memória do app inteiro. Login, cadastro e aceite de convite chamam `entrar`; logout e 401 definitivo chamam `sair`. O router usa o controller em `redirect` e `refreshListenable`: tela privada sem sessão volta ao login sozinha. `BloqueioAssinatura` é o aviso do 402: o interceptor marca, o router leva a `/mais/assinatura` (as rotas de billing e `/me/` são isentas no backend), a tela de assinatura limpa quando ela volta a valer, e a sessão acabando também limpa.
- `network/` — `dioProvider` (base URL, `X-Client-Platform: mobile`, `AuthInterceptor`) e `paginacao.dart` (`Pagina<T>` e `buscarTudo`, que segue o `next` com `page_size=100`). O interceptor renova em 401 `token_invalido` (uma vez, com o refresh compartilhado entre requisições), encerra a sessão nos outros 401 e marca o `BloqueioAssinatura` em 402; as rotas `auth/` ficam de fora.
- `error/` — `Failure` carrega `message` (o `detail` da API) e `code`. `failureFrom(DioException)` é a única tradução: 400 `invalido` → `ValidationFailure(fields)`, 401 → `AuthFailure`, 402 → `SubscriptionFailure`, 403 → `PermissionFailure`, 404 → `NotFoundFailure`, sem resposta → `NetworkFailure`. Regra de negócio (400 com code próprio: `horario_conflito`, `soma_invalida`, `cliente_com_atendimentos`...) é `ServerFailure` com o `code`. **O fluxo da tela é decidido pelo `code`, nunca pelo texto.**
- `cep/` — `ViaCepDataSource` (viacep.com.br): a API não tem busca de endereço por CEP.
- `utils/` — `dinheiro.dart` (`Decimal` ⇄ `"45.50"`, `formatarDinheiro`; nunca `double`), `datas.dart` (data, data-hora com fuso, hora; `somenteData`, `juntarDataHora`, nomes de mês e dia em português sem depender do locale do `intl`) e `lista_paginada.dart` (uma página já no domínio).
- `widgets/` — `Carregando`, `EstadoVazio`, `EstadoErro`, `confirmar()`, `AvatarIniciais`, `CampoData` (`ModoCampoData.calendario` abre o calendário do sistema; `digitacao` é dd/mm/aaaa com as barras entrando sozinhas, para datas longe de hoje como nascimento, validada ao sair do campo; `limpavel: false` quando a data é obrigatória), `FaixaSemana` (o calendário da agenda e do quadro: a semana deslizável, ou o mês quando `expandido`; quem usa guarda o estado e busca as bolinhas dos `diasDaSemana`/`diasDoMes`), `folha.dart` (`abrirFolha`, a única forma de abrir folha de baixo, e `paddingDaPagina`, o recuo das telas que rolam — os dois cuidam da barra de navegação do Android), `DinheiroInputFormatter` e `MascaraFormatter`.
- `compartilhar/whatsapp.dart` — o motor do WhatsApp pelo `wa.me` (`abrirWhatsApp`, `uriDoWhatsApp`, `numeroParaWhatsApp` com o DDI do Brasil): texto pronto e, quando se sabe, o número. Não conhece convite nem cliente; qualquer feature usa.

### Padrões das telas

- O app é de ponta a ponta (`SystemUiMode.edgeToEdge` no `main.dart`): o Android desenha a barra de navegação por cima. Folha de baixo abre por `abrirFolha` e tela que rola usa `paddingDaPagina(context)` como padding da lista; sem isso o último botão fica embaixo dos botões do sistema. Nas abas, o conteúdo termina acima da barra inferior flutuante (o `Scaffold` reserva a altura dela).
- O tema gerado tem a secundária preta; `_comAjustes` em `app.dart` troca o par `secondaryContainer`/`onSecondaryContainer` por um azul derivado da primária (é o que pinta chip selecionado, botão segmentado, botão tonal e caixas de aviso) A barra inferior é própria (`_BarraFlutuante` em `home_shell_page.dart`): uma pílula branca (escura no tema escuro) solta com sombra e margem, a aba atual na primária e as outras em cinza, sem indicador.

- Estado de tela é um `ChangeNotifier` em `presentation/providers/<tela>_provider.dart`, exposto por `Provider.autoDispose` no `<feature>_provider.dart`. A page lê com `ref.watch` e redesenha com `ListenableBuilder`; nunca cria o provider na mão (o router redesenha as rotas quando a sessão muda).
- Erro de validação da API (`ValidationFailure.fields`) vai para o campo, com `forceErrorText`, como no cadastro. O resto vai para a mensagem da tela.
- Depois do login, `context.go('/splash')`: a splash decide entre onboarding e home. Depois do cadastro confirmado, direto `/onboarding`.
- Estado que sobrevive à troca de aba (o dia aberto na agenda, o período do caixa) usa `Provider` sem autoDispose e recarrega da API ao voltar de qualquer tela aberta por cima (`recarregar`).
- Depois de criar, editar ou agir, o estado vem da resposta da API ou de uma nova leitura; a tela nunca ajusta o status por conta. Cancelar e inativar são `PATCH` de status quando a API tem status: o `DELETE` de agendamento, serviço e colaborador não é usado.
- Dinheiro na tela entra por `DinheiroInputFormatter` e sai por `dinheiroDoTexto` (`Decimal`); a cobrança confere a soma antes de mandar, porque a API recusa (`soma_invalida`).
- Testes: provider com use case mockado (`mocktail`) e datasource com o `FakeAdapter` de `test/helpers/`, que passa pelo Dio de verdade.

## Features

| Feature | O que é | Rotas |
|---|---|---|
| `splash` | Decide a rota inicial pela sessão e pela config | `/splash` |
| `auth` | Login, recuperação de senha e logout na API | `/login`, `/recovery` |
| `register` | Cadastro com confirmação por e-mail; a sessão vem na confirmação | `/register`, `/register/verificar` |
| `onboarding` | Só o wizard (negócio, nicho, horários); os dados são da `empresa` | `/onboarding` |
| `empresa` | **Dona do domínio da config**: `EmpresaConfig`, `HorarioFuncionamento`, `Nicho`, datasource, use cases, `NegocioAtualProvider` e as telas de configurações. Os widgets `DadosNegocioForm` e `HorarioDiaCard` são compartilhados com o onboarding | `/mais/configuracoes`, `.../negocio`, `.../horarios` |
| `usuarios` | `/colaboradores/me/` (papel e vínculo), a equipe (lista, ficha com nome, função, **vínculo parceiro/colaborador**, comissão do parceiro e a flag `pode_cobrar` do colaborador, que só aparece para quem tem acesso ao app ou convite a caminho; ativar/desativar; remover depois de contar os agendamentos futuros em `agendamentos-pendentes/`). **Adicionar é um passo só**: `POST colaboradores/` (já aparece nos filtros) e, com o interruptor "convidar para entrar no app" e o e-mail, `colaboradores/{id}/convidar/` na sequência (se o convite falhar, a pessoa fica criada e a tela só tenta o convite de novo). A ficha mostra o **convite pendente** da pessoa (`Convite.colaboradorId`): mandar o `link` por WhatsApp (`core/compartilhar`), reenviar (cancelar e convidar de novo) e cancelar; a lista marca "Convite enviado" na linha, e só convites sem pessoa (antigos) ficam numa seção à parte. O `FiltroProfissionais` (avatares) daqui é o filtro por profissional da agenda e do quadro. O aceite é público, pelo token do link, e já entra na sessão; sem deep link, o login tem "Recebi um convite" para colar o link. `Colaborador.veValores`/`cobra` e `negocioAtualProvider.veValores`/`podeCobrar` são o que a tela esconde (a API trava do lado dela) | `/mais/equipe`, `/mais/equipe/novo`, `/mais/equipe/:id`, `/convite/:token` |
| `servicos` | Catálogo: lista com busca e filtro de inativos, criar, editar, inativar e reativar (`PATCH ativo`; o `DELETE` da API apaga de verdade e não é usado) | `/mais/servicos`, `/mais/servicos/novo`, `/mais/servicos/:id` |
| `clientes` | A ficha do cliente: lista paginada com busca (`?search=`, nome/telefone/e-mail/CPF), criar e editar com CEP (ViaCEP), remover (a API recusa com `cliente_com_atendimentos`). Quem veio do app do cliente tem os dados espelhados travados. A ficha mostra o `SaldoClienteCard` do `financeiro` e o histórico do modo do negócio (`HistoricoClienteCard` da `agenda`, com "ver todos", ou `HistoricoKanbanCard` do `kanban`). Nos negócios por esteira a ficha tem os **veículos ou pets** (`Veiculo`, `Pet`, `ObjetoCliente`; vêm aninhados no cliente e mudam por `veiculos/` e `pets/`, nas folhas `VeiculoFormSheet`/`PetFormSheet`). O `ClientePickerSheet` daqui é usado pela agenda e pelo kanban: busca sem resultado oferece cadastrar o que foi digitado (`/clientes/novo?nome=` ou `?telefone=`), e o formulário fecha devolvendo o `Cliente` salvo, que sai escolhido. Nascimento é `CampoData` em modo digitação | `/clientes`, `/clientes/novo`, `/clientes/:id`, `/clientes/:id/editar`, `/clientes/:id/atendimentos` |
| `agenda` | O modo **horário**: um dia por vez com o calendário em cima (`FaixaSemana`: a semana deslizável ou o mês aberto pelo título ou pela alça; bolinhas de `agenda/dias-com-registro/`), o filtro por profissional em avatares e o contador de pendências; deslizar a grade para o lado troca o dia. O dia é uma **grade de horários** (`GradeDoDia`): o expediente vem de `empresa/horarios/`, uma linha a cada 15 min (`passoDaGrade`), os agendamentos têm a altura da duração e os que se sobrepõem dividem a largura (`grade_do_dia_layout.dart`, sem Flutter, testado); dia fechado mostra o aviso; tocar num espaço vazio abre o formulário com dia, hora e profissional (`?data=&hora=&colaborador=`). Marcar exige cliente, serviço (um por agendamento, `servico_id`), profissional e um slot da grade (`agenda/slots/`, que já desconta a duração). A ficha confirma, marca falta, remarca (`PATCH data_hora`; conflito é 400 `horario_conflito`), cancela (`PATCH status=cancelado`, que avisa o app do cliente) e cobra (`cobrar/`: várias formas, desconto, crédito da comanda e troco). O histórico de um cliente é `agendamentos/?cliente=` (tudo, ordenado na tela do mais recente) | `/agenda`, `/agenda/novo?data=`, `/agenda/pendencias`, `/agenda/:id` |
| `kanban` | O modo **esteira**: o quadro de um dia com as etapas em colunas (`kanban/etapas/`, `kanban/atendimentos/?data=`), chips de profissional (`?colaborador=`), receber um atendimento (cliente → o veículo ou pet dele → serviço → **profissional opcional** → dia → hora de entrada opcional da grade `kanban/slots/`, que vem da `capacidade` dos horários; `horario_ocupado` é 400), a ficha do card (mover por menu, cobrar/desfazer com a mesma folha da agenda, marcar/desfazer falta — `falta_em_pago` é 400 —, excluir quando não pago: a esteira não tem "cancelado") e as etapas do dono (`/mais/etapas`: renomear, cor, arrastar para reordenar, remover só vazia). O quadro conta as pendências com o use case da agenda, porque a API junta os dois modos | primeira aba quando `isKanban`, `/quadro/novo?data=`, `/quadro/:id`, `/mais/etapas` |
| `financeiro` | **Dono do dinheiro**: `FormaPagamento`/`Pagamento`, `CobrancaParams` e a `CobrancaSheet` que agenda e kanban usam (a pessoa lança o que o cliente entregou; o que passa do total em **dinheiro** é troco — a folha desconta da linha de dinheiro ao mandar, e um interruptor manda o troco como `troco_credito`; o que passa em cartão ou PIX é erro e trava o confirmar); o caixa por período (`financeiro/caixa/`, hoje/7 dias/mês/intervalo, com chips de profissional via `?colaborador=`; a API conta pelo dia do atendimento, não da cobrança; kpis `repasse` e `casa`, a comissão dos parceiros congelada em cada pagamento; o parceiro vê só o próprio, com `casa` nula; o colaborador comum não vê o caixa nem o item do Mais) e o saldo de crédito do cliente (`financeiro/clientes/{id}/saldo/`) | `/mais/financeiro` |
| `dashboard` | A aba **Início**: `dashboard/resumo/?data_inicio&data_fim&colaborador` — os números do período (hoje por padrão; 7 dias, mês ou intervalo) com variação sobre o período anterior de mesmo tamanho, o que vem hoje e o atalho das pendências (o ranking de serviços da API não é mostrado). O proprietário filtra por profissional (chips); quem não é vê só os próprios números, travado pela API (`colaborador` na resposta diz o aplicado), e `clientes_novos` vem nulo quando filtrado; para o colaborador comum os kpis de dinheiro vêm nulos e a tela mostra só o que veio; `repasse` é a comissão (para o parceiro, "a receber") | `/inicio` |
| `contratos` | Mais › Contratos: os contratos gerados (filtro por `?status=`) e os modelos (texto livre com as variáveis `{{cliente_nome}}`, `{{cliente_email}}`, `{{cliente_cpf}}`, `{{data}}`, `{{negocio_nome}}`; só o proprietário escreve, inativa por `PATCH ativo`). Gerar (`contratos/gerar/`) escolhe modelo e cliente e abre a ficha; a ficha monta o **PDF** (`pdf`) e abre a folha de compartilhar (`printing`), marcando `enviado` no primeiro compartilhamento; assinado e recusado o dono marca à mão (`contratos/{id}/marcar/`). A ficha do cliente tem o `ContratosClienteCard` (`?cliente=`) | `/mais/contratos`, `/mais/contratos/gerar?cliente=`, `/mais/contratos/:id`, `/mais/contratos/modelos/novo`, `/mais/contratos/modelos/:id` |
| `assinatura` | `billing/`: a assinatura do negócio, o checkout no navegador (`url_launcher`; o link vem de `iniciar/`), a confirmação por `id_externo` (o retorno do checkout cai na web, sem deep link), o cancelamento e as cobranças. É para cá que o 402 leva | `/mais/assinatura` |
| `home` | A casca: `StatefulShellRoute` com as abas Início, Agenda/Quadro, Clientes e Mais; a aba Mais tem configurações, serviços, financeiro (caixa), contratos, equipe, assinatura e sair. A segunda aba é a `PrimeiraAbaPage`, que escolhe `AgendaPage` ou `QuadroPage` pelo `tipo_agenda` | `/inicio`, `/agenda`, `/clientes`, `/mais`; `/home` redireciona para `/inicio` |

### O negócio atual

`negocioAtualProvider` (em `empresa_provider.dart`) guarda a config e o papel
de quem entrou (`/colaboradores/me/`), carregados pela casca depois do login
e zerados quando a sessão acaba. É por ele que a aba se chama Agenda ou
Quadro (`tipo_agenda`) e que serviços e configurações escondem a escrita de
quem não é proprietário. Quem salva a config chama `atualizarConfig`, e o
resto do app enxerga na hora.

### Telas por cima das abas

Formulários e configurações abrem no navegador raiz (`parentNavigatorKey`),
sem a barra inferior. Um formulário fecha com `context.pop(true)` quando
salvou, e a lista que o abriu recarrega da API ao receber o `true`.
Formulário por id usa `Provider.autoDispose.family` (`servicoFormProvider`).
