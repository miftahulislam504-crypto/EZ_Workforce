import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/nav_items.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/display.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/states.dart';

/// Placeholder for a module that ships in a later phase. It lists what the
/// module will cover so the roadmap stays visible inside the product.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final module = AppNav.moduleBySlug(slug);
    if (module == null) {
      return const EmptyState(
        icon: Icons.explore_off_outlined,
        title: 'Page not found',
        message: 'This module does not exist.',
      );
    }

    final colors = context.colors;
    return PageScroll(
      maxWidth: 880,
      children: [
        Reveal(
          child: AppCard(
            gradient: colors.heroGradient,
            borderColor: Colors.transparent,
            padding: const EdgeInsets.all(28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Icon(module.icon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Planned for Phase ${module.phase}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        module.label,
                        style: context.text.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        module.summary,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Reveal(
          index: 1,
          child: AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('What this module will include'),
                for (final feature in module.features)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.check_circle_outline,
                            size: 19,
                            color: context.scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature,
                            style: context.text.bodyLarge?.copyWith(
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Reveal(
          index: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Back to dashboard',
              icon: Icons.arrow_back,
              variant: AppButtonVariant.secondary,
              onPressed: () => context.go('/dashboard'),
            ),
          ),
        ),
      ],
    );
  }
}
