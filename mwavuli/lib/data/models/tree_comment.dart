import '../../core/api/media_url.dart';
import 'tree.dart';

/// A comment on a tree from GET /v1/trees/:id/comments.
class TreeComment {
  const TreeComment({
    required this.id,
    required this.body,
    required this.author,
    required this.createdAt,
  });

  final String id;
  final String body;
  final String author;
  final DateTime createdAt;

  factory TreeComment.fromApi(Map<String, dynamic> j) => TreeComment(
        id: j['id'] as String,
        body: j['body'] as String,
        author: j['author'] as String? ?? 'User',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// Tree record plus processed photos from GET /v1/trees/:id.
class TreeDetail {
  const TreeDetail({
    required this.tree,
    this.photos = const [],
    this.saved = false,
    this.verificationCount = 0,
    this.userVerified = false,
    this.verificationsRequired = 2,
  });

  final Tree tree;
  final List<TreePhotoRef> photos;
  final bool saved;
  final int verificationCount;
  final bool userVerified;
  final int verificationsRequired;

  String? get heroImageUrl {
    for (final p in photos) {
      final url = p.url ?? p.thumbUrl;
      if (url != null && url.isNotEmpty) return url;
    }
    return tree.thumbUrl;
  }
}

class TreePhotoRef {
  const TreePhotoRef({
    required this.id,
    required this.organ,
    this.url,
    this.thumbUrl,
  });

  final String id;
  final String organ;
  final String? url;
  final String? thumbUrl;

  factory TreePhotoRef.fromApi(Map<String, dynamic> j) => TreePhotoRef(
        id: j['id'] as String,
        organ: j['organ'] as String? ?? 'whole',
        url: resolveMediaUrl(j['url'] as String?),
        thumbUrl: resolveMediaUrl(j['thumbUrl'] as String?),
      );
}
