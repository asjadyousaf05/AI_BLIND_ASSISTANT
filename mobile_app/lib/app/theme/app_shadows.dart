import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const none = <BoxShadow>[];

  static const small = <BoxShadow>[
    BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const large = <BoxShadow>[
    BoxShadow(color: Color(0x1F000000), blurRadius: 18, offset: Offset(0, 8)),
  ];

  static const primaryGlow = <BoxShadow>[
    BoxShadow(color: Color(0x3325C0F4), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const alertGlow = <BoxShadow>[
    BoxShadow(color: Color(0x3325C0F4), blurRadius: 32, spreadRadius: 4),
  ];
}
