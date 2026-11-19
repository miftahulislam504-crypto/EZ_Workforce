import 'package:flutter/material.dart';

import '../config/env.dart';
import '../theme/app_colors.dart';

/// The EZ monogram, drawn in code so the app needs no image assets.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: context.colors.heroGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: Palette.brand.withValues(alpha: 0.35),
            blurRadius: size * 0.4,
            offset: Offset(0, size * 0.15),
          ),
        ],
      ),
      child: Text(
        'EZ',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.size = 36, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? context.scheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: size),
        SizedBox(width: size * 0.3),
        Text(
          Env.appName,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.48,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
