import 'package:flutter/material.dart';

import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_icons.dart';
import '../../app/theme/app_spacing.dart';

class AppScreenScaffold extends StatelessWidget {
  const AppScreenScaffold({
    super.key,
    required this.title,
    required this.children,
    this.showAppBar = true,
    this.showBackButton = true,
    this.trailing,
    this.bottomNavigationBar,
    this.maxWidth = AppDimensions.screenMaxWidth,
    this.padding = const EdgeInsets.all(AppSpacing.space6),
  });

  final String title;
  final List<Widget> children;
  final bool showAppBar;
  final bool showBackButton;
  final Widget? trailing;
  final Widget? bottomNavigationBar;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      namesRoute: true,
      label: title,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: showAppBar
            ? AccessibleTopBar(
                title: title,
                showBackButton: showBackButton,
                trailing: trailing,
              )
            : null,
        bottomNavigationBar: bottomNavigationBar,
        body: SafeArea(
          top: !showAppBar,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final minimumHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 0.0;

              return SingleChildScrollView(
                padding: padding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxWidth,
                      minHeight: minimumHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class AccessibleTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AccessibleTopBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.leadingLabel = 'Back',
    this.trailing,
  });

  final String title;
  final bool showBackButton;
  final String leadingLabel;
  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: showBackButton
          ? IconButton(
              tooltip: leadingLabel,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(AppIcons.arrowBack),
            )
          : null,
      title: Semantics(headingLevel: 1, child: Text(title)),
      actions: [
        if (trailing != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.space2),
            child: trailing,
          ),
      ],
    );
  }
}
