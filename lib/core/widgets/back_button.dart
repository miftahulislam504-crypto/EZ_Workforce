import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

extension BackNavigation on BuildContext {
  /// Goes back when there is a page to return to, otherwise opens [fallback].
  /// Detail pages can be opened from a link, so a plain pop is not enough.
  void goBack(String fallback) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }
}

/// Round back button for the leading slot of a [PageHeader].
class PageBackButton extends StatelessWidget {
  const PageBackButton({super.key, required this.fallback});

  final String fallback;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back),
      onPressed: () => context.goBack(fallback),
    );
  }
}
