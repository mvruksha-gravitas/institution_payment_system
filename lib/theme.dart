import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show PointerDeviceKind;

// Theme extension to carry gradients across the app
class AppGradients extends ThemeExtension<AppGradients> {
  final LinearGradient primary;
  final LinearGradient primaryContainer;
  const AppGradients({required this.primary, required this.primaryContainer});
  @override
  AppGradients copyWith({LinearGradient? primary, LinearGradient? primaryContainer}) => AppGradients(primary: primary ?? this.primary, primaryContainer: primaryContainer ?? this.primaryContainer);
  @override
  AppGradients lerp(ThemeExtension<AppGradients>? other, double t) {
    if (other is! AppGradients) return this;
    return AppGradients(
      primary: LinearGradient(
        colors: List<Color>.generate(2, (i) => Color.lerp(primary.colors[i], other.primary.colors[i], t) ?? primary.colors[i]),
        begin: primary.begin,
        end: primary.end,
      ),
      primaryContainer: LinearGradient(
        colors: List<Color>.generate(2, (i) => Color.lerp(primaryContainer.colors[i], other.primaryContainer.colors[i], t) ?? primaryContainer.colors[i]),
        begin: primaryContainer.begin,
        end: primaryContainer.end,
      ),
    );
  }
}

// Smooth, unified scroll across devices (mouse, touch, trackpad)
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.stylus, PointerDeviceKind.trackpad};
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

class AppBrand {
  // Indigo → Blue palette
  static const Color primary = Color(0xFF2563EB); // Blue 600
  static const Color secondary = Color(0xFF4F46E5); // Indigo 600
  static const Color background = Color(0xFFF9FAFB); // Light neutral gray
  static const Color card = Color(0xFFFFFFFF);
  static const Color textHeading = Color(0xFF111827);
  static const Color textBody = Color(0xFF374151);
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

ThemeData _brandTheme(Brightness brightness) {
  // Seeded scheme from green primary
  final baseScheme = ColorScheme.fromSeed(seedColor: AppBrand.primary, brightness: brightness);
  final scheme = baseScheme.copyWith(
    primary: AppBrand.primary,
    secondary: AppBrand.secondary,
    error: AppBrand.error,
    surface: AppBrand.card,
    onSurface: AppBrand.textBody,
    onSurfaceVariant: AppBrand.textBody.withValues(alpha: 0.80),
    surfaceTint: AppBrand.secondary,
  );
  final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);

  // Typography (kept as-is): Inter for body; Poppins for headings
  final inter = GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: AppBrand.textBody, displayColor: AppBrand.textHeading);
  TextStyle pop(TextStyle? s) => GoogleFonts.poppins(textStyle: (s ?? const TextStyle())).copyWith(fontWeight: FontWeight.w700, color: AppBrand.textHeading);
  final text = inter.copyWith(
    displayLarge: pop(inter.displayLarge),
    displayMedium: pop(inter.displayMedium),
    displaySmall: pop(inter.displaySmall),
    headlineLarge: pop(inter.headlineLarge),
    headlineMedium: pop(inter.headlineMedium),
    headlineSmall: pop(inter.headlineSmall),
    titleLarge: pop(inter.titleLarge),
    titleMedium: pop(inter.titleMedium),
  );

  // Gentle green gradient for hero/app bars
  final gradients = AppGradients(
    primary: const LinearGradient(colors: [AppBrand.secondary, AppBrand.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
    primaryContainer: LinearGradient(colors: [AppBrand.secondary.withValues(alpha: 0.85), AppBrand.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
  );

  return base.copyWith(
    extensions: [gradients],
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: AppBrand.background,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.primary,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(color: Colors.white),
      systemOverlayStyle: brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      color: AppBrand.card,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      surfaceTintColor: scheme.surfaceTint,
      shadowColor: Colors.black.withValues(alpha: 0.10),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppBrand.card,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        surfaceTintColor: WidgetStatePropertyAll(scheme.surfaceTint),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        elevation: const WidgetStatePropertyAll(8),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppBrand.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.25)), borderRadius: BorderRadius.circular(16)),
      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: scheme.primary), borderRadius: BorderRadius.circular(16)),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.primary.withValues(alpha: 0.10),
      selectedColor: scheme.secondary.withValues(alpha: 0.14),
      labelStyle: TextStyle(color: scheme.onSurface),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: StadiumBorder(side: BorderSide(color: scheme.outline.withValues(alpha: 0.20))),
    ),
    // Buttons: Primary Green across the app
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: text.labelLarge,
        elevation: 0,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: text.labelLarge,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.primary),
        foregroundColor: scheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: text.labelLarge,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white.withValues(alpha: 0.80),
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: const UnderlineTabIndicator(borderSide: BorderSide(color: Colors.white, width: 3)),
      labelStyle: text.titleSmall,
      unselectedLabelStyle: text.titleSmall,
    ),
    listTileTheme: ListTileThemeData(iconColor: scheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), thickness: 1),
    floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: scheme.primary, foregroundColor: Colors.white),
  );
}

ThemeData get lightTheme => _brandTheme(Brightness.light);
ThemeData get darkTheme => _brandTheme(Brightness.dark);
