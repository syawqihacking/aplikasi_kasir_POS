import 'package:flutter/material.dart';

/// Breakpoints for responsive design
class Breakpoints {
  static const double phone = 600;
  static const double tablet = 900;
}

/// Check if the screen is phone width (< 600px)
bool isPhone(BuildContext context) => MediaQuery.sizeOf(context).width < Breakpoints.phone;

/// Check if the screen is tablet width (600-900px)
bool isTablet(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width >= Breakpoints.phone && width < Breakpoints.tablet;
}

/// Check if the screen is desktop width (>= 900px)
bool isDesktop(BuildContext context) => MediaQuery.sizeOf(context).width >= Breakpoints.tablet;

/// Get the current screen size category
ScreenSize getScreenSize(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < Breakpoints.phone) return ScreenSize.phone;
  if (width < Breakpoints.tablet) return ScreenSize.tablet;
  return ScreenSize.desktop;
}

enum ScreenSize { phone, tablet, desktop }

/// Responsive padding based on screen size
EdgeInsets responsivePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width > Breakpoints.tablet) return const EdgeInsets.all(32);
  if (width > Breakpoints.phone) return const EdgeInsets.all(24);
  return const EdgeInsets.all(16);
}

/// Responsive horizontal padding
EdgeInsets responsiveHorizontalPadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width > Breakpoints.tablet) return const EdgeInsets.symmetric(horizontal: 32);
  if (width > Breakpoints.phone) return const EdgeInsets.symmetric(horizontal: 24);
  return const EdgeInsets.symmetric(horizontal: 16);
}

/// Responsive font size for headings
double responsiveFontSize(BuildContext context, {double desktop = 28, double tablet = 24, double phone = 20}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width > Breakpoints.tablet) return desktop;
  if (width > Breakpoints.phone) return tablet;
  return phone;
}

/// Responsive font size for subheadings
double responsiveSubtitleSize(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width > Breakpoints.tablet) return 14;
  if (width > Breakpoints.phone) return 13;
  return 12;
}

/// Responsive gap between widgets
double responsiveGap(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width > Breakpoints.tablet) return 24;
  if (width > Breakpoints.phone) return 16;
  return 12;
}

/// Responsive card padding
EdgeInsets responsiveCardPadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width > Breakpoints.tablet) return const EdgeInsets.all(24);
  if (width > Breakpoints.phone) return const EdgeInsets.all(20);
  return const EdgeInsets.all(16);
}

/// Whether to use a bottom navigation bar (phone) or sidebar (desktop/tablet)
bool useBottomNav(BuildContext context) => isPhone(context);