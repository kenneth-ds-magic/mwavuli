import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// mwavuli design system — earth-toned palette, Roboto typography,
/// rounded nature-friendly components. Mirrors the interactive prototype.
///
/// Raw palette tokens. Prefer reading semantic tokens from
/// `Theme.of(context).extension<MwavuliColors>()` inside widgets.
abstract final class Palette {
  // Forest greens
  static const green900 = Color(0xFF14300D);
  static const green800 = Color(0xFF1F4715);
  static const green700 = Color(0xFF2F6A21); // primary
  static const green600 = Color(0xFF3C7D2B);
  static const green500 = Color(0xFF4C9138);
  static const green300 = Color(0xFF8BBF78);
  static const green100 = Color(0xFFDCECD3);
  static const green50 = Color(0xFFEEF6E9);

  // Warm browns / bark
  static const brown800 = Color(0xFF3D2A17);
  static const brown700 = Color(0xFF5A3D22);
  static const brown600 = Color(0xFF7A542F);
  static const brown500 = Color(0xFF9A6C3F);

  // Creams / surfaces
  static const cream50 = Color(0xFFFAF7EF);
  static const cream100 = Color(0xFFF4EDDD);
  static const cream200 = Color(0xFFE9DFC9);

  // Ink
  static const ink = Color(0xFF241D14);
  static const ink2 = Color(0xFF4F4536);
  static const ink3 = Color(0xFF77694F);
  static const inkInv = Color(0xFFFBF9F3);

  // Accent gold (achievements)
  static const gold700 = Color(0xFF8A6508);
  static const gold600 = Color(0xFFB8860B);
  static const gold500 = Color(0xFFD4A017);
  static const gold400 = Color(0xFFE6BD3F);
  static const gold100 = Color(0xFFF7ECC9);

  // Status
  static const ok = Color(0xFF3C7D2B);
  static const warn = Color(0xFFB8860B);
  static const danger = Color(0xFFA5341F);

  // Categorical (species/data viz) — order-fixed, never cycled
  static const cat = <Color>[
    green700, brown600, gold600, green500, brown500, Color(0xFF5C7D8A),
  ];
}

/// Design constants.
abstract final class Dims {
  static const double radius = 16;
  static const double radiusSm = 10;
  static const double radiusLg = 24;
  static const double radiusPill = 999;
  static const double tap = 44; // min touch target (thumb-zone / a11y)
  static const double gutter = 18;
}

/// Semantic color tokens that don't fit Material's [ColorScheme].
@immutable
class MwavuliColors extends ThemeExtension<MwavuliColors> {
  const MwavuliColors({
    required this.gold,
    required this.goldSoft,
    required this.goldInk,
    required this.brown,
    required this.brownPill,
    required this.cream,
    required this.creamSunk,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.categorical,
  });

  final Color gold; // gold500 — badges, achievements
  final Color goldSoft; // gold100 fill
  final Color goldInk; // gold700 text on soft gold
  final Color brown; // bark / secondary accent
  final Color brownPill;
  final Color cream; // app background surface
  final Color creamSunk; // segmented / inset fills
  final Color ink2; // secondary text
  final Color ink3; // tertiary/muted text
  final Color line; // hairline borders
  final List<Color> categorical;

  static const light = MwavuliColors(
    gold: Palette.gold500,
    goldSoft: Palette.gold100,
    goldInk: Palette.gold700,
    brown: Palette.brown600,
    brownPill: Color(0xFFEFE2CF),
    cream: Palette.cream50,
    creamSunk: Palette.cream100,
    ink2: Palette.ink2,
    ink3: Palette.ink3,
    line: Color(0x24241D14), // ~14% ink
    categorical: Palette.cat,
  );

  /// High-contrast variant (WCAG AAA-leaning): darker greens, stronger lines.
  static const highContrast = MwavuliColors(
    gold: Palette.gold600,
    goldSoft: Palette.gold100,
    goldInk: Color(0xFF5C4405),
    brown: Palette.brown700,
    brownPill: Color(0xFFE7D6BE),
    cream: Palette.cream50,
    creamSunk: Palette.cream100,
    ink2: Color(0xFF1A140C),
    ink3: Color(0xFF33291A),
    line: Color(0x73140F08), // ~45% ink
    categorical: Palette.cat,
  );

  @override
  MwavuliColors copyWith({
    Color? gold,
    Color? goldSoft,
    Color? goldInk,
    Color? brown,
    Color? brownPill,
    Color? cream,
    Color? creamSunk,
    Color? ink2,
    Color? ink3,
    Color? line,
    List<Color>? categorical,
  }) {
    return MwavuliColors(
      gold: gold ?? this.gold,
      goldSoft: goldSoft ?? this.goldSoft,
      goldInk: goldInk ?? this.goldInk,
      brown: brown ?? this.brown,
      brownPill: brownPill ?? this.brownPill,
      cream: cream ?? this.cream,
      creamSunk: creamSunk ?? this.creamSunk,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      line: line ?? this.line,
      categorical: categorical ?? this.categorical,
    );
  }

  @override
  MwavuliColors lerp(MwavuliColors? other, double t) {
    if (other == null) return this;
    return MwavuliColors(
      gold: Color.lerp(gold, other.gold, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      goldInk: Color.lerp(goldInk, other.goldInk, t)!,
      brown: Color.lerp(brown, other.brown, t)!,
      brownPill: Color.lerp(brownPill, other.brownPill, t)!,
      cream: Color.lerp(cream, other.cream, t)!,
      creamSunk: Color.lerp(creamSunk, other.creamSunk, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      line: Color.lerp(line, other.line, t)!,
      categorical: categorical,
    );
  }
}

/// Convenience accessor: `context.earth.gold`.
extension MwavuliThemeX on BuildContext {
  MwavuliColors get earth =>
      Theme.of(this).extension<MwavuliColors>() ?? MwavuliColors.light;
}

abstract final class AppTheme {
  static ThemeData build({bool highContrast = false}) {
    final earth = highContrast ? MwavuliColors.highContrast : MwavuliColors.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: Palette.green700,
      primary: highContrast ? Palette.green800 : Palette.green700,
      onPrimary: Colors.white,
      secondary: Palette.brown600,
      surface: earth.cream,
      onSurface: Palette.ink,
      error: Palette.danger,
    );

    // Roboto body + Roboto Slab display, via google_fonts.
    final base = GoogleFonts.robotoTextTheme();
    final slab = GoogleFonts.robotoSlab();
    final textTheme = base.copyWith(
      displaySmall: slab.copyWith(
          color: Palette.green900, fontWeight: FontWeight.w700),
      headlineSmall: slab.copyWith(
          color: Palette.green900, fontWeight: FontWeight.w700),
      titleLarge: slab.copyWith(
          color: Palette.green900, fontWeight: FontWeight.w700, fontSize: 21),
      titleMedium: base.titleMedium
          ?.copyWith(color: Palette.ink, fontWeight: FontWeight.w700),
      bodyLarge: base.bodyLarge?.copyWith(color: Palette.ink, height: 1.45),
      bodyMedium: base.bodyMedium?.copyWith(color: earth.ink2, height: 1.5),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ).apply(bodyColor: Palette.ink, displayColor: Palette.green900);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: earth.cream,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      extensions: <ThemeExtension<dynamic>>[earth],

      appBarTheme: AppBarTheme(
        backgroundColor: earth.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(Dims.tap),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Palette.green800,
          backgroundColor: Colors.white,
          minimumSize: const Size.fromHeight(Dims.tap),
          side: const BorderSide(color: Palette.green300, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dims.radius),
          side: BorderSide(color: earth.line),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: scheme.primary,
        side: BorderSide(color: earth.line),
        labelStyle: textTheme.bodyMedium!
            .copyWith(fontWeight: FontWeight.w500, color: earth.ink2),
        secondaryLabelStyle:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dims.radiusPill),
          borderSide: BorderSide(color: earth.line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dims.radiusPill),
          borderSide: BorderSide(color: earth.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dims.radiusPill),
          borderSide: const BorderSide(color: Palette.green500, width: 2),
        ),
        hintStyle: TextStyle(color: earth.ink3),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 74,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Palette.green700 : earth.ink3,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
              color: selected ? Palette.green700 : earth.ink3, size: 25);
        }),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Palette.green600 : null),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Palette.green300 : null),
      ),

      dividerTheme: DividerThemeData(color: earth.line, thickness: 1, space: 1),
    );
  }
}
