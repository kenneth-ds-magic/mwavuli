import 'api_config.dart';

/// Rewrites MinIO/S3 media URLs so they work on emulators and physical devices.
///
/// Prefer API `/v1/media/...` when the response still points at localhost MinIO.
String? resolveMediaUrl(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final parsed = Uri.tryParse(url.trim());
  if (parsed == null || !parsed.hasScheme) return url;

  final api = Uri.tryParse(ApiConfig.baseUrl);
  if (api == null || !api.hasAuthority) return url;

  final host = parsed.host;
  final path = parsed.path;

  // Already same-origin media proxy.
  if (host == api.host && path.startsWith('/v1/media/')) return url;

  final looksLikeMinio = host == 'localhost' ||
      host == '127.0.0.1' ||
      host == 'minio' ||
      parsed.port == 9000 ||
      parsed.port == 9001;

  if (looksLikeMinio) {
    var key = path;
    const bucket = '/mwavuli-public/';
    final i = key.indexOf(bucket);
    if (i >= 0) {
      key = key.substring(i + bucket.length);
    } else if (key.startsWith('/')) {
      key = key.substring(1);
    }
    if (!key.startsWith('public/')) {
      key = 'public/$key';
    }
    return api.replace(path: '/v1/media/$key').toString();
  }

  return url;
}
