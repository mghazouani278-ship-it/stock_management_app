import 'dart:io' show Platform;

/// Android emulator: 10.0.2.2 = host machine's localhost
/// iOS simulator: 127.0.0.1 works (shares host network)
/// Physical device: set to your PC's IP (e.g. 192.168.1.x) if you test on a real phone
const String? _overrideHost = '92.205.161.189'; // e.g. '192.168.1.100' for physical device

String get apiHost => _overrideHost ?? (Platform.isAndroid ? '10.0.2.2' : '127.0.0.1');
