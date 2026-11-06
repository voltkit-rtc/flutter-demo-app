import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement, PlatformException;
import 'package:url_launcher/url_launcher.dart';

import '../app_assets.dart';
import '../config.dart';
import '../theme.dart';
import '../util/toast.dart';

Future<void> openUrl(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } on PlatformException {
    toast('No browser on this phone could open that link.', ToastKind.error);
  }
}

enum V { display, title, heading, body, medium, small, tiny }

TextStyle textStyle(V variant, {Color color = C.text, double? size, double? spacing}) {
  final (FontWeight weight, double font, double line) = switch (variant) {
    V.display => (FontWeight.w800, 30, 36),
    V.title => (FontWeight.w700, 22, 28),
    V.heading => (FontWeight.w600, 17, 23),
    V.body => (FontWeight.w400, 15, 21),
    V.medium => (FontWeight.w500, 15, 21),
    V.small => (FontWeight.w500, 13, 18),
    V.tiny => (FontWeight.w600, 11, 14),
  };
  return TextStyle(
    fontFamily: 'Outfit',
    fontWeight: weight,
    fontSize: size ?? font,
    height: line / font,
    leadingDistribution: TextLeadingDistribution.even,
    color: color,
    letterSpacing: spacing,
    decoration: TextDecoration.none,
  );
}

/// Text in the app's own type scale. It does not grow with the system font size, so cards keep their shape.
class T extends StatelessWidget {
  const T(this.text, {super.key, this.variant = V.body, this.color = C.text, this.align, this.lines, this.size, this.spacing, this.id});

  final String text;
  final V variant;
  final Color color;
  final TextAlign? align;
  final int? lines;
  final double? size;
  final double? spacing;
  final String? id;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      text,
      style: textStyle(variant, color: color, size: size, spacing: spacing),
      textAlign: align,
      maxLines: lines,
      overflow: lines == null ? null : TextOverflow.ellipsis,
      softWrap: lines != 1,
      textScaler: TextScaler.noScaling,
    );
    return id == null ? child : Semantics(identifier: id, child: child);
  }
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w800, fontSize: size, color: C.white, letterSpacing: -0.4, decoration: TextDecoration.none);
    return Text.rich(
      TextSpan(text: 'Volt', style: style, children: [TextSpan(text: 'Kit', style: style.copyWith(color: C.cyan))]),
      textScaler: TextScaler.noScaling,
    );
  }
}

/// Paints a gradient behind everything, as a full-screen backdrop.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, this.colors = G.night, required this.child});

  final List<Color> colors;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: C.bg, gradient: vertical(colors)),
        child: child,
      );
}

/// Pressable: dims and shrinks a little under the finger, and names itself for tests and screen readers.
class Tap extends StatefulWidget {
  const Tap({super.key, required this.child, this.onTap, this.id, this.label, this.pressedOpacity = 1, this.pressedScale = 1, this.selected, this.link = false});

  final Widget child;
  final VoidCallback? onTap;
  final String? id;
  final String? label;
  final double pressedOpacity;
  final double pressedScale;
  final bool? selected;
  final bool link;

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  var _down = false;

  void _set(bool down) {
    if (down != _down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    Widget child = widget.child;
    if (widget.pressedOpacity != 1) {
      child = AnimatedOpacity(opacity: _down ? widget.pressedOpacity : 1, duration: const Duration(milliseconds: 80), child: child);
    }
    if (widget.pressedScale != 1) {
      child = AnimatedScale(scale: _down ? widget.pressedScale : 1, duration: const Duration(milliseconds: 80), child: child);
    }
    return Semantics(
      container: true,
      identifier: widget.id,
      label: widget.label,
      button: !widget.link,
      link: widget.link,
      enabled: on,
      selected: widget.selected,
      excludeSemantics: widget.label != null,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: on ? (_) => _set(true) : null,
        onTapUp: on ? (_) => _set(false) : null,
        onTapCancel: on ? () => _set(false) : null,
        child: child,
      ),
    );
  }
}

class Spinner extends StatelessWidget {
  const Spinner({super.key, this.color = C.magenta, this.size = 22});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(color: color, strokeWidth: 2.4),
      );
}

class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onTap, this.icon, this.disabled = false, this.loading = false, this.colors = G.accent, this.dark = false, this.id});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool disabled;
  final bool loading;
  final List<Color> colors;
  final bool dark;
  final String? id;

  @override
  Widget build(BuildContext context) {
    final ink = dark ? C.ink : C.white;
    final off = disabled || loading;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Tap(
        id: id,
        label: label,
        onTap: off ? null : onTap,
        pressedOpacity: 0.85,
        pressedScale: 0.98,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(R.pill), gradient: diagonal(colors)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: loading
                ? [Spinner(color: ink)]
                : [
                    if (icon != null) ...[Icon(icon, size: 19, color: ink), const SizedBox(width: 8)],
                    Flexible(child: T(label, variant: V.heading, color: ink, lines: 1)),
                  ],
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onTap, this.icon, this.danger = false, this.id});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool danger;
  final String? id;

  @override
  Widget build(BuildContext context) {
    final tint = danger ? C.danger : C.white;
    return Tap(
      id: id,
      label: label,
      onTap: onTap,
      pressedOpacity: 0.7,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: C.glass,
          borderRadius: BorderRadius.circular(R.pill),
          border: Border.all(color: C.glassBorder, width: hairline(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 18, color: tint), const SizedBox(width: 8)],
            T(label, variant: V.medium, color: tint),
          ],
        ),
      ),
    );
  }
}

class IconBtn extends StatelessWidget {
  const IconBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 44,
    this.active = false,
    this.danger = false,
    this.tint,
    this.badge = 0,
    this.disabled = false,
    this.turns = 0,
    this.id,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final bool active;
  final bool danger;
  final Color? tint;
  final int badge;
  final bool disabled;

  /// Rotates the icon, in full turns.
  final double turns;
  final String? id;

  @override
  Widget build(BuildContext context) {
    Widget glyph = Icon(icon, size: size * 0.5, color: tint ?? C.white);
    if (turns != 0) glyph = Transform.rotate(angle: turns * 2 * math.pi, child: glyph);
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Tap(
        id: id,
        label: label,
        onTap: disabled ? null : onTap,
        pressedOpacity: 0.75,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: danger ? C.danger : (active ? C.purple : C.glassStrong),
                  border: Border.all(color: C.glassBorder, width: hairline(context)),
                ),
                child: glyph,
              ),
              if (badge > 0)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    height: 17,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(color: C.pink, borderRadius: BorderRadius.circular(9)),
                    child: T(badge > 9 ? '9+' : '$badge', variant: V.tiny, size: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          gradient: diagonal(G.panel),
          borderRadius: BorderRadius.circular(R.lg),
          border: Border.all(color: C.glassBorder, width: hairline(context)),
        ),
        child: child,
      );
}

/// An image from the app's assets, decoded no larger than it is shown. There can be dozens on a screen.
class Asset extends StatelessWidget {
  const Asset(this.path, {super.key, required this.width, required this.height, this.fit = BoxFit.cover, this.opacity});

  final String path;
  final double width;
  final double height;
  final BoxFit fit;
  final Animation<double>? opacity;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      opacity: opacity,
      gaplessPlayback: true,
      cacheWidth: (width * ratio).round(),
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.avatar, this.frame = 'none', this.size = 44});

  final String? avatar;
  final String frame;
  final double size;

  @override
  Widget build(BuildContext context) {
    final framed = frame == 'lion' || frame == 'wolf';
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(child: Asset(avatarAsset(avatar), width: size, height: size)),
          if (framed)
            Positioned(
              left: -size * 0.46,
              top: -size * 0.46,
              child: IgnorePointer(child: Asset(frameAsset(frame), width: size * 1.92, height: size * 1.92, fit: BoxFit.contain)),
            ),
        ],
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, this.icon, this.tint = C.white});

  final String label;
  final IconData? icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0x73000000), borderRadius: BorderRadius.circular(R.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12, color: tint), const SizedBox(width: 4)],
            T(label, variant: V.tiny, color: tint),
          ],
        ),
      );
}

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  /// `host`, `cohost`, `moderator` or `viewer`.
  final String role;

  @override
  Widget build(BuildContext context) {
    if (role == 'viewer') return const SizedBox.shrink();
    final (String label, Color bg, Color ink) = switch (role) {
      'host' => ('HOST', C.gold, C.ink),
      'moderator' => ('MOD', C.success, const Color(0xFF032016)),
      _ => ('CO-HOST', C.purple, C.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: T(label, variant: V.tiny, size: 9, color: ink),
    );
  }
}

class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.size = 7});

  final double size;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 650), lowerBound: 0.35)..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: FadeTransition(
          opacity: _pulse,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: const BoxDecoration(color: C.white, shape: BoxShape.circle),
          ),
        ),
      );
}

class LivePill extends StatelessWidget {
  const LivePill({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(R.pill),
          gradient: const LinearGradient(colors: G.danger),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [LiveDot(size: 6), SizedBox(width: 4), T('LIVE', variant: V.tiny)],
        ),
      );
}

class _BrandPill extends StatelessWidget {
  const _BrandPill({required this.label, required this.url, required this.leading, required this.lead, required this.name});

  final String label;
  final String url;
  final Widget leading;
  final String lead;
  final String name;

  @override
  Widget build(BuildContext context) => Tap(
        label: label,
        link: true,
        onTap: () => openUrl(url),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: const Color(0x61000000), borderRadius: BorderRadius.circular(R.pill)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(width: 4),
              T(lead, variant: V.tiny, color: C.textDim),
              T(name, variant: V.tiny),
            ],
          ),
        ),
      );
}

class PoweredBy extends StatelessWidget {
  const PoweredBy({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: _BrandPill(
          label: Voltkit.poweredBy,
          url: Voltkit.site,
          leading: Asset(Art.mark, width: 14, height: 14, fit: BoxFit.contain),
          lead: 'Powered by ',
          name: 'VoltKit RTC',
        ),
      );
}

/// Says what this app is: a Flutter demo, running on VoltKit RTC. Both open the page that explains how.
class BuiltWith extends StatelessWidget {
  const BuiltWith({super.key, this.alignment = WrapAlignment.center});

  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: alignment,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: const [
          _BrandPill(
            label: Voltkit.poweredBy,
            url: Voltkit.site,
            leading: Asset(Art.mark, width: 14, height: 14, fit: BoxFit.contain),
            lead: 'Powered by ',
            name: 'VoltKit RTC',
          ),
          _BrandPill(
            label: Voltkit.madeWith,
            url: Voltkit.flutterPage,
            leading: Icon(Icons.flutter_dash, size: 13, color: C.cyan),
            lead: 'Made with ',
            name: 'Flutter',
          ),
        ],
      );
}

/// A sheet over the screen. It stays above the keyboard, navigation bar included.
Future<Result?> showSheet<Result>(BuildContext context, {required WidgetBuilder builder, String? title, String? id}) => showModalBottomSheet<Result>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x99000000),
      barrierLabel: 'Close',
      elevation: 0,
      constraints: const BoxConstraints(),
      builder: (context) => _SheetBody(title: title, id: id, child: builder(context)),
    );

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.child, this.title, this.id});

  final Widget child;
  final String? title;
  final String? id;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    return Semantics(
      identifier: id,
      container: true,
      explicitChildNodes: true,
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
        padding: EdgeInsets.fromLTRB(18, 10, 18, (keyboard > 0 ? keyboard : math.max(media.padding.bottom, 14)) + 8),
        decoration: BoxDecoration(
          color: C.plum,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(R.xl)),
          border: Border.all(color: C.glassBorder, width: hairline(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: C.glassStrong, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            if (title != null) ...[T(title!, variant: V.heading), const SizedBox(height: 12)],
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

class SheetRow extends StatelessWidget {
  const SheetRow({super.key, required this.icon, required this.label, required this.onTap, this.hint, this.danger = false, this.gold = false, this.id});

  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback onTap;
  final bool danger;
  final bool gold;
  final String? id;

  @override
  Widget build(BuildContext context) {
    final tint = danger ? C.danger : (gold ? C.gold : C.white);
    return Tap(
      id: id,
      label: label,
      onTap: onTap,
      pressedOpacity: 0.6,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: C.glass, shape: BoxShape.circle),
              child: Icon(icon, size: 19, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  T(label, variant: V.medium, color: tint),
                  if (hint != null) T(hint!, variant: V.small, color: C.textFaint),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single line input in the app's look.
class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.controller,
    this.id,
    this.hint,
    this.maxLength,
    this.autofocus = false,
    this.focusNode,
    this.height = 50,
    this.radius = R.md,
    this.fontSize = 16,
    this.weight = FontWeight.w500,
    this.fill = C.glass,
    this.border = false,
    this.enabled = true,
    this.action,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? id;
  final String? hint;
  final int? maxLength;
  final bool autofocus;
  final FocusNode? focusNode;
  final double height;
  final double radius;
  final double fontSize;
  final FontWeight weight;
  final Color fill;
  final bool border;
  final bool enabled;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        identifier: id,
        child: Container(
          height: height,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius),
            border: border ? Border.all(color: C.glassBorder, width: hairline(context)) : null,
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            enabled: enabled,
            maxLength: maxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textInputAction: action,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: C.magenta,
            style: TextStyle(fontFamily: 'Outfit', fontSize: fontSize, fontWeight: weight, color: C.white),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              counterText: '',
              hintText: hint,
              hintStyle: TextStyle(fontFamily: 'Outfit', fontSize: fontSize, fontWeight: weight, color: C.textFaint),
            ),
          ),
        ),
      );
}

/// Column of children with a fixed gap, as `gap` in React Native.
List<Widget> gapped(double gap, List<Widget> children, {bool horizontal = false}) => [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(width: horizontal ? gap : null, height: horizontal ? null : gap),
        children[i],
      ],
    ];

// Forces the semantics tree on, for the device tests in tools/. Off in a normal build.
const e2eBuild = bool.fromEnvironment('E2E');
void ensureE2eSemantics() {
  if (e2eBuild) SemanticsBinding.instance.ensureSemantics();
}

