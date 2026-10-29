# Como aplicar o Design System nas telas do Work Manage

Regras para qualquer tela do app (`frontend/apps/workmanage`), nova ou antiga. A fonte de todos os valores é `design/tokens/tokens.json`; o brand book é `design/00-overview/README.md`; as escolhas onde o Design System é omisso estão em `design/DECISOES.md`.

## O que já existe no código

- `lib/core/theme/brand.dart` exporta os tokens:
  - `BrandColors` (também é a `ThemeExtension`): `BrandColors.of(context)` dá `navy`, `blue`, `blueSoft`, `bg`, `bg2`, `border`, `ink`, `inkMuted`, `onBrand`, `success`, `warning`, `danger` do tema atual. Fixos: `BrandColors.brandBlue` e `BrandColors.brandNavy`.
  - `BrandSpacing.space1` a `space7` = 4, 8, 12, 16, 24, 40, 64.
  - `BrandRadius.sm` 6 / `md` 12 / `lg` 20, e os `BorderRadius` prontos `smAll`, `mdAll`, `lgAll`, `lgTop`.
  - `BrandShadows.card(context)`: a única sombra.
  - `BrandText` (`h1`, `h2`, `h3`, `body`, `bodyStrong`, `label`, `caption`; `wordmark` e `display` em MuseoModerno, só para marca e capa).
- `lib/core/theme/theme.dart`: `AppTheme.light()` e `AppTheme.dark()`, com o `ColorScheme` ligado aos tokens e os temas de todos os componentes.
- **Papéis do ColorScheme que pegam de surpresa:**
  - `outline` e `outlineVariant` são o `border`, claríssimo: nunca para texto ou ícone.
  - `primaryContainer` e `secondaryContainer` são o `blueSoft`.
  - `errorContainer` é o `bg2`, com `onErrorContainer` = `danger`.
  - `tertiary` é o `inkMuted`.
  - `onSurfaceVariant` é o `inkMuted`.
- **Componentes que já saem certos pelo tema:**
  - O `FilledButton` (e o `.tonal`, porque o tema vale para as duas variantes) é azul da marca com texto branco. O `OutlinedButton` é o secundário (texto `ink` e borda). O `TextButton` é link azul.
  - Campos: fundo `bg2`, borda e foco azul. Não ponha `border: OutlineInputBorder()` local.
  - Cartões: `bg` com borda e sem sombra.
  - Chips: `radius-sm`, com o selecionado em `blueSoft`.
  - Diálogos e folhas: `radius-lg`.
  - Linhas de lista: título `bodyStrong`, detalhe `body` em `inkMuted`.
  - `CircularProgressIndicator`: azul.
  - Status: `SeloDeStatus` (`lib/core/widgets/selo_de_status.dart`), a cor do status no texto e no ícone, sobre fundo neutro com borda fina. O `StatusContratoChip`, os selos de inativo, de convite e da assinatura usam ele.
- **Marca:**
  - `lib/core/widgets/brand_logo.dart` (`BrandLogo`) escolhe a versão do logo pelo fundo.
  - `work_manage_loader.dart` é o símbolo animado.
  - `auth_logo.dart`, `auth_panel.dart` e `estiloDaBarraDeAbertura` são das telas de abertura.

## Regras de tela

1. **Cor.** Nada de `Color(0x…)`, `Colors.<qualquer>` (só `Colors.transparent`), `.shadeNNN` ou hexadecimal: use os papéis do `colorScheme` ou `BrandColors.of(context)`. Não invente tom com `withValues(alpha:)`; escolha um token (`blueSoft` para destaque, `bg2` para fundo neutro, `border` para linha). Status só para status: `success` concluído/aprovado/pago, `warning` pendente/atenção, `danger` erro/atraso/ação destrutiva.
2. **Azul = ação.**
   - O `primary` só vai em: botão primário, link, estado ativo/selecionado e foco.
   - Nunca em ícone decorativo, título, avatar ou cabeçalho, e nunca como fundo de tela ou seção.
   - Selecionado ou destacado: `blueSoft` com texto `ink`.
   - Preenchimento azul que leva texto (dia ou horário escolhido): `BrandColors.brandBlue` com `onBrand`, nos dois temas.
   - Texto, ícone ou contorno azul sobre o fundo: `colorScheme.primary`, que clareia no escuro.
3. **Contraste ≥ 4,5:1.**
   - Sobre `bg` e `bg2`: `ink`, `inkMuted`, `primary`, `success`, `warning`, `danger`.
   - Sobre `blueSoft`: `ink`.
   - Sobre `brandBlue` e marinho: branco.
   - Cor que é dado (as cores de etapa do quadro) só marca: bolinha, barra ou borda. Ela nunca leva texto.
4. **Tema escuro** em toda tela: nenhuma cor fixa que suma no escuro.
5. **Tipografia.** Nada de `TextStyle(fontSize: …)`: use os papéis do `textTheme` ou o `BrandText`, mudando só a cor com `copyWith`.
   - Tamanhos do Design System: 12, 13, 15, 18, 24, 32. Fora deles, o mais próximo, e no empate o menor (14 → 13, 16 → 15, 20 → 18, 22 → 24, 28 → 24).
   - Ênfase: `titleMedium` ou `BrandText.bodyStrong`, em vez de `copyWith(fontWeight:)`.
   - Título de cartão, folha ou seção: `titleLarge` (h3). Título de ficha: `BrandText.h2`.
   - Número grande: `headlineMedium`. Legenda ou metadado: `bodySmall`.
   - MuseoModerno nunca em texto de interface.
6. **Espaçamento.** Todo padding, margem e vão usa `BrandSpacing`. Fora da escala, o token mais próximo, e no empate o menor: 2 → 4, 6 → 4, 10 → 8, 14 → 12, 20 → 16, 32 → 24, 48 → 40, 56 → 64.
   - Medida de componente não é espaçamento: tamanho de ícone, raio de avatar, `minimumSize`, altura de grade ou de gráfico, o `SizedBox(height: 2)` que guarda o lugar do `LinearProgressIndicator`.
   - `paddingDaPagina(context)` e `abrirFolha` continuam como estão.
7. **Raio.** Até 9 → `sm`; de 10 a 16 → `md`; 17 ou mais → `lg`.
   - Campo, chip e badge: `sm`.
   - Botão, cartão e **caixa de aviso ou erro**: `md`.
   - Painel, folha e diálogo: `lg`.
   - Círculo de verdade (avatar, bolinha) continua círculo.
8. **Sombra.** Só o que flutua sobre o conteúdo (a barra de baixo, um item sendo arrastado) usa `BrandShadows.card(context)`. O resto se separa por `Border.all(color: BrandColors.of(context).border)`.
9. **Ícones.** Use a família Material Icons Round (`Icons.*_rounded`), com a versão de linha quando ela existe: `people_outline_rounded`, `person_outline_rounded`, `mail_outline_rounded`, `lock_outline_rounded`, `error_outline_rounded`, `info_outline_rounded`, `check_circle_outline_rounded`, `delete_outline_rounded`, `mode_edit_outline_rounded`.
   - O ícone fica em `ink` ou `onSurfaceVariant`; o azul só vai no ativo.
   - O símbolo da marca nunca vira ícone.
10. **Tom de voz.** Claro, acolhedor, profissional e prático: frases curtas, "você", sem exclamação, e toda mensagem diz o que aconteceu e o que fazer em seguida.
    - Exemplo: "Horário confirmado: Ana, sexta às 14h. Enviamos um lembrete 1 hora antes."
    - Não mexa em texto que é lógica: rota, código ou campo da API, chave, regex, variável de modelo (`{{cliente_nome}}`).
    - Mensagem que vem da API vai como chega.
    - Se um teste afirma o texto que você mudou, atualize o teste.
11. **Só apresentação.** Arquitetura, navegação e regras de negócio ficam iguais (ver `frontend/apps/workmanage/CLAUDE.md`).
    - Não mexa em `domain/`, `data/`, injeção de dependência, rotas.
    - Nos providers de tela, só nos textos.
    - Não mude a API pública de widget usado por outra feature, e não remova funcionalidade.
12. **Botões.** O Design System tem dois: o primário (azul) e o secundário (contornado). O `FilledButton.tonal` sai igual ao primário pelo tema: use-o só como ação principal. Onde a ação é secundária, use `OutlinedButton`.
13. **Status e gráficos.**
    - Status: cor do status no texto e no ícone, sobre fundo neutro com borda fina. Os neutros vão em `inkMuted` ou `ink`.
    - Contador de pendências: `warning`, com o número em `bg`.
    - Gráficos: barras em `inkMuted`, só a destacada em `primary`. Duas partes: `ink` e `inkMuted`.

**Validação:** `flutter analyze` sem nenhum aviso e `flutter test` passando. Um commit por módulo: Conventional Commits em português, só a linha do título, sem referência ao Claude, e o push é sempre do desenvolvedor.
