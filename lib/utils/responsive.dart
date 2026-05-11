import 'package:flutter/material.dart';

class Responsive {
  static const double phoneMax = 600;
  static const double tabletMax = 900;

  static bool isPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < phoneMax;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= phoneMax && w < tabletMax;
  }

  static bool isLarge(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletMax;

  static bool isTabletOrLarger(BuildContext context) =>
      MediaQuery.of(context).size.width >= phoneMax;

  static int columnsFor(double width) {
    if (width >= tabletMax) return 3;
    if (width >= phoneMax) return 2;
    return 1;
  }

  static double maxContentWidth(double width) {
    if (width >= 1200) return 1100;
    if (width >= tabletMax) return 900;
    return width;
  }
}

class MaxWidth extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  const MaxWidth({super.key, required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cap = maxWidth ?? Responsive.maxContentWidth(constraints.maxWidth);
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: cap),
            child: child,
          ),
        );
      },
    );
  }
}
