import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/widgets/foundation_scaffold.dart';
import 'app_route.dart';

class UnknownRouteScreen extends StatelessWidget {
  const UnknownRouteScreen({super.key, required this.unknownRouteName});

  final String? unknownRouteName;

  @override
  Widget build(BuildContext context) {
    return FoundationScaffold(
      title: AppStrings.pageNotFoundTitle,
      description:
          'The requested page could not be opened. You can safely return to the home screen.',
      status: unknownRouteName == null
          ? 'Unknown route.'
          : 'Unknown route: $unknownRouteName',
      children: [
        FilledButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoute.home.path, (route) => false),
          icon: const Icon(Icons.home),
          label: const Text(AppStrings.returnHome),
        ),
      ],
    );
  }
}
