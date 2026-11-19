import 'package:flutter/material.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand.dart';

/// Split-screen layout for sign-in and registration pages. The brand panel
/// is shown on wide screens only.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.maxWidth = 440,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final colors = context.colors;

    final form = Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 20, vertical: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!wide) ...[
                const BrandWordmark(size: 38),
                const SizedBox(height: 32),
              ],
              Text(
                title,
                style: context.text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: context.text.bodyLarge?.copyWith(
                  color: colors.mutedText,
                ),
              ),
              const SizedBox(height: 28),
              child,
              if (footer != null) ...[const SizedBox(height: 24), footer!],
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: context.scheme.surface,
      body: wide
          ? Row(
              children: [
                const Expanded(flex: 5, child: _BrandPanel()),
                Expanded(flex: 5, child: form),
              ],
            )
          : SafeArea(child: form),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  static const List<(IconData, String)> _points = [
    (Icons.groups_2_outlined, 'One home for every employee record'),
    (Icons.account_tree_outlined, 'Branches, departments and roles built in'),
    (Icons.verified_user_outlined, 'Role based access with a full audit trail'),
    (Icons.campaign_outlined, 'Notices and alerts that reach the right people'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: context.colors.heroGradient),
      padding: const EdgeInsets.all(56),
      child: Stack(
        children: [
          Positioned(
            right: -120,
            top: -120,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            left: -80,
            bottom: -140,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandWordmark(size: 44, color: Colors.white),
              const Spacer(),
              Text(
                Env.tagline,
                style: context.text.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 32),
              for (final point in _points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(point.$1, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          point.$2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Text(
                Env.values.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
