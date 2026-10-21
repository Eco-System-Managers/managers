import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff002b80),
      surfaceTint: Color(0xff2a56c7),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff003fb1),
      onPrimaryContainer: Color(0xffa1b6ff),
      secondary: Color(0xff000000),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff1a1b21),
      onSecondaryContainer: Color(0xff82838a),
      tertiary: Color(0xff434c5b),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff5b6474),
      onTertiaryContainer: Color(0xffd8e1f4),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff93000a),
      surface: Color(0xfffaf8ff),
      onSurface: Color(0xff1a1b22),
      onSurfaceVariant: Color(0xff434653),
      outline: Color(0xff747685),
      outlineVariant: Color(0xffc4c6d6),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2f3038),
      inversePrimary: Color(0xffb5c4ff),
      primaryFixed: Color(0xffdbe1ff),
      onPrimaryFixed: Color(0xff00174c),
      primaryFixedDim: Color(0xffb5c4ff),
      onPrimaryFixedVariant: Color(0xff003dab),
      secondaryFixed: Color(0xffe2e2e9),
      onSecondaryFixed: Color(0xff1a1b21),
      secondaryFixedDim: Color(0xffc6c6cd),
      onSecondaryFixedVariant: Color(0xff45474c),
      tertiaryFixed: Color(0xffdae3f6),
      onTertiaryFixed: Color(0xff131c29),
      tertiaryFixedDim: Color(0xffbec7d9),
      onTertiaryFixedVariant: Color(0xff3e4756),
      surfaceDim: Color(0xffd9d9e3),
      surfaceBright: Color(0xfffaf8ff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff3f3fd),
      surfaceContainer: Color(0xffededf7),
      surfaceContainerHigh: Color(0xffe8e7f1),
      surfaceContainerHighest: Color(0xffe2e1eb),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff002b80),
      surfaceTint: Color(0xff2a56c7),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff003fb1),
      onPrimaryContainer: Color(0xffdee3ff),
      secondary: Color(0xff000000),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff1a1b21),
      onSecondaryContainer: Color(0xffa6a6ad),
      tertiary: Color(0xff2e3745),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff5b6474),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff740006),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffcf2c27),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffaf8ff),
      onSurface: Color(0xff0f1118),
      onSurfaceVariant: Color(0xff333642),
      outline: Color(0xff4f525f),
      outlineVariant: Color(0xff6a6c7a),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2f3038),
      inversePrimary: Color(0xffb5c4ff),
      primaryFixed: Color(0xff3c66d7),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff1b4cbd),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff6b6d73),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff53555b),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff646d7e),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff4c5565),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffc6c6cf),
      surfaceBright: Color(0xfffaf8ff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff3f3fd),
      surfaceContainer: Color(0xffe8e7f1),
      surfaceContainerHigh: Color(0xffdcdce6),
      surfaceContainerHighest: Color(0xffd1d1db),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff002571),
      surfaceTint: Color(0xff2a56c7),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff003fb1),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff000000),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff1a1b21),
      onSecondaryContainer: Color(0xffcfd0d7),
      tertiary: Color(0xff242d3b),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff414a59),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff600004),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff98000a),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffaf8ff),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff000000),
      outline: Color(0xff292c38),
      outlineVariant: Color(0xff464956),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2f3038),
      inversePrimary: Color(0xffb5c4ff),
      primaryFixed: Color(0xff003fb0),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff002b7f),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff47494f),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff313338),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff414a59),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff2a3341),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffb8b8c1),
      surfaceBright: Color(0xfffaf8ff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff0f0fa),
      surfaceContainer: Color(0xffe2e1eb),
      surfaceContainerHigh: Color(0xffd4d3dd),
      surfaceContainerHighest: Color(0xffc6c6cf),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffb5c4ff),
      surfaceTint: Color(0xffb5c4ff),
      onPrimary: Color(0xff00297a),
      primaryContainer: Color(0xff003fb1),
      onPrimaryContainer: Color(0xffa1b6ff),
      secondary: Color(0xffc6c6cd),
      onSecondary: Color(0xff2e3036),
      secondaryContainer: Color(0xff14161b),
      onSecondaryContainer: Color(0xff7e7f86),
      tertiary: Color(0xffbec7d9),
      onTertiary: Color(0xff28313f),
      tertiaryContainer: Color(0xff5b6474),
      onTertiaryContainer: Color(0xffd8e1f4),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff11131a),
      onSurface: Color(0xffe2e1eb),
      onSurfaceVariant: Color(0xffc4c6d6),
      outline: Color(0xff8e909f),
      outlineVariant: Color(0xff434653),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe2e1eb),
      inversePrimary: Color(0xff2a56c7),
      primaryFixed: Color(0xffdbe1ff),
      onPrimaryFixed: Color(0xff00174c),
      primaryFixedDim: Color(0xffb5c4ff),
      onPrimaryFixedVariant: Color(0xff003dab),
      secondaryFixed: Color(0xffe2e2e9),
      onSecondaryFixed: Color(0xff1a1b21),
      secondaryFixedDim: Color(0xffc6c6cd),
      onSecondaryFixedVariant: Color(0xff45474c),
      tertiaryFixed: Color(0xffdae3f6),
      onTertiaryFixed: Color(0xff131c29),
      tertiaryFixedDim: Color(0xffbec7d9),
      onTertiaryFixedVariant: Color(0xff3e4756),
      surfaceDim: Color(0xff11131a),
      surfaceBright: Color(0xff373940),
      surfaceContainerLowest: Color(0xff0c0e15),
      surfaceContainerLow: Color(0xff1a1b22),
      surfaceContainer: Color(0xff1e1f26),
      surfaceContainerHigh: Color(0xff282a31),
      surfaceContainerHighest: Color(0xff33343c),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffd3dbff),
      surfaceTint: Color(0xffb5c4ff),
      onPrimary: Color(0xff001f63),
      primaryContainer: Color(0xff648afd),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xffdcdce3),
      onSecondary: Color(0xff24262b),
      secondaryContainer: Color(0xff8f9097),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xffd4ddef),
      onTertiary: Color(0xff1d2634),
      tertiaryContainer: Color(0xff8891a2),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xffffd2cc),
      onError: Color(0xff540003),
      errorContainer: Color(0xffff5449),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff11131a),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffdadbec),
      outline: Color(0xffafb1c1),
      outlineVariant: Color(0xff8d909e),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe2e1eb),
      inversePrimary: Color(0xff003eae),
      primaryFixed: Color(0xffdbe1ff),
      onPrimaryFixed: Color(0xff000d36),
      primaryFixedDim: Color(0xffb5c4ff),
      onPrimaryFixedVariant: Color(0xff002e87),
      secondaryFixed: Color(0xffe2e2e9),
      onSecondaryFixed: Color(0xff0f1116),
      secondaryFixedDim: Color(0xffc6c6cd),
      onSecondaryFixedVariant: Color(0xff34363c),
      tertiaryFixed: Color(0xffdae3f6),
      onTertiaryFixed: Color(0xff08111e),
      tertiaryFixedDim: Color(0xffbec7d9),
      onTertiaryFixedVariant: Color(0xff2e3745),
      surfaceDim: Color(0xff11131a),
      surfaceBright: Color(0xff43444c),
      surfaceContainerLowest: Color(0xff06070d),
      surfaceContainerLow: Color(0xff1c1d24),
      surfaceContainer: Color(0xff26282f),
      surfaceContainerHigh: Color(0xff31323a),
      surfaceContainerHighest: Color(0xff3c3d45),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme());
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffeeefff),
      surfaceTint: Color(0xffb5c4ff),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xffafc0ff),
      onPrimaryContainer: Color(0xff000829),
      secondary: Color(0xffefeff7),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xffc2c2c9),
      onSecondaryContainer: Color(0xff090b10),
      tertiary: Color(0xffeaf0ff),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xffbac3d5),
      onTertiaryContainer: Color(0xff030b18),
      error: Color(0xffffece9),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffaea4),
      onErrorContainer: Color(0xff220001),
      surface: Color(0xff11131a),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffffffff),
      outline: Color(0xffeeefff),
      outlineVariant: Color(0xffc0c2d2),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe2e1eb),
      inversePrimary: Color(0xff003eae),
      primaryFixed: Color(0xffdbe1ff),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xffb5c4ff),
      onPrimaryFixedVariant: Color(0xff000d36),
      secondaryFixed: Color(0xffe2e2e9),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xffc6c6cd),
      onSecondaryFixedVariant: Color(0xff0f1116),
      tertiaryFixed: Color(0xffdae3f6),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xffbec7d9),
      onTertiaryFixedVariant: Color(0xff08111e),
      surfaceDim: Color(0xff11131a),
      surfaceBright: Color(0xff4e5058),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff1e1f26),
      surfaceContainer: Color(0xff2f3038),
      surfaceContainerHigh: Color(0xff3a3b43),
      surfaceContainerHighest: Color(0xff45464e),
    );
  }

  ThemeData darkHighContrast() {
    return theme(darkHighContrastScheme());
  }


  ThemeData theme(ColorScheme colorScheme) => ThemeData(
     useMaterial3: true,
     brightness: colorScheme.brightness,
     colorScheme: colorScheme,
     textTheme: textTheme.apply(
       bodyColor: colorScheme.onSurface,
       displayColor: colorScheme.onSurface,
     ),
     scaffoldBackgroundColor: colorScheme.surface,
     canvasColor: colorScheme.surface,
  );


  List<ExtendedColor> get extendedColors => [
  ];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
