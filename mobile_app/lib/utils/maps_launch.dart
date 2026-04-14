import 'package:url_launcher/url_launcher.dart';

/// Opens [text] in Google Maps: full `http(s)` URLs as-is, otherwise as a search query.
Future<bool> openGoogleMapsForLocation(String text) async {
  final raw = text.trim();
  if (raw.isEmpty) return false;

  final Uri uri;
  final lower = raw.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    final parsed = Uri.tryParse(raw);
    uri = parsed ?? Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(raw)}');
  } else if (lower.startsWith('geo:')) {
    final parsed = Uri.tryParse(raw);
    uri = parsed ?? Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(raw)}');
  } else {
    uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(raw)}');
  }

  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
