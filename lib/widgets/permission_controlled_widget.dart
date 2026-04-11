import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/permissions_controller.dart';

/// Widget wrapper that controls visibility and enabled state based on user permissions
class PermissionControlledWidget extends StatelessWidget {
  final String controlName;
  final Widget child;
  final Widget? fallback;

  const PermissionControlledWidget({
    super.key,
    required this.controlName,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<PermissionsController>()) return child;
    final perms = Get.find<PermissionsController>();

    return Obx(() {
      final visible = perms.isVisible(controlName);
      final enabled = perms.isEnabled(controlName);

      if (!visible) {
        return fallback ?? const SizedBox.shrink();
      }

      if (!enabled) {
        return Opacity(
          opacity: 0.5,
          child: IgnorePointer(
            child: child,
          ),
        );
      }

      return child;
    });
  }
}

/// Simpler version that only checks visibility
class VisibilityControlled extends StatelessWidget {
  final String controlName;
  final Widget child;
  final Widget? fallback;

  const VisibilityControlled({
    super.key,
    required this.controlName,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<PermissionsController>()) return child;
    final perms = Get.find<PermissionsController>();

    return Obx(() {
      if (!perms.isVisible(controlName)) {
        return fallback ?? const SizedBox.shrink();
      }
      return child;
    });
  }
}

/// Extension method for easier usage
extension PermissionControlExtension on Widget {
  /// Wrap widget with permission control
  Widget withPermission(String controlName, {Widget? fallback}) {
    return PermissionControlledWidget(
      controlName: controlName,
      fallback: fallback,
      child: this,
    );
  }

  /// Wrap widget with visibility control only
  Widget withVisibilityControl(String controlName, {Widget? fallback}) {
    return VisibilityControlled(
      controlName: controlName,
      fallback: fallback,
      child: this,
    );
  }
}
