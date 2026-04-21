import 'dart:io' show Platform;

/// Android emulator: `10.0.2.2` = host machine's localhost.
/// iOS simulator: `127.0.0.1` works (shares host network).
///
/// **Physical device:** set [_overrideHost] to your PC LAN IP, or set a full URL in
/// [api_config.apiBaseUrlOverride] (takes precedence over this file).
///
/// **Développement local :** laisser `null` → Android émulateur `10.0.2.2`, iOS / Windows / macOS `127.0.0.1`.
const String? _overrideHost = null;

String get apiHost => _overrideHost ?? (Platform.isAndroid ? '10.0.2.2' : '127.0.0.1');
