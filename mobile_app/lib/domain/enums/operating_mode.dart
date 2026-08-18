enum OperatingMode {
  mobile,
  raspberryPi;

  String get label => switch (this) {
    OperatingMode.mobile => 'Mobile Mode',
    OperatingMode.raspberryPi => 'Raspberry Pi Mode',
  };

  String get description => switch (this) {
    OperatingMode.mobile =>
      'Use the Android phone camera for offline object detection.',
    OperatingMode.raspberryPi =>
      'Use a local wearable Raspberry Pi device in a later module.',
  };
}
