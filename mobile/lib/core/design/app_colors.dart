import 'dart:ui';

/// Semantic colours. Widgets ask for a role ("surface", "cash"), never for a
/// hex value, so the light and dark themes stay in step.
final class AppColors {
  const AppColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.onAccent,
    required this.hero,
    required this.onHero,
    required this.onHeroMuted,
    required this.heroDivider,
    required this.cash,
    required this.card,
    required this.error,
    required this.errorSurface,
    required this.success,
    required this.successSurface,
    required this.scrim,
    required this.shadow,
  });

  final Brightness brightness;

  /// The page behind everything.
  final Color background;

  /// Cards, sheets, input fields.
  final Color surface;

  /// Pressed states, secondary buttons, skeletons, tracks.
  final Color surfaceMuted;
  final Color border;

  final Color text;
  final Color textMuted;
  final Color textFaint;

  /// The one loud colour: the primary action and the selected day.
  final Color accent;
  final Color onAccent;

  /// The "take-home" card.
  final Color hero;
  final Color onHero;
  final Color onHeroMuted;
  final Color heroDivider;

  /// Payment kinds, used consistently in the split bar, the list and the form.
  final Color cash;
  final Color card;

  final Color error;
  final Color errorSurface;
  final Color success;
  final Color successSurface;

  /// Behind a sheet.
  final Color scrim;
  final Color shadow;

  static const light = AppColors(
    brightness: Brightness.light,
    background: Color(0xFFF3F1EA),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFE9E6DC),
    border: Color(0xFFE0DCD0),
    text: Color(0xFF17181A),
    textMuted: Color(0xFF63666C),
    textFaint: Color(0xFF9D9E9A),
    accent: Color(0xFFFFC935),
    onAccent: Color(0xFF17181A),
    hero: Color(0xFF17181A),
    onHero: Color(0xFFF6F4EE),
    onHeroMuted: Color(0xFFA2A3A6),
    heroDivider: Color(0xFF303236),
    cash: Color(0xFF178F57),
    card: Color(0xFF4460E6),
    error: Color(0xFFC93622),
    errorSurface: Color(0xFFFBE7E3),
    success: Color(0xFF178F57),
    successSurface: Color(0xFFE2F3E9),
    scrim: Color(0x7A0B0C0D),
    shadow: Color(0x1417181A),
  );

  static const dark = AppColors(
    brightness: Brightness.dark,
    background: Color(0xFF0E0F11),
    surface: Color(0xFF1A1C1F),
    surfaceMuted: Color(0xFF272A2E),
    border: Color(0xFF2E3136),
    text: Color(0xFFF3F1EA),
    textMuted: Color(0xFFA0A2A7),
    textFaint: Color(0xFF6A6D72),
    accent: Color(0xFFFFC935),
    onAccent: Color(0xFF17181A),
    hero: Color(0xFF22252A),
    onHero: Color(0xFFF6F4EE),
    onHeroMuted: Color(0xFFA2A3A6),
    heroDivider: Color(0xFF363A40),
    cash: Color(0xFF3CCB86),
    card: Color(0xFF8799FF),
    error: Color(0xFFFF7A66),
    errorSurface: Color(0xFF3A1E1A),
    success: Color(0xFF3CCB86),
    successSurface: Color(0xFF17301F),
    scrim: Color(0xA3000000),
    shadow: Color(0x52000000),
  );
}
