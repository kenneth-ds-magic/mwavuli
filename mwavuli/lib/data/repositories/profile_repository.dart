import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/upload_service.dart';
import '../../features/auth/auth_controller.dart';
import '../models/profile.dart';

class ProfileRepository {
  ProfileRepository(this._api, this._upload);
  final ApiClient _api;
  final UploadService _upload;

  Future<ProfileData> fetchMe() async {
    final data = await _api.fetchMe();
    return ProfileData.fromApi(data);
  }

  Future<MeProfile> updateMe({
    String? displayName,
    String? bio,
    String? locationLabel,
  }) async {
    final data = await _api.updateMe(
      displayName: displayName,
      bio: bio,
      locationLabel: locationLabel,
    );
    final profile = (data['profile'] as Map?)?.cast<String, dynamic>();
    if (profile == null) {
      return (await fetchMe()).profile;
    }
    return MeProfile.fromApi(profile);
  }

  /// PUT avatar bytes to S3, then poll until the pipeline sets avatarUrl.
  Future<MeProfile?> uploadAvatar(
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  }) async {
    final init = await _api.requestAvatarUpload(contentType: contentType);
    await _upload.putBytes(
      init['uploadUrl'] as String,
      bytes,
      contentType: contentType,
    );

    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 750));
      final data = await _api.fetchMe();
      final profile =
          (data['profile'] as Map?)?.cast<String, dynamic>();
      final url = profile?['avatarUrl'] as String?;
      if (url != null && url.isNotEmpty) {
        return MeProfile.fromApi(profile!);
      }
    }
    return null;
  }
}

final profileRepositoryProvider = Provider(
  (ref) => ProfileRepository(
    ref.watch(apiClientProvider),
    ref.watch(uploadServiceProvider),
  ),
);

final profileProvider = FutureProvider<ProfileData?>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (auth == AuthStatus.unknown) return null;
  if (auth == AuthStatus.unauthenticated) return null;
  return ref.watch(profileRepositoryProvider).fetchMe();
});
