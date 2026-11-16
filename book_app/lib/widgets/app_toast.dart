import 'package:flutter/material.dart';

enum AppToastKind { success, error, info }

class AppToast {
  AppToast._();

  static void success(
    BuildContext context,
    String message, {
    String? title,
    SnackBarAction? action,
  }) {
    show(
      context,
      message,
      title: title,
      kind: AppToastKind.success,
      action: action,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    String? title,
    SnackBarAction? action,
  }) {
    show(
      context,
      message,
      title: title,
      kind: AppToastKind.error,
      action: action,
    );
  }

  static void info(
    BuildContext context,
    String message, {
    String? title,
    SnackBarAction? action,
  }) {
    show(
      context,
      message,
      title: title,
      kind: AppToastKind.info,
      action: action,
    );
  }

  static void show(
    BuildContext context,
    String message, {
    String? title,
    AppToastKind kind = AppToastKind.info,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: _ToastContent(title: title, message: message, kind: kind),
          action: action,
        ),
      );
  }
}

class _ToastContent extends StatelessWidget {
  const _ToastContent({
    required this.title,
    required this.message,
    required this.kind,
  });

  final String? title;
  final String message;
  final AppToastKind kind;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (kind) {
      AppToastKind.success => (
        Icons.check_circle_rounded,
        const Color(0xFF55D6AE),
      ),
      AppToastKind.error => (
        Icons.error_outline_rounded,
        const Color(0xFFFF7180),
      ),
      AppToastKind.info => (
        Icons.notifications_none_rounded,
        const Color(0xFFAE91FF),
      ),
    };

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .76),
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
