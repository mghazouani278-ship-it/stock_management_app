/// Stub: used when dart:io is not available (Flutter web)
/// Use 127.0.0.1 (not `localhost`) so the browser does not resolve to IPv6 ::1
/// while Node listens on IPv4 — avoids "Unable to reach the server" on Windows/Chrome.
String get apiHost => '127.0.0.1';
