import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_shadows.dart';
import '../../app/theme/app_spacing.dart';

class BrandIconBadge extends StatelessWidget {
  const BrandIconBadge({
    super.key,
    required this.icon,
    this.label,
    this.size = AppDimensions.prominentIconContainer,
    this.iconSize,
    this.square = false,
    this.filled = false,
  });

  final IconData icon;
  final String? label;
  final double size;
  final double? iconSize;
  final bool square;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: filled ? AppColors.primary : AppColors.primaryOverlay20,
      borderRadius: BorderRadius.circular(
        square ? AppRadii.extraLarge : AppRadii.full,
      ),
      border: Border.all(
        color: filled ? AppColors.primary : AppColors.primaryOverlay40,
        width: 4,
      ),
      boxShadow: filled ? AppShadows.primaryGlow : AppShadows.none,
    );

    final badge = Container(
      width: size,
      height: size,
      decoration: decoration,
      child: Icon(
        icon,
        color: filled ? AppColors.onPrimary : AppColors.primary,
        size: iconSize ?? size * 0.48,
      ),
    );

    if (label == null) {
      return ExcludeSemantics(child: badge);
    }

    return Semantics(label: label, image: true, child: badge);
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.icon,
    this.color = AppColors.primary,
  });

  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space1,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == null)
              Container(
                width: AppDimensions.statusDot,
                height: AppDimensions.statusDot,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              )
            else
              Icon(icon, color: color, size: AppDimensions.iconSmall),
            const SizedBox(width: AppSpacing.space2),
            Flexible(
              child: Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusSummaryCard extends StatelessWidget {
  const StatusSummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _surfaceTint(context),
          border: Border.all(color: color.withValues(alpha: 0.14)),
          borderRadius: BorderRadius.circular(AppRadii.extraLarge),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: _mutedText(context)),
              ),
              const SizedBox(height: AppSpacing.space2),
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureNoteCard extends StatelessWidget {
  const FeatureNoteCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryOverlay10,
        border: Border.all(color: AppColors.primaryOverlay30, width: 2),
        borderRadius: BorderRadius.circular(AppRadii.extraLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                icon,
                color: AppColors.primary,
                size: AppDimensions.iconLarge,
              ),
            ),
            const SizedBox(width: AppSpacing.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.space1),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SafetyNotice extends StatelessWidget {
  const SafetyNotice({super.key, required this.title, required this.messages});

  final String title;
  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: title,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(AppRadii.extraLarge),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.health_and_safety_outlined,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space3),
              for (final message in messages) ...[
                Text(message),
                const SizedBox(height: AppSpacing.space2),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.error_outline,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title. $message',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.10),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(AppRadii.extraLarge),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.error),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.space1),
                    Text(message),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _surfaceTint(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.primaryOverlay05
      : AppColors.lightSurfaceMuted;
}

Color _mutedText(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.primary.withValues(alpha: 0.70)
      : AppColors.slate500;
}
