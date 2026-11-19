import 'package:flutter/widgets.dart';

class Breakpoints {
  const Breakpoints._();

  static const double mobile = 700;
  static const double desktop = 1100;
  static const double maxContent = 1240;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isMobile => screenWidth < Breakpoints.mobile;
  bool get isTablet =>
      screenWidth >= Breakpoints.mobile && screenWidth < Breakpoints.desktop;
  bool get isDesktop => screenWidth >= Breakpoints.desktop;

  /// Number of grid columns for card grids at the current width.
  int gridColumns({int mobile = 1, int tablet = 2, int desktop = 3}) {
    if (isMobile) return mobile;
    if (isTablet) return tablet;
    return desktop;
  }
}
