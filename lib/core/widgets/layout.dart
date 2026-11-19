import 'package:flutter/material.dart';

import '../utils/responsive.dart';

/// Scrollable page body with centred, width-limited content and
/// breakpoint-aware padding.
class PageScroll extends StatelessWidget {
  const PageScroll({
    super.key,
    required this.children,
    this.maxWidth = Breakpoints.maxContent,
    this.controller,
    this.onRefresh,
  });

  final List<Widget> children;
  final double maxWidth;
  final ScrollController? controller;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final pad = context.isMobile ? 16.0 : (context.isTablet ? 24.0 : 32.0);
    final scroll = SingleChildScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
    if (onRefresh == null) return scroll;
    return RefreshIndicator(onRefresh: onRefresh!, child: scroll);
  }
}

/// Lays children out in as many columns as fit [minTileWidth].
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 260,
    this.spacing = 16,
    this.maxColumns = 6,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            ((constraints.maxWidth + spacing) / (minTileWidth + spacing))
                .floor()
                .clamp(1, maxColumns);
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// Two-pane row on wide screens, stacked column on narrow ones.
class SplitRow extends StatelessWidget {
  const SplitRow({
    super.key,
    required this.primary,
    required this.secondary,
    this.secondaryWidth = 380,
    this.spacing = 20,
  });

  final Widget primary;
  final Widget secondary;
  final double secondaryWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (!context.isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          SizedBox(height: spacing),
          secondary,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: primary),
        SizedBox(width: spacing),
        SizedBox(width: secondaryWidth, child: secondary),
      ],
    );
  }
}
