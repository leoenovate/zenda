import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Which semantic color from [ColorScheme] paints the logo.
enum ZendaLogoTone {
  /// Brand primary — teal or orange depending on user preference.
  brand,

  /// For logos sitting on primary-colored surfaces (e.g. sidebar, AppBar).
  onBrand,

  /// Default foreground on neutral surfaces.
  surface,

  /// Complementary accent hue.
  accent,
}

/// Theme-aware Zenda logo rendered from [assets/logos/logo.svg].
class ZendaLogo extends StatelessWidget {
  const ZendaLogo({
    super.key,
    this.size = 32,
    this.color,
    this.tone = ZendaLogoTone.brand,
    this.semanticsLabel = 'Zenda',
  });

  final double size;
  final Color? color;
  final ZendaLogoTone tone;
  final String? semanticsLabel;

  static const _assetPath = 'assets/logos/logo.svg';

  Color _resolveColor(BuildContext context) {
    if (color != null) return color!;
    final scheme = Theme.of(context).colorScheme;
    return switch (tone) {
      ZendaLogoTone.brand => scheme.primary,
      ZendaLogoTone.onBrand => scheme.onPrimary,
      ZendaLogoTone.surface => scheme.onSurface,
      ZendaLogoTone.accent => scheme.secondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tint = _resolveColor(context);

    return Semantics(
      label: semanticsLabel,
      child: SvgPicture.asset(
        _assetPath,
        height: size,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      ),
    );
  }
}
