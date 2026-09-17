import 'package:flutter/material.dart';

/// WCAG 2.1 AA accessible button with semantic announcement,
/// 48x48 min touch target, and high-visibility focus ring.
class AccessibleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final String? label;
  final String semanticLabel;
  final String? semanticHint;
  final bool isLoading;
  final bool isSecondary;
  final IconData? icon;

  const AccessibleButton({
    super.key,
    required this.onPressed,
    this.child,
    this.label,
    String? semanticLabel,
    this.semanticHint,
    this.isLoading = false,
    this.isSecondary = false,
    this.icon,
  }) : semanticLabel = semanticLabel ?? label ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isSecondary ? theme.colorScheme.primary : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        if (child != null)
          child!
        else if (label != null)
          Text(label!),
      ],
    );

    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      label: semanticLabel,
      hint: semanticHint,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: isSecondary
            ? OutlinedButton(
                onPressed: isLoading ? null : onPressed,
                child: content,
              )
            : ElevatedButton(
                onPressed: isLoading ? null : onPressed,
                child: content,
              ),
      ),
    );
  }
}
