import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/upload_service.dart';
import '../../features/auth/auth_controller.dart';
import '../local/drift_tree_store.dart';
import '../models/profile.dart';

class ProfileRepository {
  ProfileRepository(this._api, this._upload, this._local);
  final ApiClient _api;
  final UploadService _upload;
  final LocalTreeStore _local;

  Future<ProfileData?> fetchMe() async {
    try {
      final data = await _api.fetchMe();
      final profileData = ProfileData.fromApi(data);
      // Persist user info in SQLite database (from_server = true)
      await _local.saveUser(profileData, fromServer: true);
      return profileData;
    } catch (_) {
      // Offline fallback: load user info from SQLite database
      return await _local.getCachedUser();
    }
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
    final profileMap = (data['profile'] as Map?)?.cast<String, dynamic>();
    if (profileMap == null) {
      final updated = await fetchMe();
      return updated!.profile;
    }
    final meProfile = MeProfile.fromApi(profileMap);
    final current = await _local.getCachedUser();
    if (current != null) {
      final updatedProfileData = ProfileData(
        profile: meProfile,
        following: current.following,
        followers: current.followers,
        treeCount: current.treeCount,
        speciesCount: current.speciesCount,
        points: current.points,
        badges: current.badges,
        trees: current.trees,
        topSpecies: current.topSpecies,
        contributions: current.contributions,
      );
      await _local.saveUser(updatedProfileData, fromServer: true);
    }
    return meProfile;
  }

  Future<MeProfile> updateCredentials({
    String? username,
    String? email,
    required String currentPassword,
    String? newPassword,
  }) async {
    final data = await _api.updateCredentials(
      username: username,
      email: email,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    final profileMap = (data['profile'] as Map?)?.cast<String, dynamic>();
    if (profileMap == null) {
      final updated = await fetchMe();
      return updated!.profile;
    }
    final meProfile = MeProfile.fromApi(profileMap);
    final current = await _local.getCachedUser();
    if (current != null) {
      final updatedProfileData = ProfileData(
        profile: meProfile,
        following: current.following,
        followers: current.followers,
        treeCount: current.treeCount,
        speciesCount: current.speciesCount,
        points: current.points,
        badges: current.badges,
        trees: current.trees,
        topSpecies: current.topSpecies,
        contributions: current.contributions,
      );
      await _local.saveUser(updatedProfileData, fromServer: true);
    }
    return meProfile;
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
      final profileData = await fetchMe();
      if (profileData != null && profileData.profile.avatarUrl != null) {
        return profileData.profile;
      }
    }
    return null;
  }
}

final profileRepositoryProvider = Provider(
  (ref) => ProfileRepository(
    ref.watch(apiClientProvider),
    ref.watch(uploadServiceProvider),
    ref.watch(localTreeStoreProvider),
  ),
);

final profileProvider = FutureProvider<ProfileData?>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (auth == AuthStatus.unknown) return null;
  if (auth == AuthStatus.unauthenticated) return null;
  return ref.watch(profileRepositoryProvider).fetchMe();
});
