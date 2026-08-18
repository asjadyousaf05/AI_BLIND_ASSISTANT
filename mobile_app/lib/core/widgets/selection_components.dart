import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';

class SelectableInfoCard extends StatelessWidget {
  const SelectableInfoCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.status,
    this.enabled = true,
    this.semanticLabel,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final String? status;
  final bool enabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    final borderColor = selected
        ? AppColors.primary
        : Theme.of(context).colorScheme.outlineVariant;
    final foreground = active
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).disabledColor;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: active,
      label:
          semanticLabel ??
          '$title, ${selected ? 'selected' : 'not selected'}'
              '${status == null ? '' : ', $status'}',
      child: InkWell(
        onTap: active ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadii.extraLarge),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.space5),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryOverlay10 : _surface(context),
            border: Border.all(color: borderColor, width: selected ? 4 : 2),
            borderRadius: BorderRadius.circular(AppRadii.extraLarge),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: AppDimensions.iconContainer,
                    height: AppDimensions.iconContainer,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.primaryOverlay10,
                      borderRadius: BorderRadius.circular(AppRadii.large),
                    ),
                    child: Icon(
                      icon,
                      color: selected ? AppColors.onPrimary : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: selected
                                    ? AppColors.primary
                                    : foreground,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.space1),
                        Text(description, style: TextStyle(color: foreground)),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle, color: AppColors.primary),
                ],
              ),
              if (status != null) ...[
                const SizedBox(height: AppSpacing.space4),
                Text(
                  status!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? AppColors.primary : foreground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SettingChoiceCard<T> extends StatelessWidget {
  const SettingChoiceCard({
    super.key,
    required this.value,
    required this.groupValue,
    required this.title,
    required this.icon,
    required this.onChanged,
  });

  final T value;
  final T groupValue;
  final String title;
  final IconData icon;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: '$title, ${selected ? 'selected' : 'not selected'}',
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(AppRadii.extraLarge),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(
            minHeight: AppDimensions.primaryControlHeight,
          ),
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryOverlay10 : _surface(context),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadii.extraLarge),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? AppColors.primary : _mutedText(context),
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(title, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

Color _surface(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.slate800.withValues(alpha: 0.55)
      : AppColors.slate100;
}

Color _mutedText(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.slate400
      : AppColors.slate500;
}
