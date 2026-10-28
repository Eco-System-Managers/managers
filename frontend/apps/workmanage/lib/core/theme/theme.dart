import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';

// o tema do app, claro e escuro, montado só com os tokens do Design System
// (brand.dart; a fonte é design/tokens/tokens.json). o ColorScheme parte do
// azul da marca e cada papel do Material 3 é ajustado para um token, então
// nenhum tom é inventado. as escolhas que o Design System não cobre estão em
// design/DECISOES.md
abstract final class AppTheme {
  static ThemeData light() => _tema(BrandColors.light, Brightness.light);

  static ThemeData dark() => _tema(BrandColors.dark, Brightness.dark);

  // a sombra do Material mais próxima da shadow-card, para os componentes do
  // Material que flutuam (botão flutuante, menu, aviso) e não aceitam
  // BoxShadow; o resto fica sem elevação e se separa por borda
  static const _elevacaoFlutuante = 2.0;

  static ColorScheme colorScheme(BrandColors c, Brightness brilho) {
    final claro = brilho == Brightness.light;
    return ColorScheme.fromSeed(
      seedColor: BrandColors.brandBlue,
      brightness: brilho,
    ).copyWith(
      // azul = ação. no escuro o texto sobre o azul clareado é o marinho
      // (5.7:1): o branco daria 3:1
      primary: c.blue,
      onPrimary: claro ? c.onBrand : c.navy,
      primaryContainer: c.blueSoft,
      onPrimaryContainer: c.ink,
      primaryFixed: BrandColors.light.blueSoft,
      primaryFixedDim: BrandColors.light.blueSoft,
      onPrimaryFixed: c.navy,
      onPrimaryFixedVariant: c.navy,
      // a secundária é o marinho do texto; o par container é o azul suave,
      // que pinta tudo que está "selecionado" (chip, botão segmentado)
      secondary: c.ink,
      onSecondary: c.bg,
      secondaryContainer: c.blueSoft,
      onSecondaryContainer: c.ink,
      secondaryFixed: BrandColors.light.bg2,
      secondaryFixedDim: BrandColors.light.bg2,
      onSecondaryFixed: c.navy,
      onSecondaryFixedVariant: c.navy,
      // a marca tem duas cores; a terciária fica nos neutros
      tertiary: c.inkMuted,
      onTertiary: c.bg,
      tertiaryContainer: c.bg2,
      onTertiaryContainer: c.ink,
      tertiaryFixed: BrandColors.light.bg2,
      tertiaryFixedDim: BrandColors.light.bg2,
      onTertiaryFixed: c.navy,
      onTertiaryFixedVariant: c.navy,
      // a caixa de erro é o fundo 2 com o texto em danger: o Design System não
      // tem um vermelho suave
      error: c.danger,
      onError: claro ? c.onBrand : c.navy,
      errorContainer: c.bg2,
      onErrorContainer: c.danger,
      surface: c.bg,
      onSurface: c.ink,
      onSurfaceVariant: c.inkMuted,
      surfaceDim: claro ? c.bg2 : c.bg,
      surfaceBright: claro ? c.bg : c.bg2,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.bg,
      surfaceContainer: c.bg2,
      surfaceContainerHigh: c.bg2,
      surfaceContainerHighest: c.bg2,
      // borda é só contorno: nunca para texto ou ícone
      outline: c.border,
      outlineVariant: c.border,
      shadow: claro ? c.navy : Colors.black,
      scrim: claro ? c.navy : Colors.black,
      inverseSurface: claro ? c.navy : c.ink,
      onInverseSurface: claro ? c.onBrand : c.navy,
      inversePrimary: claro ? BrandColors.dark.blue : BrandColors.light.blue,
      // tudo flat: sem o tom azulado que o Material põe na elevação
      surfaceTint: Colors.transparent,
    );
  }

  static ThemeData _tema(BrandColors c, Brightness brilho) {
    final claro = brilho == Brightness.light;
    final cores = colorScheme(c, brilho);
    final textos = BrandText.textTheme(c);
    final bordaFina = BorderSide(color: c.border);

    // o que flutua sobre a página (diálogo, folha, menu): no claro é o branco
    // sobre o véu; no escuro, o fundo 2, que se destaca do marinho
    final superficieFlutuante = claro ? c.bg : c.bg2;

    // padding interno dos botões: space-3 na vertical, space-5 dos lados
    const paddingDeBotao = EdgeInsets.symmetric(
      horizontal: BrandSpacing.space5,
      vertical: BrandSpacing.space3,
    );
    const formaDeBotao = RoundedRectangleBorder(
      borderRadius: BrandRadius.mdAll,
    );

    OutlineInputBorder bordaDeCampo(Color cor, {double largura = 1}) {
      return OutlineInputBorder(
        borderRadius: BrandRadius.smAll,
        borderSide: BorderSide(color: cor, width: largura),
      );
    }

    // ícone do campo: azul no foco, danger no erro, cinza no resto
    final corDoIconeDoCampo = WidgetStateColor.resolveWith((estados) {
      if (estados.contains(WidgetState.error)) return c.danger;
      if (estados.contains(WidgetState.focused)) return c.blue;
      return c.inkMuted;
    });

    return ThemeData(
      useMaterial3: true,
      brightness: brilho,
      colorScheme: cores,
      extensions: [c],
      fontFamily: BrandText.sans,
      textTheme: textos,
      primaryTextTheme: textos.apply(
        bodyColor: c.onBrand,
        displayColor: c.onBrand,
      ),
      scaffoldBackgroundColor: c.bg,
      // o menu do DropdownButton é desenhado no canvasColor: ele flutua, então
      // no escuro é o fundo 2, como o diálogo e a folha
      canvasColor: superficieFlutuante,
      dividerColor: c.border,
      hintColor: c.inkMuted,
      iconTheme: IconThemeData(color: c.ink),
      primaryIconTheme: IconThemeData(color: c.onBrand),
      appBarTheme: AppBarThemeData(
        // a barra é o fundo da página; quando o conteúdo passa por baixo, ela
        // vira o fundo 2, sem sombra
        backgroundColor: WidgetStateColor.resolveWith(
          (estados) =>
              estados.contains(WidgetState.scrolledUnder) ? c.bg2 : c.bg,
        ),
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: BrandText.h3.copyWith(color: c.ink),
        toolbarTextStyle: BrandText.body.copyWith(color: c.ink),
        iconTheme: IconThemeData(color: c.ink),
        actionsIconTheme: IconThemeData(color: c.ink),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: claro ? Brightness.dark : Brightness.light,
          statusBarBrightness: claro ? Brightness.light : Brightness.dark,
        ),
      ),
      // botão primário: o azul da marca com texto branco nos dois temas
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BrandColors.brandBlue,
          foregroundColor: c.onBrand,
          textStyle: BrandText.bodyStrong,
          padding: paddingDeBotao,
          shape: formaDeBotao,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandColors.brandBlue,
          foregroundColor: c.onBrand,
          textStyle: BrandText.bodyStrong,
          padding: paddingDeBotao,
          shape: formaDeBotao,
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      // secundário: contornado, texto em ink
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: bordaFina,
          textStyle: BrandText.bodyStrong,
          padding: paddingDeBotao,
          shape: formaDeBotao,
        ),
      ),
      // o link: texto azul
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.blue,
          textStyle: BrandText.bodyStrong,
          padding: const EdgeInsets.symmetric(
            horizontal: BrandSpacing.space3,
            vertical: BrandSpacing.space2,
          ),
          shape: formaDeBotao,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: BrandColors.brandBlue,
        foregroundColor: c.onBrand,
        elevation: _elevacaoFlutuante,
        focusElevation: _elevacaoFlutuante,
        hoverElevation: _elevacaoFlutuante,
        highlightElevation: _elevacaoFlutuante,
        shape: formaDeBotao,
        extendedTextStyle: BrandText.bodyStrong,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          foregroundColor: c.ink,
          selectedForegroundColor: c.ink,
          selectedBackgroundColor: c.blueSoft,
          side: bordaFina,
          textStyle: BrandText.label,
          shape: formaDeBotao,
        ),
      ),
      // campos: fundo 2, borda fina, raio sm e foco no azul
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: c.bg2,
        contentPadding: const EdgeInsets.all(BrandSpacing.space3),
        border: bordaDeCampo(c.border),
        enabledBorder: bordaDeCampo(c.border),
        disabledBorder: bordaDeCampo(c.border),
        focusedBorder: bordaDeCampo(c.blue, largura: 2),
        errorBorder: bordaDeCampo(c.danger),
        focusedErrorBorder: bordaDeCampo(c.danger, largura: 2),
        labelStyle: BrandText.body.copyWith(color: c.inkMuted),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((estados) {
          if (estados.contains(WidgetState.error)) {
            return BrandText.label.copyWith(color: c.danger);
          }
          if (estados.contains(WidgetState.focused)) {
            return BrandText.label.copyWith(color: c.blue);
          }
          return BrandText.label.copyWith(color: c.inkMuted);
        }),
        hintStyle: BrandText.body.copyWith(color: c.inkMuted),
        helperStyle: BrandText.caption.copyWith(color: c.inkMuted),
        errorStyle: BrandText.caption.copyWith(color: c.danger),
        counterStyle: BrandText.caption.copyWith(color: c.inkMuted),
        prefixStyle: BrandText.body.copyWith(color: c.ink),
        suffixStyle: BrandText.body.copyWith(color: c.ink),
        iconColor: c.inkMuted,
        prefixIconColor: corDoIconeDoCampo,
        suffixIconColor: corDoIconeDoCampo,
      ),
      // cartão: fundo da página com borda, sem sombra
      cardTheme: CardThemeData(
        color: c.bg,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BrandRadius.mdAll,
          side: bordaFina,
        ),
        clipBehavior: Clip.antiAlias,
      ),
      // chip: raio sm; o selecionado é o azul suave
      chipTheme: ChipThemeData(
        backgroundColor: c.bg,
        selectedColor: c.blueSoft,
        disabledColor: c.bg2,
        side: WidgetStateBorderSide.resolveWith(
          (estados) => estados.contains(WidgetState.selected)
              ? BorderSide(color: c.blueSoft)
              : bordaFina,
        ),
        shape: const RoundedRectangleBorder(borderRadius: BrandRadius.smAll),
        labelStyle: BrandText.label.copyWith(color: c.ink),
        secondaryLabelStyle: BrandText.label.copyWith(color: c.ink),
        checkmarkColor: c.blue,
        deleteIconColor: c.inkMuted,
        iconTheme: IconThemeData(color: c.inkMuted),
        elevation: 0,
        pressElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: superficieFlutuante,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BrandRadius.lgAll),
        titleTextStyle: BrandText.h3.copyWith(color: c.ink),
        contentTextStyle: BrandText.body.copyWith(color: c.inkMuted),
        iconColor: c.inkMuted,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: superficieFlutuante,
        modalBackgroundColor: superficieFlutuante,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BrandRadius.lgTop),
        clipBehavior: Clip.antiAlias,
        dragHandleColor: c.border,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: superficieFlutuante,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        indicatorColor: c.blueSoft,
        iconTheme: WidgetStateProperty.resolveWith(
          (estados) => IconThemeData(
            color: estados.contains(WidgetState.selected) ? c.blue : c.inkMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (estados) => BrandText.label.copyWith(
            color: estados.contains(WidgetState.selected) ? c.blue : c.inkMuted,
          ),
        ),
      ),
      // o aviso de baixo: marinho no claro; no escuro, o fundo 2 com borda.
      // a ação é o azul do tema escuro, que dá 5:1 sobre os dois fundos
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: claro ? c.navy : c.bg2,
        contentTextStyle: BrandText.body.copyWith(
          color: claro ? c.onBrand : c.ink,
        ),
        actionTextColor: BrandColors.dark.blue,
        closeIconColor: claro ? c.onBrand : c.inkMuted,
        elevation: _elevacaoFlutuante,
        shape: RoundedRectangleBorder(
          borderRadius: BrandRadius.mdAll,
          side: claro ? BorderSide.none : bordaFina,
        ),
        insetPadding: const EdgeInsets.fromLTRB(
          BrandSpacing.space4,
          BrandSpacing.space1,
          BrandSpacing.space4,
          BrandSpacing.space3,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: BrandSpacing.space4,
      ),
      // linha de lista: o nome em body-strong, o detalhe em inkMuted; a linha
      // selecionada é o azul suave. sem textColor: o ListTile pinta com ele o
      // título, o detalhe e as pontas, e o detalhe perderia o inkMuted
      listTileTheme: ListTileThemeData(
        iconColor: c.inkMuted,
        titleTextStyle: BrandText.bodyStrong.copyWith(color: c.ink),
        subtitleTextStyle: BrandText.body.copyWith(color: c.inkMuted),
        leadingAndTrailingTextStyle: BrandText.label.copyWith(
          color: c.inkMuted,
        ),
        selectedColor: c.blue,
        selectedTileColor: c.blueSoft,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((estados) {
          if (estados.contains(WidgetState.disabled)) return null;
          if (estados.contains(WidgetState.selected)) return cores.onPrimary;
          return c.inkMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((estados) {
          if (estados.contains(WidgetState.disabled)) return null;
          if (estados.contains(WidgetState.selected)) return c.blue;
          return c.bg2;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((estados) {
          if (estados.contains(WidgetState.disabled)) return null;
          if (estados.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return c.inkMuted;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((estados) {
          if (estados.contains(WidgetState.disabled)) return null;
          if (estados.contains(WidgetState.selected)) return c.blue;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(cores.onPrimary),
        side: WidgetStateBorderSide.resolveWith((estados) {
          if (estados.contains(WidgetState.disabled) ||
              estados.contains(WidgetState.selected)) {
            return null;
          }
          return BorderSide(color: c.inkMuted, width: 2);
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((estados) {
          if (estados.contains(WidgetState.disabled)) return null;
          if (estados.contains(WidgetState.selected)) return c.blue;
          return c.inkMuted;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.blue,
        linearTrackColor: c.bg2,
        circularTrackColor: Colors.transparent,
        refreshBackgroundColor: superficieFlutuante,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.blue,
        selectionColor: c.blueSoft,
        selectionHandleColor: c.blue,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.blue,
        unselectedLabelColor: c.inkMuted,
        indicatorColor: c.blue,
        dividerColor: c.border,
        labelStyle: BrandText.label,
        unselectedLabelStyle: BrandText.label,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: c.danger,
        textColor: cores.onError,
        textStyle: BrandText.caption,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: claro ? c.navy : c.bg2,
          borderRadius: BrandRadius.smAll,
        ),
        textStyle: BrandText.caption.copyWith(color: claro ? c.onBrand : c.ink),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: superficieFlutuante,
        surfaceTintColor: Colors.transparent,
        shadowColor: cores.shadow,
        elevation: _elevacaoFlutuante,
        shape: RoundedRectangleBorder(
          borderRadius: BrandRadius.mdAll,
          side: bordaFina,
        ),
        textStyle: BrandText.body.copyWith(color: c.ink),
        labelTextStyle: WidgetStatePropertyAll(
          BrandText.body.copyWith(color: c.ink),
        ),
        iconColor: c.inkMuted,
      ),
      menuTheme: MenuThemeData(style: _estiloDeMenu(c, superficieFlutuante)),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: BrandText.body.copyWith(color: c.ink),
        menuStyle: _estiloDeMenu(c, superficieFlutuante),
      ),
      // calendário: o dia escolhido é o azul da marca com número branco;
      // hoje tem contorno azul; o intervalo entre as pontas é o azul suave
      datePickerTheme: DatePickerThemeData(
        backgroundColor: superficieFlutuante,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BrandRadius.lgAll),
        headerBackgroundColor: superficieFlutuante,
        headerForegroundColor: c.ink,
        dividerColor: c.border,
        weekdayStyle: BrandText.label.copyWith(color: c.inkMuted),
        dayStyle: BrandText.body,
        dayForegroundColor: _corDoDia(selecionado: c.onBrand, normal: c.ink),
        dayBackgroundColor: _fundoDoDia(),
        todayForegroundColor: _corDoDia(selecionado: c.onBrand, normal: c.blue),
        todayBackgroundColor: _fundoDoDia(),
        todayBorder: BorderSide(color: c.blue),
        yearForegroundColor: _corDoDia(selecionado: c.onBrand, normal: c.ink),
        yearBackgroundColor: _fundoDoDia(),
        rangePickerBackgroundColor: superficieFlutuante,
        rangePickerSurfaceTintColor: Colors.transparent,
        rangePickerHeaderBackgroundColor: superficieFlutuante,
        rangePickerHeaderForegroundColor: c.ink,
        rangeSelectionBackgroundColor: c.blueSoft,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: superficieFlutuante,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BrandRadius.lgAll),
        dialBackgroundColor: claro ? c.bg2 : c.bg,
        dialHandColor: BrandColors.brandBlue,
        dialTextColor: WidgetStateColor.resolveWith(
          (estados) =>
              estados.contains(WidgetState.selected) ? c.onBrand : c.ink,
        ),
        hourMinuteColor: WidgetStateColor.resolveWith(
          (estados) => estados.contains(WidgetState.selected)
              ? c.blueSoft
              : (claro ? c.bg2 : c.bg),
        ),
        hourMinuteTextColor: c.ink,
        dayPeriodColor: WidgetStateColor.resolveWith(
          (estados) => estados.contains(WidgetState.selected)
              ? c.blueSoft
              : Colors.transparent,
        ),
        dayPeriodTextColor: c.ink,
        dayPeriodBorderSide: bordaFina,
        entryModeIconColor: c.inkMuted,
        helpTextStyle: BrandText.label.copyWith(color: c.inkMuted),
      ),
    );
  }

  static MenuStyle _estiloDeMenu(BrandColors c, Color fundo) {
    return MenuStyle(
      backgroundColor: WidgetStatePropertyAll(fundo),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(_elevacaoFlutuante),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BrandRadius.mdAll,
          side: BorderSide(color: c.border),
        ),
      ),
    );
  }

  // o dia desabilitado devolve null e fica com o cinza padrão do calendário
  static WidgetStateProperty<Color?> _corDoDia({
    required Color selecionado,
    required Color normal,
  }) {
    return WidgetStateProperty.resolveWith((estados) {
      if (estados.contains(WidgetState.disabled)) return null;
      if (estados.contains(WidgetState.selected)) return selecionado;
      return normal;
    });
  }

  static WidgetStateProperty<Color?> _fundoDoDia() {
    return WidgetStateProperty.resolveWith(
      (estados) =>
          estados.contains(WidgetState.selected) ? BrandColors.brandBlue : null,
    );
  }
}
