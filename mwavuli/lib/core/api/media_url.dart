import 'api_config.dart';

/// Rewrites MinIO/S3 media URLs so they work on emulators and physical devices.
///
/// Prefer API `/v1/media/...` when the response still points at localhost MinIO.
String? resolveMediaUrl(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  var cleaned = url.trim();

  // Strip duplicate or nested /v1/media/ prefixes
  final mediaIdx = cleaned.lastIndexOf('/v1/media/');
  if (mediaIdx != -1) {
    cleaned = cleaned.substring(mediaIdx + '/v1/media/'.length);
  }

  final api = Uri.tryParse(ApiConfig.baseUrl);
  if (api == null || !api.hasAuthority) return cleaned;

  var key = cleaned;
  const bucket = '/mwavuli-public/';
  const uploadsBucket = '/mwavuli-uploads/';
  final i = key.indexOf(bucket);
  final u = key.indexOf(uploadsBucket);

  if (i >= 0) {
    key = key.substring(i + bucket.length);
    if (!key.startsWith('public/')) key = 'public/$key';
  } else if (u >= 0) {
    key = key.substring(u + uploadsBucket.length);
    if (!key.startsWith('uploads/')) key = 'uploads/$key';
  } else {
    final parsed = Uri.tryParse(key);
    if (parsed != null && parsed.hasScheme) {
      final host = parsed.host;
      final path = parsed.path;

      if (host == api.host && path.startsWith('/v1/media/')) return key;

      final looksLikeMinio = host == 'localhost' ||
          host == '127.0.0.1' ||
          host == 'minio' ||
          parsed.port == 9000 ||
          parsed.port == 9001;

      if (!looksLikeMinio) return key;

      var p = path;
      if (p.startsWith('/')) p = p.substring(1);
      key = p;
    }

    if (key.startsWith('/')) key = key.substring(1);
    if (!key.startsWith('public/') && !key.startsWith('uploads/')) {
      key = 'public/$key';
    }
  }

  return api.replace(path: '/v1/media/$key').toString();
}
