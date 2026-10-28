# Decisões de aplicação do Design System

Onde o Design System (esta pasta; a fonte é `tokens/tokens.json`) não dizia o que fazer, a decisão foi tomada pelo princípio mais próximo: **duas cores, uma pequena**; **geometria, não desenho**; **azul = ação**. Uma linha de justificativa por decisão.

App: **Work Manage** (`frontend/apps/workmanage`).

## Escopo

- **Só o Work Manage.** O `frontend/apps/servicemanage` é um esqueleto sem telas (um `main.dart` de exemplo); no app entram só os arquivos `w-*`.
- **`design/` na raiz do monorepo**, e não dentro do app: o Design System é das duas marcas e serve aos dois apps.
- **O Grafite (`#14161B`) ficou fora.** Ele aparece em `brand_colors.dart` e na paleta, mas não em `tokens.json`, que é a fonte da verdade; o app não tem bloco de código.
- **A versão azul do logo (`*-blue.svg`) ficou fora do app.** O Design System a reserva para peças onde só o azul está disponível (carimbo, bordado).

## Cor

- **Azul no tema escuro, dois usos.** `primary` é `#5A93FF` (link, ícone e texto ativos, foco: 5,7:1 sobre o fundo), com `onPrimary` marinho. Branco sobre `#5A93FF` dá 3:1 e reprova a regra dos 4,5:1. Todo **preenchimento azul que leva texto** usa o azul da marca `#1B6AF3` com branco nos dois temas (4,8:1): botão primário, botão flutuante, dia escolhido no calendário, ponteiro do relógio.
- **`secondary` é o `ink`**, e os dois *containers* (`primaryContainer`, `secondaryContainer`) são o `blue-soft` com texto `ink`. Esse par pinta tudo que está "selecionado" (chip, botão segmentado, linha da lista), e o `blue-soft` é o "fundo de destaque ligado ao azul".
- **A terciária fica nos neutros** (`ink-muted`, `bg-2`): a marca tem duas cores e o resto é interface.
- **As superfícies do Material 3 viram só `bg` e `bg-2`**: `surface`, `surfaceContainerLowest` e `Low` = `bg`; `surfaceContainer`, `High` e `Highest` = `bg-2`. O Design System tem dois fundos.
- **`outline` e `outlineVariant` são os dois o `border`.** Por isso borda nunca é cor de texto nem de ícone: no claro, `#DFE6F1` some sobre o branco.
- **Caixa de erro = `bg-2` com texto `danger`.** O Design System não tem um vermelho suave, e não se inventa tom.
- **No escuro, o que flutua (diálogo, folha de baixo, menu, calendário, relógio) é o `bg-2`; no claro, o `bg`.** No escuro, o `bg` é o próprio marinho e não se separaria da página.
- **Tudo flat.** `surfaceTint` transparente: o Material 3 não tinge a elevação de azul.
- **A barra de cima é o fundo da página.** Quando o conteúdo passa por baixo, ela vira o `bg-2`, sem sombra.
- **Aviso (SnackBar):**
  - no claro, marinho com texto branco;
  - no escuro, `bg-2` com borda;
  - a ação usa o azul do tema escuro (`#5A93FF`), que passa de 5:1 sobre os dois fundos.
- **Interruptor e caixa de seleção.** Desligado: polegar e contorno em `ink-muted`, porque o `border` sumiria. Ligado: o azul com `onPrimary`.

## Tipografia

- **Inter e MuseoModerno embarcadas** em `assets/fonts/` (Inter 400/500/600/700 estáticas; MuseoModerno variável), com as licenças OFL registradas no `LicenseRegistry`. O `google_fonts` saiu por dois motivos:
  - baixava a fonte no primeiro uso, sem internet o app abria em outra fonte;
  - cada peso virava uma família, então `copyWith(fontWeight: …)` engrossava a Inter 400 em vez de usar o arquivo do peso.
- **Os 15 papéis do Material 3 nos 7 tamanhos de interface do Design System.** Os pesos são por grupo, como pedido: display e headline 700, title 600, body 400, label 500.
  - Onde dois papéis caem no mesmo token, eles ficam iguais (ex.: `headlineMedium` e `headlineSmall` = 24).
  - O `bodySmall` (a *caption*) já sai em `ink-muted` ("sempre em ink-muted").
- **Tamanho fora da escala vai para o token mais próximo; no empate, o menor.** Vale também para espaçamento e raio. Arredondar para cima podia estourar layout em tela pequena.
- **Texto de botão em `body-strong` (15/600).** O `label` (13) é, no Design System, o texto de "botões pequenos".
- **Título de linha de lista em `body-strong`** ("nome em listas"), detalhe em `body` `ink-muted`.
- **Título de aviso e de diálogo em `h3`**, e o rótulo flutuante do campo em `label`.

## Forma, espaço e sombra

- **Botões com `radius-md` em vez de pílula.** O token diz "botões e cartões", e é o raio dos cantos do símbolo.
- **Padding de botão:** `space-3` na vertical ("padding interno de botões e inputs") e `space-5` dos lados, para o texto não ficar espremido.
- **Campo preenchido com `bg-2`** ("bg-2: campos de formulário"), com borda fina, `radius-sm` e foco em 2 px de azul.
- **A caixa de seleção mantém o canto padrão do Material (2 px).** É ≈ 1/10 da altura, a mesma proporção dos cantos do símbolo; os 6 px do `radius-sm` deixariam a caixa quase redonda.
- **Uma sombra só.** Os elementos do app que flutuam usam a `shadow-card` exata. Os componentes do Material que flutuam (botão flutuante, menu, aviso) não aceitam `BoxShadow`, então usam elevação 2, a sombra do Material mais próxima dela. O resto não tem elevação e se separa por borda.

## Marca dentro do app

- **`BrandLogo` escolhe a versão pelo fundo:**
  - luminância abaixo de 0,5 (marinho, azul, fundos do escuro) → branco;
  - `bg` e `bg-2` → colorido;
  - outro fundo claro → marinho.
  Ele guarda o respiro de ¼ da altura do símbolo e o tamanho mínimo: logo com 24 px, abaixo disso só o símbolo, que não desce de 16 px.
- **O logo empilhado segue o mesmo mínimo de 24 px do horizontal**, porque o Design System só fixa o do horizontal. Nas telas de entrada (`AuthLogo`):
  - o empilhado vale até 72 px, onde a wordmark ainda é legível;
  - abaixo disso fica só o símbolo, que some quando nem ele cabe (teclado aberto);
  - a altura máxima é 96 px, a medida de referência do Design System para o respiro.
- **Telas de abertura no marinho, nos dois temas**: splash, entrar, cadastro, recuperar senha e verificar e-mail.
  - O logo vai na versão branca, como no ícone do app.
  - O azul da tela inteira saiu: ele fica para os botões.
  - O painel do formulário é `bg` no claro e `bg-2` no escuro, com `radius-lg`.
- **O loader e a splash desenhavam o logo antigo (os dois anéis).** Agora é o símbolo W animado, com os mesmos três caminhos do SVG, sem alterar nenhum ponto:
  - as hastes entram, a gota azul chega por cima ("o cliente que chega para o próximo horário"), o símbolo respira e sai;
  - os tempos são os de antes, porque a splash espera o fim do ciclo para navegar;
  - é colorido no claro e branco no escuro e na splash.

## Fora do app (plataformas)

- **Splash nativa:** marinho com o símbolo branco a 120 dp, o mesmo tamanho da splash do Flutter, que continua sem salto.
  - Android até o 11: `launch_background`.
  - Android 12+: `windowSplashScreenBackground` e `windowSplashScreenAnimatedIcon`, num quadro de 288 dp.
  - iOS: `LaunchScreen` e `LaunchImage`.
- **Ícone do app (`flutter_launcher_icons`):**
  - Android adaptativo: fundo `#0B1C35` e o símbolo branco a 68 % da largura, como no ícone do Design System; a mesma frente é o ícone monocromático do Android 13.
  - Aparelhos antigos: `w-icone-marinho-1024`.
  - iOS: o `-quadrado-1024`, sem alfa, porque o sistema aplica a própria máscara.
- **Web (`frontend/workmanage_web`):**
  - favicon de 48, ícones de 192 e 512, e as versões *maskable* feitas do quadrado;
  - `manifest.json` e `index.html` com o nome e o marinho como cor do tema.
  - O app não tem a pasta `web/`, por isso o gerador não cuidou da web.
- **O nome que aparece no aparelho passou a ser "Work Manage"** (Android `label`, iOS `CFBundleDisplayName`, web). Antes era "managers"/"Managers". O `applicationId` e o *bundle id* não mudaram.
- **Bug do gerador.** O `flutter_launcher_icons` 0.14.4 troca por engano `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` para `AppIcon` no `project.pbxproj`. A mudança foi desfeita; ao gerar de novo, desfaça outra vez.

## Telas

- **Ícones de interface na família Material Icons Round** (`Icons.*_rounded`), como pedido. Quando a família tem a versão de linha do mesmo desenho (`*_outline_rounded`), ela é preferida: o Design System pede "ícones de linha", e não se adicionou pacote de ícones.
- **Status:** a cor vai no texto e no ícone (`success`, `warning`, `danger`, ou `ink`/`ink-muted` para os estados neutros), sobre fundo neutro com borda fina. Nada de tons translúcidos da cor do status.
- **Gráficos:** as barras são `ink-muted`, e só a barra destacada é azul ("duas cores, uma pequena"). Numa divisão em duas partes: `ink` e `ink-muted`, sem azul, porque é dado, não ação.
- **Contador de pendências em `warning`, com o número em `bg`** (Início, Agenda e Quadro). O badge do tema é `danger`, mas pendente é atenção, e o mesmo número tem a mesma cor em toda parte.
- **Linha de lista: o tema não fixa `textColor`.** O `ListTile` pintaria com ela o título, o detalhe e as pontas, e o detalhe perderia o `ink-muted`.
- **Só dois botões, como no Design System:** primário (azul) e secundário (contornado). O `FilledButton.tonal` sai como o primário pelo tema; onde a ação é secundária, vai o `OutlinedButton`.
- **Caixas de aviso e de erro em `radius-md`.** São blocos tipo cartão, não campos.

### Início (dashboard)

- **Logo horizontal colorido (24 px) no topo, acima da saudação, sem o respiro próprio do widget.** O recuo do cabeçalho (16 e 12) já passa do respiro de ¼ da altura.
- **O "card do próximo" deixou de ser um bloco azul cheio.** Ficou em `blue-soft` ("destaque de bloco"), com texto `ink` e `radius-lg`.
  - "Abrir" é o primário e "Avisar" é contornado, com fundo `bg`. Um link azul sobre o `blue-soft` dá 4,2:1, e a borda some sobre ele.
- **A contagem ("em 10 min") fica numa pílula `bg`**, em `warning` até 15 minutos e em `ink-muted` depois. O `bg-2` sumiria sobre o `blue-soft` (1,06:1).
- **Linha do dia:**
  - pílulas em `bg-2`;
  - o próximo horário em `blue-soft` com contorno azul, porque no escuro o `blue-soft` e o `bg-2` quase se confundem;
  - os horários que já passaram em `ink-muted` (antes era a cor de borda).
- **A saudação vai em `titleLarge` (h3) e o faturamento em `headlineMedium`.** Os números vêm depois do que vem agora.

### Financeiro (Caixa e cobrança)

- **O recebido do Caixa fica em `headlineMedium`, igual ao faturamento do Início.** O Caixa segue a linguagem do Início, e com fonte grande o total cabe inteiro.
- **Na cobrança, a soma diz se dá para confirmar:**
  - "Confere" e "Troco" em `success`;
  - "Falta" e "Passa" (cartão ou PIX acima do total) em `danger`.
- **Saldo de crédito e extrato em `ink`, com o sinal + ou −.** Movimento de crédito não é status, e o vermelho sugeriria erro.
- **O erro do crédito traz o limite** ("Use até R$ 30,00, sem passar do total"). O erro do campo esconde a dica "Disponível".

### Agenda

- **Status:**
  - agendado e cancelado em `ink-muted` (cancelado era a cor de borda: invisível);
  - confirmado em `ink`;
  - concluído em `success`;
  - faltou em `danger`.
  O chip é transparente com borda fina.
- **Bloco da grade:**
  - `blue-soft` com texto `ink` e uma barra de 3 px na cor do status;
  - `radius-sm`, porque o bloco de 15 minutos tem 27 px e com `md` viraria pílula.
- **A linha do "agora" é azul, a única peça azul da grade.** Marca o estado atual, como o "hoje" do calendário.
- **Na grade, a linha da hora é `border` e a dos 15 minutos é `bg-2`.** É a hierarquia que antes vinha de borda translúcida.
- **Horário escolhido em `brandBlue` com texto branco; ocupado em `bg-2` com `ink-muted`.**
- **A folga do fim da grade passou de 96 para 64 (`space-7`).** O último horário continua acima do botão flutuante.

### Quadro (kanban)

- **As cores das etapas são dado do negócio**: o dono escolhe e a API guarda e cria as três padrão.
  - A paleta ficou como estava, e é o único lugar com cor literal fora do tema.
  - A cor da etapa só marca (bolinha); o texto fica em `ink`.
- **O check da amostra escolhida é marinho ou branco pelo contraste com a cor** (`estimateBrightnessForColor`). Nenhuma cor da paleta passa de 0,5 de luminância, então "branco fixo" daria 2,2:1 no âmbar padrão.
- **A coluna do quadro é um painel `bg-2` com `radius-lg`; os cartões, `bg` com borda e `md`.** Com o tema novo, o fundo antigo da coluna era o próprio `bg`.
- **A etapa sendo arrastada fica em `blue-soft` com a `shadow-card`.** Ela flutua sobre a lista.
- **Pago e Faltou: texto na cor do status, borda fina, `radius-sm`.**

### Clientes

- **Dados travados (cliente que veio do app): texto em `ink-muted` e cadeado no fim do campo.** O cinza de 38 % do campo desabilitado fica abaixo de 4,5:1.
- **A data de nascimento travada continua sendo o `CampoData`, sem o cadeado.** O validador dele vale também com o campo travado, e trocar o campo mudaria o comportamento. O modo travado do `CampoData` está pendente no core.
- **O selo "App" é `blue-soft` sem borda** ("badges").
- **"Não informado" vai em `ink-muted`, sem itálico.** A Inter embarcada não tem itálico, que sairia sintetizado.
- **O nome na ficha vai em `h2`; nos dados, o rótulo em `label` e o valor em `body`.** Antes o rótulo pesava mais que o valor.
- **O vão entre os cartões da ficha é `space-4`** ("vão entre cartões"). O ícone de editar é `mode_edit_outline_rounded`, a versão de linha.

### Textos que mudaram (tom de voz)

- **Início:**
  - "Não deu para abrir o WhatsApp." → "Não foi possível abrir o WhatsApp. Confira se ele está instalado e tente de novo."
  - A mensagem do "Avisar" perdeu o "!" e o "te esperamos".
- **Agenda:**
  - "Sem horários livres neste dia. Escolha outro dia." No dia lotado, a frase antiga dizia que o negócio não abria.
  - "Ninguém ativo executa este serviço. Escolha quem executa em Mais › Serviços."
- **Quadro:**
  - "Nenhum atendimento" (era "Nada aqui").
  - O caminho das etapas passou a "Mais › Configurações › Etapas do quadro".
  - "Escolha outro dia ou receba sem hora marcada."
