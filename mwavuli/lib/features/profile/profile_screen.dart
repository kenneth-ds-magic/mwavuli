import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/upload_service.dart';
import '../../core/camera/photo_capture.dart';
import '../../core/location/location_service.dart';
import '../../core/offline/sync_service.dart';
import '../../core/prefs/user_prefs.dart';
import '../../data/models/profile.dart';
import '../../data/models/tree.dart';
import '../../data/repositories/profile_repository.dart';
import '../auth/auth_controller.dart';
import '../../widgets/location_autocomplete_field.dart';
import '../../widgets/pill.dart';
import '../../widgets/tree_photo.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _tab = 0;
  bool _followersRequested = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth == AuthStatus.unknown) {
      return const Center(child: CircularProgressIndicator());
    }
    // Guests (and post-logout) go to the welcome hero — not an in-tab login stub.
    if (auth == AuthStatus.unauthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/welcome');
      });
      return const Center(child: CircularProgressIndicator());
    }

    final tabReq = ref.watch(profileTabRequestProvider);
    if (tabReq != null && tabReq != _tab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _tab = tabReq.clamp(0, 2));
        ref.read(profileTabRequestProvider.notifier).state = null;
      });
    }

    final openFollowers = ref.watch(profileOpenFollowersRequestProvider);
    if (openFollowers && !_followersRequested) {
      _followersRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        ref.read(profileOpenFollowersRequestProvider.notifier).state = false;
        _followersRequested = false;
        await _showSocialList(context, 'Followers', false);
      });
    }

    final profileAsync = ref.watch(profileProvider);
    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _errorState(context, e),
      data: (data) {
        if (data == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/welcome');
          });
          return const Center(child: CircularProgressIndicator());
        }
        return _profileBody(context, data);
      },
    );
  }

  Widget _errorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Palette.danger),
            const SizedBox(height: 12),
            const Text('Could not load your profile.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(profileProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileBody(BuildContext context, ProfileData data) {
    final earth = context.earth;
    final joined = DateFormat.y().format(data.profile.createdAt);
    final primaryBadge =
        data.badges.isNotEmpty ? data.badges.first.name : 'Citizen scientist';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 96,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Palette.green600, Palette.green800]),
              ),
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  child: IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: Palette.green800),
                    onPressed: () => setState(() => _tab = 2),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              bottom: -38,
              child: _ProfileAvatar(profile: data.profile),
            ),
          ],
        ),
        const SizedBox(height: 46),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dims.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.profile.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge),
              Text(
                '${data.profile.handle}'
                '${data.profile.locationLabel == null ? '' : ' · ${data.profile.locationLabel}'}'
                ' · joined $joined',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: earth.ink3),
              ),
              const SizedBox(height: 8),
              Text(
                data.profile.bio?.isNotEmpty == true
                    ? data.profile.bio!
                    : 'No bio yet.',
                style: TextStyle(fontSize: 13.5, color: earth.ink2, height: 1.5),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 7, children: [
                Pill(primaryBadge,
                    icon: Icons.eco_rounded, tone: PillTone.green),
                Pill('Level ${data.profile.level} · ${data.profile.levelName}',
                    tone: PillTone.gold),
              ]),
              const SizedBox(height: 14),
              Wrap(
                spacing: 22,
                runSpacing: 10,
                children: [
                  _stat('${data.following}', 'Following',
                      onTap: () => _showSocialList(context, 'Following', true)),
                  _stat('${data.followers}', 'Followers',
                      onTap: () => _showSocialList(context, 'Followers', false)),
                  _stat('${data.treeCount}', 'Trees',
                      onTap: () => setState(() => _tab = 0)),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stackActions = constraints.maxWidth < 300;
                  final edit = SizedBox(
                    width: stackActions ? double.infinity : null,
                    child: OutlinedButton.icon(
                      onPressed: () => _editProfile(context, data.profile),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit profile'),
                    ),
                  );
                  final share = OutlinedButton(
                    onPressed: () => _shareProfile(context, data),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(52, 44),
                    ),
                    child: const Icon(Icons.ios_share_rounded, size: 18),
                  );
                  if (stackActions) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        edit,
                        const SizedBox(height: 8),
                        share,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: edit),
                      const SizedBox(width: 10),
                      share,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _segmented(),
        const SizedBox(height: 8),
        if (_tab == 0) _treesPane(context, data.trees),
        if (_tab == 1) _statsPane(context, data),
        if (_tab == 2) _settingsPane(context),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _stat(String v, String k, {VoidCallback? onTap}) {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(v,
            style: const TextStyle(
                fontFamily: 'RobotoSlab',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Palette.green900)),
        Text(k,
            style: const TextStyle(fontSize: 12, color: Color(0xFF77694F))),
      ],
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: child,
      ),
    );
  }

  Widget _segmented() {
    Widget seg(String label, int i) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _tab = i),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _tab == i ? Palette.green700 : Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                    color: _tab == i ? Palette.green700 : context.earth.line),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _tab == i ? Colors.white : context.earth.ink2)),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dims.gutter),
      child: Row(children: [
        seg('My trees', 0),
        seg('Stats', 1),
        seg('Settings', 2),
      ]),
    );
  }

  Widget _treesPane(BuildContext context, List<Tree> trees) {
    if (trees.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No trees logged yet.')),
      );
    }
    final bodyWidth = MediaQuery.sizeOf(context).width - Dims.gutter * 2;
    final crossAxisCount = bodyWidth >= 520 ? 3 : 2;
    final aspectRatio = bodyWidth < 340 ? 0.88 : 0.92;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: Dims.gutter, vertical: 8),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: aspectRatio,
      children: [
        for (final t in trees)
          GestureDetector(
            onTap: () => context.push('/tree/${t.id}'),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TreePhoto(
                      t.photoTag,
                      imageUrl: t.thumbUrl,
                      photoStatus: t.photoStatus,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: _tag(_treeTagLabel(t)),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.commonName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Palette.green900)),
                        Text(
                          t.createdAt == null
                              ? t.health.label
                              : '${t.health.label} · ${DateFormat.MMMd().format(t.createdAt!)}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF77694F)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _treeTagLabel(Tree t) {
    if (!t.synced) return '📴 Queued';
    if (t.verified) return '✓ Verified';
    if (t.isFuzzy) return '🔒 Fuzzy';
    return t.visibility.name;
  }

  Widget _tag(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999)),
        child: Text(s,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w700)),
      );

  Widget _statsPane(BuildContext context, ProfileData data) {
    final parks = data.trees
        .map((t) => t.fuzzyLocation)
        .where((l) => l != null)
        .length;
    final tiles = [
      _statTile('${data.treeCount}', 'Trees'),
      _statTile('${data.speciesCount}', 'Species'),
      _statTile('$parks', 'Mapped'),
      _statTile(_formatPoints(data.points), 'Points'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dims.gutter),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 340;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (narrow) ...[
                Row(children: [
                  Expanded(child: tiles[0]),
                  Expanded(child: tiles[1]),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: tiles[2]),
                  Expanded(child: tiles[3]),
                ]),
              ] else
                Row(children: [
                  for (final tile in tiles) Expanded(child: tile),
                ]),
              const SizedBox(height: 16),
              _ContributionsChart(contributions: data.contributions),
              if (data.badges.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Badges',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final b in data.badges)
                      Pill(b.name,
                          icon: Icons.military_tech_outlined, tone: PillTone.gold),
                  ],
                ),
              ],
              if (data.topSpecies.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Top species',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                ..._topSpeciesBars(data.topSpecies, maxLabelWidth: narrow ? 56 : 74),
              ],
            ],
          );
        },
      ),
    );
  }

  String _formatPoints(int points) {
    if (points >= 1000) return '${(points / 1000).toStringAsFixed(1)}k';
    return '$points';
  }

  List<Widget> _topSpeciesBars(List<TopSpeciesStat> species,
      {double maxLabelWidth = 74}) {
    final max = species.map((s) => s.count).reduce((a, b) => a > b ? a : b);
    return [
      for (var i = 0; i < species.length; i++)
        _speciesBar(
          species[i].name,
          species[i].count,
          max == 0 ? 0 : species[i].count / max,
          Palette.cat[i % Palette.cat.length],
          labelWidth: maxLabelWidth,
        ),
    ];
  }

  Widget _statTile(String v, String k) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x24241D14))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(v,
                  style: const TextStyle(
                      fontFamily: 'RobotoSlab',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Palette.green800)),
            ),
            const SizedBox(height: 4),
            Text(k,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF77694F))),
          ],
        ),
      );

  Widget _speciesBar(String k, int n, double frac, Color c,
      {double labelWidth = 74}) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(children: [
          SizedBox(
              width: labelWidth,
              child: Text(k,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 12,
                backgroundColor: const Color(0xFFF4EDDD),
                valueColor: AlwaysStoppedAnimation(c),
              ),
            ),
          ),
          SizedBox(
              width: 26,
              child: Text('$n',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
      );

  Widget _settingsPane(BuildContext context) {
    final earth = context.earth;
    final queueAsync = ref.watch(syncQueueCountProvider);
    final queued = queueAsync.maybeWhen(data: (n) => n, orElse: () => 0);
    final fuzzyAsync = ref.watch(defaultFuzzyLocationProvider);
    final defaultFuzzy = fuzzyAsync.maybeWhen(data: (v) => v, orElse: () => true);

    Widget group(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(2, 16, 2, 6),
          child: Text(t.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: earth.ink3)),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dims.gutter),
      child: Column(
        children: [
          group('Accessibility'),
          _SwitchRow(
            icon: Icons.text_fields_rounded,
            title: 'Larger text',
            subtitle: 'Scale UI text up (WCAG 1.4.4)',
            value: ref.watch(largeTextProvider),
            onChanged: (v) =>
                ref.read(largeTextProvider.notifier).state = v,
          ),
          _SwitchRow(
            icon: Icons.contrast_rounded,
            title: 'High contrast',
            subtitle: 'Stronger colour contrast',
            value: ref.watch(highContrastProvider),
            onChanged: (v) =>
                ref.read(highContrastProvider.notifier).state = v,
          ),
          _SwitchRow(
            icon: Icons.wifi_off_rounded,
            title: 'Simulate offline',
            subtitle: 'Force offline mode for testing sync',
            value: ref.watch(simulateOfflineProvider),
            onChanged: (v) =>
                ref.read(simulateOfflineProvider.notifier).state = v,
          ),
          group('Privacy & location'),
          _SwitchRow(
            icon: Icons.place_outlined,
            title: 'Default to fuzzy location',
            subtitle: 'New tree logs publish ±500 m by default',
            value: defaultFuzzy,
            onChanged: fuzzyAsync.isLoading
                ? null
                : (v) => ref.read(defaultFuzzyLocationProvider.notifier).set(v),
          ),
          _SettingRow(
            Icons.lock_outline_rounded,
            'Photo EXIF stripping',
            'GPS removed on-device and on the server · Always on',
            () => _showInfoDialog(
              context,
              'Photo EXIF stripping',
              'mwavuli strips location and camera metadata from photos before '
              'upload and again on the server. This cannot be turned off.',
            ),
          ),
          _SettingRow(
            Icons.shield_outlined,
            'My reports',
            'Content you have flagged for review',
            () => _showReportsSheet(context),
          ),
          group('Data & account (GDPR)'),
          _SettingRow(
            Icons.download_outlined,
            'Export my data',
            'Download everything as JSON or CSV',
            () => _exportData(context),
          ),
          _SettingRow(
            Icons.sync_rounded,
            'Offline & sync',
            'Encrypted on-device cache · $queued queued',
            () => _showSyncSheet(context),
          ),
          _SettingRow(Icons.delete_outline_rounded, 'Delete account',
              'Full data purge within 30 days', () => _confirmDelete(context),
              danger: true),
          group('Session'),
          _SettingRow(Icons.logout_rounded, 'Log out',
              'Sign out of this device', () => _logout(context)),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, MeProfile profile) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(profile: profile),
    );
    if (!context.mounted) return;

    ref.invalidate(profileProvider);
    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated'),
          behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _shareProfile(BuildContext context, ProfileData data) async {
    final p = data.profile;
    final text =
        '${p.displayName} (${p.handle}) on mwavuli — ${data.treeCount} trees logged'
        '${p.locationLabel == null ? '' : ' · ${p.locationLabel}'}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profile summary copied'),
        behavior: SnackBarBehavior.floating));
  }

  Future<void> _showSocialList(
    BuildContext context,
    String title,
    bool following,
  ) async {
    try {
      final api = ref.read(apiClientProvider);
      final items =
          following ? await api.fetchFollowing() : await api.fetchFollowers();
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Palette.cream50,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          final maxH = MediaQuery.sizeOf(ctx).height * 0.72;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(ctx).textTheme.titleMedium),
                        ),
                        Text('${items.length}',
                            style:
                                TextStyle(color: ctx.earth.ink3, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No one here yet.'),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: ctx.earth.line),
                        itemBuilder: (_, i) {
                          final u = items[i];
                          final name = u['displayName'] as String? ?? 'User';
                          final handle = u['username'] as String? ?? '';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Palette.green600,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('@$handle',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not load list'),
          behavior: SnackBarBehavior.floating));
    }
  }

  void _showInfoDialog(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _showReportsSheet(BuildContext context) async {
    try {
      final items = await ref.read(apiClientProvider).fetchMyReports();
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Palette.cream50,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          final maxH = MediaQuery.sizeOf(ctx).height * 0.72;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('My reports',
                        style: Theme.of(ctx).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('You have not filed any reports.'),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: ctx.earth.line),
                          itemBuilder: (_, i) {
                            final r = items[i];
                            final reason = (r['reason'] as String? ?? 'other')
                                .replaceAll('_', ' ');
                            final status = r['status'] as String? ?? 'open';
                            final type = r['targetType'] as String? ?? 'tree';
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(reason,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              subtitle: Text('$type · $status',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12, color: ctx.earth.ink3)),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not load reports'),
          behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _showSyncSheet(BuildContext context) async {
    final queued = await ref.read(syncServiceProvider).pendingCount();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.cream50,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Offline sync', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                queued == 0
                    ? 'No tree logs waiting to upload.'
                    : '$queued tree log${queued == 1 ? '' : 's'} queued on this device.',
                style: TextStyle(fontSize: 14, color: ctx.earth.ink2),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: queued == 0
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        try {
                          await ref.read(syncServiceProvider).flush(
                                ref.read(apiClientProvider),
                                ref.read(uploadServiceProvider),
                                ref.read(photoCacheProvider),
                              );
                          ref.invalidate(syncQueueCountProvider);
                          ref.invalidate(profileProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Sync attempted'),
                                    behavior: SnackBarBehavior.floating));
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Sync failed'),
                                    behavior: SnackBarBehavior.floating));
                          }
                        }
                      },
                child: const Text('Sync now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export format'),
        content: const Text('Choose how to download your data.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'json'),
              child: const Text('JSON')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'csv'),
              child: const Text('CSV')),
        ],
      ),
    );
    if (format == null || !context.mounted) return;
    try {
      await ref.read(apiClientProvider).exportData(format: format);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Export ready ($format)'),
            behavior: SnackBarBehavior.floating));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Export failed'),
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    // Capture router before await — auth flip rebuilds this route to a spinner.
    final router = GoRouter.of(context);
    await ref.read(authControllerProvider.notifier).logout();
    router.go('/welcome');
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
            'Your account and all your data will be permanently purged within '
            '30 days (GDPR erasure). This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(apiClientProvider).scheduleDeletion();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Deletion scheduled'),
                      behavior: SnackBarBehavior.floating));
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Could not schedule deletion'),
                      behavior: SnackBarBehavior.floating));
                }
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: Palette.danger)),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.profile,
    this.previewName,
    this.previewBytes,
    this.avatarUrlOverride,
  });
  final MeProfile profile;

  /// When set, shows initials from this name instead of [profile.displayName].
  final String? previewName;

  /// Local preview while a new avatar is uploading.
  final Uint8List? previewBytes;

  /// Server avatar URL after upload completes (overrides [profile.avatarUrl]).
  final String? avatarUrlOverride;

  String get _initials {
    final name = (previewName ?? profile.displayName).trim();
    if (name.isEmpty) return profile.initials;
    final first =
        name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).first;
    return first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final remoteUrl = avatarUrlOverride ?? profile.avatarUrl;
    final showRemote =
        previewBytes == null && previewName == null && remoteUrl != null && remoteUrl.isNotEmpty;
    return CircleAvatar(
      radius: 40,
      backgroundColor: Colors.white,
      child: previewBytes != null
          ? CircleAvatar(
              radius: 36,
              backgroundColor: Palette.green600,
              backgroundImage: MemoryImage(previewBytes!),
            )
          : showRemote
              ? CircleAvatar(
                  radius: 36,
                  backgroundColor: Palette.green600,
                  backgroundImage: NetworkImage(remoteUrl),
                  onBackgroundImageError: (_, __) {},
                )
              : CircleAvatar(
                  radius: 36,
                  backgroundColor: Palette.green600,
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'RobotoSlab',
                    ),
                  ),
                ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});
  final MeProfile profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _locCtrl;
  bool _loading = false;
  bool _locating = false;
  bool _avatarUploading = false;
  Uint8List? _pendingAvatarBytes;
  String? _avatarUrlOverride;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.displayName);
    _bioCtrl = TextEditingController(text: widget.profile.bio ?? '');
    _locCtrl = TextEditingController(text: widget.profile.locationLabel ?? '');
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _locCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Display name is required.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).updateMe(
            displayName: name,
            bio: _bioCtrl.text.trim(),
            locationLabel: _locCtrl.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not save your profile. Check your connection.';
        });
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final loc = ref.read(locationServiceProvider);
      final geocode = ref.read(nominatimGeocodeProvider);
      final label = await loc.currentLocationLabel(geocode);
      if (!mounted) return;
      if (label == null || label.isEmpty) {
        setState(() => _error =
            'Location unavailable. Enable location access in Settings.');
        return;
      }
      _locCtrl.text = label;
      _focusScopeUnfocus();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not look up your location.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _focusScopeUnfocus() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _changeAvatar() async {
    final earth = context.earth;
    final source = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Palette.cream50,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: earth.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, false),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _pickAndUploadAvatar(fromGallery: source);
  }

  Future<void> _pickAndUploadAvatar({required bool fromGallery}) async {
    try {
      final photo = await ref
          .read(photoCaptureProvider)
          .pickAvatar(fromGallery: fromGallery);
      if (photo == null || !mounted) return;

      setState(() {
        _pendingAvatarBytes = photo.bytes;
        _avatarUploading = true;
        _error = null;
      });

      final updated = await ref.read(profileRepositoryProvider).uploadAvatar(
            photo.bytes,
            contentType: photo.contentType,
          );

      if (!mounted) return;
      setState(() {
        _avatarUploading = false;
        if (updated != null) {
          _avatarUrlOverride = updated.avatarUrl;
          _pendingAvatarBytes = null;
        }
      });

      if (updated != null) {
        ref.invalidate(profileProvider);
      } else if (mounted) {
        setState(() => _error =
            'Avatar uploaded. It may take a moment to appear everywhere.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _avatarUploading = false;
        _pendingAvatarBytes = null;
        _error = 'Could not upload avatar. Check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final earth = context.earth;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Palette.cream50,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: earth.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Edit profile',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        'Update how you appear to the community.',
                        style: TextStyle(fontSize: 14, color: earth.ink2),
                      ),
                      const SizedBox(height: 22),
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _ProfileAvatar(
                                  profile: widget.profile,
                                  previewName: _pendingAvatarBytes == null
                                      ? _nameCtrl.text
                                      : null,
                                  previewBytes: _pendingAvatarBytes,
                                  avatarUrlOverride: _avatarUrlOverride,
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Material(
                                    color: Palette.cream50,
                                    elevation: 2,
                                    shadowColor: Colors.black26,
                                    shape: const CircleBorder(
                                      side: BorderSide(
                                        color: Palette.green700,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: (_loading || _avatarUploading)
                                          ? null
                                          : _changeAvatar,
                                      child: Padding(
                                        padding: const EdgeInsets.all(9),
                                        child: _avatarUploading
                                            ? SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: earth.ink3,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.camera_alt_outlined,
                                                size: 18,
                                                color: Palette.green700,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.profile.handle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: earth.ink3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Username cannot be changed',
                              style: TextStyle(fontSize: 11.5, color: earth.ink3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _ProfileFormLabel('Display name'),
                      _ProfileFormField(
                        controller: _nameCtrl,
                        hint: 'How your name appears on your logs',
                        icon: Icons.badge_outlined,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      const _ProfileFormLabel('Bio'),
                      _ProfileFormField(
                        controller: _bioCtrl,
                        hint: 'Share what trees or places you love mapping',
                        icon: Icons.notes_outlined,
                        maxLines: 4,
                        maxLength: 500,
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: 16),
                      const _ProfileFormLabel('Location'),
                      LocationAutocompleteField(
                        controller: _locCtrl,
                        enabled: !_loading,
                        locating: _locating,
                        onUseCurrentLocation: _useCurrentLocation,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Palette.danger, fontSize: 13)),
                      ],
                      const SizedBox(height: 22),
                      ElevatedButton(
                        onPressed: _loading ? null : _save,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save changes'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed:
                            _loading ? null : () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileFormLabel extends StatelessWidget {
  const _ProfileFormLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Palette.ink,
          ),
        ),
      );
}

class _ProfileFormField extends StatelessWidget {
  const _ProfileFormField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final earth = context.earth;
    // Multi-line fields (bio) should not use the theme pill radius.
    final radius = BorderRadius.circular(maxLines > 1 ? 12 : Dims.radiusPill);
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: earth.line, width: 1.5),
    );
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      style: const TextStyle(fontSize: 15, color: Palette.ink),
      decoration: InputDecoration(
        hintText: hint,
        counterStyle: TextStyle(fontSize: 11, color: earth.ink3),
        prefixIcon: maxLines > 1
            ? Padding(
                padding: const EdgeInsets.only(left: 14, right: 10, top: 12),
                child: Align(
                  alignment: Alignment.topCenter,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Icon(icon, size: 20, color: Palette.green700),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(icon, size: 20, color: Palette.green700),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffixIcon,
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: Palette.green500, width: 2),
        ),
      ),
    );
  }
}

class _ContributionsChart extends StatelessWidget {
  const _ContributionsChart({required this.contributions});
  final List<MonthlyContribution> contributions;

  @override
  Widget build(BuildContext context) {
    final data = MonthlyContribution.fillLastSixMonths(contributions);
    final maxCount = data.map((d) => d.count).reduce((a, b) => a > b ? a : b);
    final scaleMax = maxCount > 0 ? maxCount : 1;
    final hasLogs = maxCount > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x24241D14))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Trees logged',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'last 6 months',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: MediaQuery.sizeOf(context).width < 340 ? 10.5 : 11.5,
                    color: const Color(0xFF77694F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasLogs)
            const Text('No logs in the last 6 months.',
                style: TextStyle(fontSize: 12, color: Color(0xFF77694F))),
          LayoutBuilder(
              builder: (context, constraints) {
                final barWidth =
                    (constraints.maxWidth / data.length * 0.5).clamp(8.0, 22.0);
                final monthSize =
                    constraints.maxWidth < 320 ? 9.0 : 10.5;
                final aspect = constraints.maxWidth < 340 ? 2.5 : 2.85;

                return AspectRatio(
                  aspectRatio: aspect,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final d in data)
                        Expanded(
                          child: _ContributionMonthColumn(
                            month: d.month,
                            monthSize: monthSize,
                            count: d.count,
                            scaleMax: scaleMax,
                            barWidth: barWidth,
                            isPeak: d.count == maxCount && d.count > 0,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ContributionMonthColumn extends StatelessWidget {
  const _ContributionMonthColumn({
    required this.month,
    required this.monthSize,
    required this.count,
    required this.scaleMax,
    required this.barWidth,
    required this.isPeak,
  });

  final String month;
  final double monthSize;
  final int count;
  final int scaleMax;
  final double barWidth;
  final bool isPeak;

  @override
  Widget build(BuildContext context) {
    final monthBand = (MediaQuery.textScalerOf(context).scale(monthSize) + 4)
        .clamp(12.0, 24.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plotHeight =
              (constraints.maxHeight - monthBand).clamp(0.0, constraints.maxHeight);

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: plotHeight,
                child: _ContributionBar(
                  count: count,
                  scaleMax: scaleMax,
                  barWidth: barWidth,
                  isPeak: isPeak,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: monthBand,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      month,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: monthSize,
                        color: const Color(0xFF77694F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ContributionBar extends StatelessWidget {
  const _ContributionBar({
    required this.count,
    required this.scaleMax,
    required this.barWidth,
    required this.isPeak,
  });

  final int count;
  final int scaleMax;
  final double barWidth;
  final bool isPeak;

  @override
  Widget build(BuildContext context) {
    final spacerFlex = (scaleMax - count).clamp(0, scaleMax);
    final barFlex = count.clamp(0, scaleMax);
    final showBaseline = count == 0;

    return ClipRect(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.bottomCenter,
        children: [
          Column(
            children: [
              if (spacerFlex > 0)
                Expanded(flex: spacerFlex, child: const SizedBox.shrink()),
              if (barFlex > 0)
                Expanded(
                  flex: barFlex,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: barWidth,
                      decoration: BoxDecoration(
                        color: isPeak ? Palette.green700 : Palette.green500,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                )
              else if (showBaseline)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: barWidth,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Palette.green500.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
          if (isPeak)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Palette.green800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow(this.icon, this.title, this.subtitle, this.onTap,
      {this.danger = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Palette.danger : Palette.green700;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x18241D14)))),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: danger ? const Color(0xFFF6E0DA) : Palette.green50,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: danger ? Palette.danger : Palette.ink)),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF77694F))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF77694F)),
        ]),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x18241D14)))),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: Palette.green50, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 19, color: Palette.green700),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF77694F))),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }
}
