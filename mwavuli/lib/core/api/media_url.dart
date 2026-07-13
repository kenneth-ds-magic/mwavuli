import 'api_config.dart';

/// Rewrites MinIO/S3 media URLs so they work on emulators and physical devices.
///
/// The API may return `http://localhost:9000/...` while the app talks to the
/// API via `127.0.0.1`, `10.0.2.2`, or a LAN IP. Map media to the same host.
String? resolveMediaUrl(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final parsed = Uri.tryParse(url.trim());
  if (parsed == null || !parsed.hasScheme) return url;

  final api = Uri.tryParse(ApiConfig.baseUrl);
  if (api == null || !api.hasAuthority) return url;

  final host = parsed.host;
  if (host != 'localhost' && host != '127.0.0.1') return url;

  final apiHost = api.host;
  if (apiHost == host) return url;

  return parsed.replace(host: apiHost).toString();
}
