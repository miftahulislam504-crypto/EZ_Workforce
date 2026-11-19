import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Underlined tab row that switches content in place. Unlike [TabBar] it does
/// not need a fixed height, so it works inside a scrolling page.
class TabStrip<T> extends StatelessWidget {
  const TabStrip({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
  });

  final List<T> tabs;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in tabs)
              InkWell(
                onTap: () => onChanged(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 3,
                        color: tab == selected
                            ? context.scheme.primary
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Text(
                    labelOf(tab),
                    style: TextStyle(
                      fontWeight: tab == selected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: tab == selected
                          ? context.scheme.primary
                          : colors.mutedText,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
