import 'dart:async';

import 'package:flutter/material.dart';

/// Application route observer to track the active screen route.
class AppRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  String? currentRoute;
  final _listeners = <VoidCallback>{};

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _updateRoute(String? route) {
    currentRoute = route;
    // Navigator may report a route while widgets are building. Notify the
    // application coordinator after that synchronous build has completed.
    scheduleMicrotask(() {
      for (final listener in _listeners.toList()) {
        if (_listeners.contains(listener)) listener();
      }
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      _updateRoute(route.settings.name);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute) {
      _updateRoute(previousRoute.settings.name);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      _updateRoute(newRoute.settings.name);
    }
  }
}

/// Singleton instance of [AppRouteObserver] registered in [MaterialApp].
final AppRouteObserver appRouteObserver = AppRouteObserver();
