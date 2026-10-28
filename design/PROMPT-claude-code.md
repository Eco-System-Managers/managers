# Prompt para o Claude Code — aplicar o Design System no app Flutter

Cole o texto abaixo no Claude Code, aberto na raiz do projeto Flutter. Ajuste só o caminho da pasta do Design System e o nome do produto (Work Manage ou Service Manage).

---

Aplique o Design System **Work Manage · Service Manage** neste projeto Flutter, por completo, em tudo o que couber. Este app é o **[Work Manage | Service Manage]**.

## Fonte da verdade

A pasta do Design System está em `C:\Users\Melina\Downloads\Work-Service-Manage-Brand` (copie-a para `design/` na raiz do repositório antes de começar e trabalhe a partir dessa cópia). Leia nesta ordem, inteiros, antes de tocar em qualquer código:

1. `LEIA-ME.txt` e `00-overview/README.md` — o brand book: essência, tom de voz, princípios, regras de logo, cores, tipografia.
2. `tokens/tokens.json` — a fonte de todos os valores (cores nos temas claro e escuro, tipografia, espaçamento, raio, sombra). Tudo que você escrever em código deriva daqui; nunca invente um valor.
3. `01-colors/brand_colors.dart`, `03-spacing/brand_spacing.dart` — pontos de partida em Dart, podem ser absorvidos ou reescritos.
4. `02-typography/` — `MuseoModerno-variable.ttf` (só para a wordmark e títulos de capa) e as regras de Inter (interface).
5. `07-assets/` — logos e símbolos em SVG e PNG, ícones de app em 1024/512/192/48, imagens de redes sociais. Os SVGs já têm a wordmark em curvas.

## O que entregar

**1. Tema (`lib/theme/` ou onde o projeto já guarda tema):**
- `ThemeData` claro e escuro com Material 3 (`useMaterial3: true`), `ColorScheme.fromSeed(seedColor: 0xFF1B6AF3)` ajustado para que `primary` seja exatamente `#1B6AF3`, `onPrimary` branco, `secondary`/texto principal `#0B1C35`, superfícies `#FFFFFF` / `#F3F6FD` no claro e `#0B1C35` / `#13254A` no escuro, `outline` `#DFE6F1` / `#2A3B5C`, `error` `#B3261E` / `#FF7B72`. Os valores de cada tema estão em `tokens.json` → `color.tokens`, com a nota de uso de cada um.
- Classes de tokens (`BrandColors`, `BrandSpacing`, `BrandRadius`, `BrandShadows`, `BrandText`) e uma `ThemeExtension` para o que o `ColorScheme` não cobre (`blueSoft`, `inkMuted`, `success`, `warning`).
- `TextTheme` em **Inter** (adicione `google_fonts` ou os arquivos em `assets/fonts/`): display/headline 700, title 600, body 400, label 500, tamanhos e alturas de linha de `tokens.json` → `type.groups`. **MuseoModerno** entra como família separada, só para a wordmark e telas de capa; nunca em texto corrido.
- Escala de espaçamento base 4 (`space-1` 4 → `space-7` 64) e raios (`radius-sm` 6, `radius-md` 12, `radius-lg` 20, `radius-icon` 22 %). Uma sombra só (`shadow-card`); o resto usa borda.
- Temas de componentes no `ThemeData`: `AppBarTheme`, `ElevatedButton`/`FilledButton`/`OutlinedButton`/`TextButton` (pill ou `radius-md`, azul com texto branco; secundário contornado), `InputDecorationTheme` (`radius-sm`, borda `outline`, foco em `primary`), `CardTheme` (`radius-md`, borda em vez de sombra), `ChipTheme`, `DialogTheme`, `BottomSheetTheme`, `NavigationBarTheme`, `SnackBarTheme`, `DividerTheme`, `ListTileTheme`, `SwitchTheme`, `CheckboxTheme`.

**2. Marca dentro do app:**
- Logos e símbolos em `assets/brand/` a partir de `07-assets/logos-svg` e `simbolos-svg` (use `flutter_svg`). Crie um widget `BrandLogo` (horizontal / empilhado / símbolo; colorido / branco / marinho) que escolhe a versão certa pelo fundo, respeita a área de respiro (¼ da altura) e o tamanho mínimo (logo 24 px, símbolo 16 px).
- Splash e tela de abertura: fundo `#1B6AF3` ou `#0B1C35` com a versão branca; AppBar e cabeçalhos: versão horizontal colorida sobre fundo claro.
- Ícone do app: use `07-assets/icone-app/*-icone-marinho-1024.png` (ou `-quadrado-1024.png` nas plataformas que aplicam a própria máscara) com `flutter_launcher_icons`, para Android (adaptive icon com fundo `#0B1C35`), iOS e web (favicon em 48 e 192).

**3. Varredura de todas as telas e widgets:**
- Substitua toda cor, tamanho de fonte, padding, margem, raio e sombra hard-coded por tokens ou pelo tema. Nenhum `Color(0x…)`, `TextStyle(fontSize: …)`, `EdgeInsets.all(13)` ou `BorderRadius.circular(7)` solto deve sobrar fora dos arquivos de tema; o que não tiver token equivalente vira o token mais próximo da escala (nunca um valor novo).
- O azul é só para ação: botão primário, link, estado ativo, a peça azul do símbolo. O resto da interface fica em marinho, branco e cinza. Não pinte fundos inteiros de azul dentro do app (só fora dele: splash, capas).
- Texto sempre com contraste 4.5:1 sobre o fundo (os pares de `tokens.json` já passam nos dois temas); texto sobre azul é branco.
- Tom de voz nos textos da interface (strings, mensagens, erros, estados vazios): claro, acolhedor, profissional e prático; frases curtas, "você", sem exclamações, toda mensagem diz o que aconteceu e o que fazer em seguida. Ex.: "Horário confirmado: Ana, sexta às 14h. Enviamos um lembrete 1 hora antes."
- Ícones de linha com pontas arredondadas (`Icons.*_rounded` ou o pacote que o projeto já usa), em `ink`/`inkMuted`, azul só no ativo.
- Tema escuro funcional em todas as telas, sem cor fixa que suma no escuro.

**4. Decisões e qualidade:**
- Tome as decisões você mesmo quando o Design System for omisso, sempre pelo princípio mais próximo (duas cores e uma pequena; geometria, não desenho; azul = ação). Registre cada decisão em `design/DECISOES.md` com uma linha de justificativa.
- Preserve a arquitetura, a navegação e as regras de negócio do projeto; esta é uma mudança de apresentação. Não remova funcionalidade.
- Faça em commits pequenos por área (tema → marca → telas por módulo), rodando `flutter analyze` e os testes existentes a cada passo; corrija warnings que você introduzir. Atualize golden tests se houver.
- Ao final, entregue um resumo: o que mudou por pasta, os tokens criados, os pontos onde você teve de decidir sozinho e uma lista do que ficou fora (por exemplo telas geradas por bibliotecas de terceiros que não aceitam tema).

Comece lendo os arquivos do Design System e mapeando o projeto (estrutura de pastas, tema atual, pacotes de fonte/ícone já usados, telas). Apresente o plano em poucas linhas e siga sem esperar aprovação, a menos que encontre algo que mude regra de negócio.
