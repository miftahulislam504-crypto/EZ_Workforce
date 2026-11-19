import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/brand.dart';

/// Shown when the app was started without Supabase credentials.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: AppCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandWordmark(size: 40),
                  const SizedBox(height: 28),
                  Text(
                    'Connect your Supabase project',
                    style: context.text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'The app needs your Supabase URL and anon key. Pass them when you run or build the app:',
                    style: context.text.bodyLarge?.copyWith(
                      color: context.colors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SelectableText(
                      'flutter run -d chrome \\\n'
                      '  --dart-define=SUPABASE_URL=https://YOUR-REF.supabase.co \\\n'
                      '  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'See docs/SETUP.md for the full setup guide, including applying the database migrations.',
                    style: TextStyle(color: context.colors.mutedText),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
