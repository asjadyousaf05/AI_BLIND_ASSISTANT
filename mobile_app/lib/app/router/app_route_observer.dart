import 'package:flutter/material.dart';

/// Application route observer to track the active screen route.
class AppRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  String? currentRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      currentRoute = route.settings.name;
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute) {
      currentRoute = previousRoute.settings.name;
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      currentRoute = newRoute.settings.name;
    }
  }
}

/// Singleton instance of [AppRouteObserver] registered in [MaterialApp].
final AppRouteObserver appRouteObserver = AppRouteObserver();
