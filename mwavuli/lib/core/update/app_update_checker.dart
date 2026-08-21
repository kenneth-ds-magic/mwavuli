import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../api/api_client.dart';
import '../api/api_config.dart';

import '../api/upload_service.dart';
import '../camera/photo_capture.dart';
import '../offline/sync_service.dart';
import '../../data/local/drift_tree_store.dart';

class AppUpdateChecker extends ConsumerStatefulWidget {
  const AppUpdateChecker({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppUpdateChecker> createState() => _AppUpdateCheckerState();
}

class _AppUpdateCheckerState extends ConsumerState<AppUpdateChecker> {
  bool _updateRequired = false;
  bool _optimizingPostUpdate = false;
  String _latestVersion = '';
  String _updateLink = '';
  String _releaseNotes = '';

  @override
  void initState() {
    super.initState();
    _checkVersionAndPostUpdate();
  }

  Future<void> _checkVersionAndPostUpdate() async {
    await _handlePostUpdateSyncAndCleanup();
    await _checkVersion();
  }

  Future<void> _handlePostUpdateSyncAndCleanup() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final currentVersion = ApiConfig.appVersion.trim();
      final lastVersion = await storage.read(key: 'mwavuli.last_processed_version');
      if (lastVersion == null) {
        // First fresh install: seed current version without running post-update cleanup
        await storage.write(key: 'mwavuli.last_processed_version', value: currentVersion);
        return;
      }

      if (lastVersion != currentVersion) {
        if (mounted) {
          setState(() {
            _optimizingPostUpdate = true;
          });
        }

        // 1. Validate and clean missing/corrupted queued records
        final syncService = ref.read(syncServiceProvider);
        await syncService.validateAndCleanQueue();

        // 2. Sync pending offline queue to server if online
        try {
          await syncService.flush(
            ref.read(apiClientProvider),
            ref.read(uploadServiceProvider),
            ref.read(photoCacheProvider),
          );
        } catch (_) {}

        // 3. Clear old local cache to ensure fresh data after app update
        await ref.read(localTreeStoreProvider).clear();

        // 4. Save current version as processed
        await storage.write(key: 'mwavuli.last_processed_version', value: currentVersion);

        if (mounted) {
          setState(() {
            _optimizingPostUpdate = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _optimizingPostUpdate = false;
        });
      }
    }
  }

  Future<void> _checkVersion() async {
    try {
      final latest =
          await ref.read(apiClientProvider).fetchLatestAppVersion();
      if (!mounted) return;

      final current = ApiConfig.appVersion.trim();
      final latestVer = latest.appVersion.trim();

      if (latestVer.isNotEmpty && current != latestVer) {
        setState(() {
          _updateRequired = true;
          _latestVersion = latestVer;
          _updateLink = latest.link;
          _releaseNotes = latest.releaseNotes;
        });
      }
    } catch (_) {
      // Offline / network failure: ignore version check so app can launch offline
    }
  }

  Future<void> _openDownloadLink() async {
    if (_updateLink.isEmpty) return;
    final uri = Uri.parse(_updateLink);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_optimizingPostUpdate) {
      return Stack(
        children: [
          widget.child,
          PopScope(
            canPop: false,
            child: Scaffold(
              backgroundColor: Colors.black.withValues(alpha: 0.85),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 380),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Palette.cream50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Palette.green800),
                        const SizedBox(height: 20),
                        Text(
                          'Optimizing Mwavuli (v${ApiConfig.appVersion})',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Palette.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Syncing offline queue, validating data records, and clearing cache...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Palette.ink2,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (!_updateRequired) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: Colors.black.withValues(alpha: 0.85),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Palette.cream50,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Palette.green100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.system_update_rounded,
                          size: 40,
                          color: Palette.green800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Update Available',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Palette.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A new version of Mwavuli (v$_latestVersion) is available. Please update to continue using the application.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Palette.ink2,
                          height: 1.4,
                        ),
                      ),
                      if (_releaseNotes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "What's New:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _releaseNotes,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _openDownloadLink,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text(
                            'Update Now',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
