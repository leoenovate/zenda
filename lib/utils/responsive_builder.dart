import 'package:flutter/material.dart';

/// Breakpoints for different screen sizes
class ScreenSize {
  static const double mobile = 650;
  static const double tablet = 1100;
  static const double desktop = 1200;
}

/// Utility class for responsive design
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveBuilder({
    Key? key,
    required this.mobile,
    this.tablet,
    this.desktop,
  }) : super(key: key);

  /// Static method to get current device screen type
  static DeviceScreenType getDeviceType(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    
    if (width < ScreenSize.mobile) {
      return DeviceScreenType.mobile;
    } 
    if (width < ScreenSize.tablet) {
      return DeviceScreenType.tablet;
    } 
    if (width < ScreenSize.desktop) {
      return DeviceScreenType.desktop;
    }
    
    return DeviceScreenType.desktop;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = constraints.maxWidth;

        // For mobile screens
        if (maxWidth < ScreenSize.mobile) {
          return mobile;
        }
        
        // For tablet screens
        if (maxWidth < ScreenSize.tablet) {
          return tablet ?? mobile;
        }
        
        // For desktop screens
        return desktop ?? tablet ?? mobile;
      },
    );
  }
}

/// Helper for determining what type of screen we're dealing with
enum DeviceScreenType {
  mobile,
  tablet,
  desktop,
}

/// Extension on BuildContext to easily access screen information
extension ResponsiveExtension on BuildContext {
  bool get isMobile => ResponsiveBuilder.getDeviceType(this) == DeviceScreenType.mobile;
  bool get isTablet => ResponsiveBuilder.getDeviceType(this) == DeviceScreenType.tablet;
  bool get isDesktop => ResponsiveBuilder.getDeviceType(this) == DeviceScreenType.desktop;
  
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  
  Size get screenSize => MediaQuery.of(this).size;
  
  // Padding helpers based on screen size
  EdgeInsets get screenPadding {
    if (isMobile) return const EdgeInsets.all(16);
    if (isTablet) return const EdgeInsets.all(24);
    return const EdgeInsets.all(32);
  }
  
  // Responsive spacing helpers
  double get spacingXs => isMobile ? 4 : 8;
  double get spacingSm => isMobile ? 8 : 16;
  double get spacingMd => isMobile ? 16 : 24;
  double get spacingLg => isMobile ? 24 : 32;
  double get spacingXl => isMobile ? 32 : 48;
} 