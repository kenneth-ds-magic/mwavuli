import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
import '../../data/local/drift_tree_store.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/tree_repository.dart';
import '../../data/repositories/explore_repository.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_errors.dart';
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
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
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
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Palette.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded, size: 48, color: Palette.danger),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load your profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Palette.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection or try again.',
              style: TextStyle(fontSize: 13, color: context.earth.ink3),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(profileProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Palette.danger,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Log Out'),
                ),
              ],
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
        data.badges.isNotEmpty ? data.badges.first.name : 'Citizen Scientist';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Palette.cream50,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header Cover Banner & User Profile Identity
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 130,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Palette.green900, Palette.green700, Palette.green800],
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                alignment: Alignment.topRight,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _glassIconButton(
                          icon: Icons.share_outlined,
                          tooltip: 'Share profile',
                          onTap: () => _shareProfile(context, data),
                        ),
                        const SizedBox(width: 8),
                        _glassIconButton(
                          icon: Icons.settings_outlined,
                          tooltip: 'Settings',
                          onTap: () => setState(() => _tab = 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: Dims.gutter,
                bottom: -44,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          )
                        ],
                      ),
                      child: _ProfileAvatar(profile: data.profile),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 52),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dims.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.profile.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'RobotoSlab',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Palette.green900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Palette.green50,
                                  borderRadius: BorderRadius.circular( dimsPill ),
                                  border: Border.all(color: Palette.green300),
                                ),
                                child: Text(
                                  data.profile.handle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Palette.green800,
                                  ),
                                ),
                              ),
                              if (data.profile.locationLabel != null &&
                                  data.profile.locationLabel!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.place_outlined, size: 14, color: Palette.green700),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    data.profile.locationLabel!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.5, color: earth.ink3),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _editProfile(context, data.profile),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: earth.line, width: 1.5),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16, color: Palette.green800),
                      label: const Text(
                        'Edit',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Palette.green900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  data.profile.bio?.isNotEmpty == true
                      ? data.profile.bio!
                      : 'No bio added yet.',
                  style: TextStyle(fontSize: 13.5, color: earth.ink2, height: 1.45),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 13, color: earth.ink3),
                    const SizedBox(width: 4),
                    Text(
                      'Joined $joined',
                      style: TextStyle(fontSize: 12, color: earth.ink3, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Pill(primaryBadge, icon: Icons.eco_rounded, tone: PillTone.green),
                    Pill('Level ${data.profile.level} · ${data.profile.levelName}', tone: PillTone.gold),
                  ],
                ),
                const SizedBox(height: 18),
                // Metric Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _socialStatCard(
                        count: '${data.following}',
                        label: 'Following',
                        icon: Icons.people_outline_rounded,
                        onTap: () => _showSocialList(context, 'Following', true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _socialStatCard(
                        count: '${data.followers}',
                        label: 'Followers',
                        icon: Icons.groups_outlined,
                        onTap: () => _showSocialList(context, 'Followers', false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _socialStatCard(
                        count: '${data.treeCount}',
                        label: 'Trees Logged',
                        icon: Icons.park_outlined,
                        onTap: () => setState(() => _tab = 0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _segmentedTabBar(),
          const SizedBox(height: 12),
          if (_tab == 0) _treesPane(context, data.trees),
          if (_tab == 1) _statsPane(context, data),
          if (_tab == 2) _settingsPane(context, data.profile),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static const double dimsPill = 999;

  Widget _glassIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.22),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  Widget _socialStatCard({
    required String count,
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1F241D14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Palette.green700),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  count,
                  style: const TextStyle(
                    fontFamily: 'RobotoSlab',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Palette.green900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF77694F), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segmentedTabBar() {
    Widget tabButton(String title, IconData icon, int index) {
      final active = _tab == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Palette.green700 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? Palette.green700 : context.earth.line,
                width: 1.5,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Palette.green700.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active ? Colors.white : context.earth.ink2,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: active ? Colors.white : context.earth.ink2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dims.gutter),
      child: Row(
        children: [
          tabButton('My Trees', Icons.park_rounded, 0),
          const SizedBox(width: 8),
          tabButton('Impact', Icons.bar_chart_rounded, 1),
          const SizedBox(width: 8),
          tabButton('Settings', Icons.tune_rounded, 2),
        ],
      ),
    );
  }

  Widget _treesPane(BuildContext context, List<Tree> trees) {
    if (trees.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Palette.green50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.park_outlined, size: 40, color: Palette.green700),
            ),
            const SizedBox(height: 14),
            const Text(
              'No trees logged yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.green900),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap the camera button below to log your first tree!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.earth.ink3),
            ),
          ],
        ),
      );
    }

    final bodyWidth = MediaQuery.sizeOf(context).width - Dims.gutter * 2;
    final crossAxisCount = bodyWidth >= 520 ? 3 : 2;
    final aspectRatio = bodyWidth < 340 ? 0.85 : 0.90;

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
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1F241D14)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  )
                ],
              ),
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
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.commonName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Palette.green900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.createdAt == null
                              ? t.health.label
                              : '${t.health.label} · ${DateFormat.MMMd().format(t.createdAt!)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF77694F),
                            fontWeight: FontWeight.w500,
                          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          s,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _statsPane(BuildContext context, ProfileData data) {
    final parks = data.trees
        .map((t) => t.fuzzyLocation)
        .where((l) => l != null)
        .length;
    final tiles = [
      _statTile('${data.treeCount}', 'Trees Logged', Icons.park_outlined),
      _statTile('${data.speciesCount}', 'Species Identified', Icons.eco_outlined),
      _statTile('$parks', 'Mapped Locations', Icons.map_outlined),
      _statTile(_formatPoints(data.points), 'Impact Points', Icons.military_tech_outlined),
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
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: tiles[2]),
                  Expanded(child: tiles[3]),
                ]),
              ] else
                Row(children: [
                  for (final tile in tiles) Expanded(child: tile),
                ]),
              const SizedBox(height: 18),
              _ContributionsChart(contributions: data.contributions),
              if (data.badges.isNotEmpty) ...[
                const SizedBox(height: 22),
                const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 18, color: Palette.gold600),
                    SizedBox(width: 6),
                    Text(
                      'Earned Badges',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.green900),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final b in data.badges)
                      Pill(b.name, icon: Icons.military_tech_outlined, tone: PillTone.gold),
                  ],
                ),
              ],
              if (data.topSpecies.isNotEmpty) ...[
                const SizedBox(height: 22),
                const Row(
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 18, color: Palette.green700),
                    SizedBox(width: 6),
                    Text(
                      'Top Species Logged',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.green900),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._topSpeciesBars(data.topSpecies, maxLabelWidth: narrow ? 60 : 80),
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

  List<Widget> _topSpeciesBars(List<TopSpeciesStat> species, {double maxLabelWidth = 80}) {
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

  Widget _statTile(String v, String k, IconData icon) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1F241D14)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Palette.green700),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                v,
                style: const TextStyle(
                  fontFamily: 'RobotoSlab',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Palette.green900,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              k,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF77694F), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );

  Widget _speciesBar(String k, int n, double frac, Color c, {double labelWidth = 80}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              k,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Palette.ink),
            ),
          ),
          const SizedBox(width: 8),
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
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(
              '$n',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.green900),
            ),
          ),
        ]),
      );

  Widget _settingsPane(BuildContext context, MeProfile profile) {
    final earth = context.earth;
    final queueAsync = ref.watch(syncQueueCountProvider);
    final queued = queueAsync.maybeWhen(data: (n) => n, orElse: () => 0);
    final fuzzyAsync = ref.watch(defaultFuzzyLocationProvider);
    final defaultFuzzy = fuzzyAsync.maybeWhen(data: (v) => v, orElse: () => true);

    Widget groupTitle(String title, IconData icon) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Palette.green700),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: earth.ink3,
                ),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dims.gutter),
      child: Column(
        children: [
          groupTitle('Account & Credentials', Icons.manage_accounts_outlined),
          _cardGroup([
            _SettingRow(
              Icons.badge_outlined,
              'Edit Public Profile',
              'Display name, bio, location, avatar photo',
              () => _editProfile(context, profile),
            ),
            _SettingRow(
              Icons.key_outlined,
              'Account Credentials',
              'Username, email address, password',
              () => _editCredentials(context, profile),
              isLast: true,
            ),
          ]),
          groupTitle('Accessibility & Display', Icons.accessibility_new_rounded),
          _cardGroup([
            _SwitchRow(
              icon: Icons.text_fields_rounded,
              title: 'Larger text',
              subtitle: 'Scale UI text up (WCAG 1.4.4)',
              value: ref.watch(largeTextProvider),
              onChanged: (v) => ref.read(largeTextProvider.notifier).state = v,
            ),
            _SwitchRow(
              icon: Icons.contrast_rounded,
              title: 'High contrast',
              subtitle: 'Stronger colour contrast',
              value: ref.watch(highContrastProvider),
              onChanged: (v) => ref.read(highContrastProvider.notifier).state = v,
            ),
            _SwitchRow(
              icon: Icons.wifi_off_rounded,
              title: 'Simulate offline',
              subtitle: 'Force offline mode for testing sync',
              value: ref.watch(simulateOfflineProvider),
              onChanged: (v) => ref.read(simulateOfflineProvider.notifier).state = v,
              isLast: true,
            ),
          ]),
          groupTitle('Privacy & Location', Icons.shield_outlined),
          _cardGroup([
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
              'GPS removed on-device and on server · Always on',
              () => _showInfoDialog(
                context,
                'Photo EXIF stripping',
                'mwavuli strips location and camera metadata from photos before '
                'upload and again on the server. This cannot be turned off.',
              ),
            ),
            _SettingRow(
              Icons.flag_outlined,
              'My reports',
              'Content you have flagged for review',
              () => _showReportsSheet(context),
              isLast: true,
            ),
          ]),
          groupTitle('Data & Storage (GDPR)', Icons.folder_zip_outlined),
          _cardGroup([
            _SettingRow(
              Icons.download_outlined,
              'Export my data',
              'Download everything as JSON or CSV (GDPR Art. 20)',
              () => _exportData(context),
            ),
            _SettingRow(
              Icons.sync_rounded,
              'Offline & sync queue',
              'Encrypted SQLite storage · $queued queued',
              () => _showSyncSheet(context),
            ),
            _SettingRow(
              Icons.delete_outline_rounded,
              'Delete account',
              'Full data purge within 30 days',
              () => _confirmDelete(context),
              danger: true,
              isLast: true,
            ),
          ]),
          groupTitle('Session', Icons.account_circle_outlined),
          _cardGroup([
            _SettingRow(
              Icons.logout_rounded,
              'Log out',
              'Sign out of this device',
              () => _logout(context),
              isLast: true,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _cardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1F241D14)),
      ),
      child: Column(children: children),
    );
  }

  Future<void> _editProfile(BuildContext context, MeProfile profile) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Palette.cream50,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _EditProfileSheet(profile: profile),
    );
    if (!context.mounted) return;

    ref.invalidate(profileProvider);
    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated successfully'),
          behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _editCredentials(BuildContext context, MeProfile profile) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Palette.cream50,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _EditCredentialsSheet(profile: profile),
    );
    if (!context.mounted) return;

    ref.invalidate(profileProvider);
    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Account credentials updated successfully'),
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
        content: Text('Profile summary copied to clipboard'),
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
                            style: TextStyle(color: ctx.earth.ink3, fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No users found in this list yet.'),
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
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(name,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                    Text('My reports', style: Theme.of(ctx).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('You have not filed any content reports.'),
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
      builder: (ctx) {
        var syncing = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Offline Sync Queue', style: Theme.of(ctx).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      queued == 0
                          ? 'All tree logs are synced to the server.'
                          : '$queued tree log${queued == 1 ? '' : 's'} queued on this device.',
                      style: TextStyle(fontSize: 14, color: ctx.earth.ink2),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: (queued == 0 || syncing)
                          ? null
                          : () async {
                              setModalState(() => syncing = true);
                              try {
                                await ref.read(syncServiceProvider).flush(
                                      ref.read(apiClientProvider),
                                      ref.read(uploadServiceProvider),
                                      ref.read(photoCacheProvider),
                                      localStore: ref.read(localTreeStoreProvider),
                                    );
                                ref.invalidate(syncQueueCountProvider);
                                ref.invalidate(profileProvider);
                                ref.invalidate(feedProvider);
                                ref.invalidate(mapFeedProvider);
                                ref.invalidate(exploreProvider);
                                ref.invalidate(exploreFeedProvider);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Sync completed successfully'),
                                          behavior: SnackBarBehavior.floating));
                                }
                              } catch (_) {
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Sync failed. Please check connection.'),
                                          behavior: SnackBarBehavior.floating));
                                }
                              }
                            },
                      child: syncing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Sync Now'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<File> _saveExportToDownloads(String content, String format) async {
    final dateStr = DateTime.now().toIso8601String().split('T').first;
    final filename = 'mwavuli-export-$dateStr.$format';

    final candidateDirs = <Directory>[];

    try {
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) candidateDirs.add(downloadDir);
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) candidateDirs.add(extDir);
      } else {
        final dlDir = await getDownloadsDirectory();
        if (dlDir != null) candidateDirs.add(dlDir);
        candidateDirs.add(await getApplicationDocumentsDirectory());
      }
    } catch (_) {}

    try {
      candidateDirs.add(await getApplicationDocumentsDirectory());
    } catch (_) {}
    try {
      candidateDirs.add(await getTemporaryDirectory());
    } catch (_) {}

    for (final dir in candidateDirs) {
      try {
        final file = File('${dir.path}/$filename');
        await file.writeAsString(content);
        return file;
      } catch (_) {
        continue;
      }
    }

    final fallback = File('${(await getTemporaryDirectory()).path}/$filename');
    await fallback.writeAsString(content);
    return fallback;
  }

  Future<void> _exportData(BuildContext context) async {
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export format'),
        content: const Text(
          'Choose how to download your complete personal data (GDPR Art. 20).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'json'),
            child: const Text('JSON'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'csv'),
            child: const Text('CSV'),
          ),
        ],
      ),
    );
    if (format == null || !context.mounted) return;

    var loadingDialogShown = false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Assembling your GDPR export...'),
              ],
            ),
          ),
        ),
      ),
    );
    loadingDialogShown = true;

    try {
      final rawData =
          await ref.read(apiClientProvider).exportData(format: format);
      if (loadingDialogShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingDialogShown = false;
      }

      String content;
      if (rawData is String) {
        content = rawData;
      } else {
        const encoder = JsonEncoder.withIndent('  ');
        content = encoder.convert(rawData);
      }

      final file = await _saveExportToDownloads(content, format);

      if (!context.mounted) return;
      _showExportResultSheet(context, file, content, format);
    } catch (e) {
      if (context.mounted) {
        if (loadingDialogShown) {
          Navigator.of(context, rootNavigator: true).pop();
          loadingDialogShown = false;
        }
        var msg = 'Export failed: $e';
        if (e.toString().contains('429')) {
          msg = 'Rate limit reached. Please wait a moment before exporting again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showExportResultSheet(
    BuildContext context,
    File file,
    String content,
    String format,
  ) {
    final kbSize = (content.length / 1024).toStringAsFixed(1);
    final filename = file.path.split('/').last;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.cream50,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      color: Palette.green700, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'GDPR Data Export (${format.toUpperCase()})',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'File size: $kbSize KB · Tap below to save to any directory',
                style: TextStyle(fontSize: 12.5, color: ctx.earth.ink2),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: SelectableText(
                      content,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        color: Colors.lightGreenAccent,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.drive_file_move_outlined, size: 20),
                label: Text('Save .$format ...'.toUpperCase()),
                onPressed: () async {
                  try {
                    // ignore: deprecated_member_use
                    await Share.shareXFiles(
                      [XFile(file.path)],
                      text: 'Mwavuli GDPR Data Export ($filename)',
                    );
                  } catch (_) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open file saver'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy Content'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: content));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Copied export data to clipboard'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
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
  final String? previewName;
  final Uint8List? previewBytes;
  final String? avatarUrlOverride;

  String get _initials {
    final name = (previewName ?? profile.displayName).trim();
    if (name.isEmpty) return profile.initials;
    final parts =
        name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final remoteUrl = avatarUrlOverride ?? profile.avatarUrl;
    final String? validRemoteUrl =
        (previewBytes == null && remoteUrl != null && remoteUrl.trim().isNotEmpty)
            ? remoteUrl
            : null;

    final ImageProvider? imageProvider = previewBytes != null
        ? MemoryImage(previewBytes!)
        : (validRemoteUrl != null ? NetworkImage(validRemoteUrl) : null);

    return CircleAvatar(
      radius: 42,
      backgroundColor: Colors.white,
      child: CircleAvatar(
        radius: 38,
        backgroundColor: Palette.green700,
        backgroundImage: imageProvider,
        onBackgroundImageError: imageProvider != null ? (_, __) {} : null,
        child: Text(
          _initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
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
      if (_pendingAvatarBytes != null) {
        setState(() => _avatarUploading = true);
        try {
          await ref
              .read(profileRepositoryProvider)
              .uploadAvatar(_pendingAvatarBytes!);
        } catch (_) {}
      }

      await ref.read(profileRepositoryProvider).updateMe(
            displayName: name,
            bio: _bioCtrl.text.trim(),
            locationLabel: _locCtrl.text.trim(),
            avatarUrl: _pendingAvatarBytes == null ? _avatarUrlOverride : null,
          );
      ref.invalidate(profileProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _avatarUploading = false;
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
      FocusScope.of(context).unfocus();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not look up your location.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
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
              leading: const Icon(Icons.photo_camera_outlined, color: Palette.green700),
              title: const Text('Take photo', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, false),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Palette.green700),
              title: const Text('Choose from gallery', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _pickAvatar(fromGallery: source);
  }

  Future<void> _pickAvatar({required bool fromGallery}) async {
    try {
      final photo = await ref
          .read(photoCaptureProvider)
          .pickAvatar(fromGallery: fromGallery);
      if (photo == null || !mounted) return;

      setState(() {
        _pendingAvatarBytes = photo.bytes;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not pick image from ${fromGallery ? "gallery" : "camera"}.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final earth = context.earth;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        maxWidth: 560,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: earth.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 14, 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: Palette.green50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_outlined, size: 18, color: Palette.green700),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Profile',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontFamily: 'RobotoSlab',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Palette.green900,
                          ),
                        ),
                        Text(
                          'Update public profile details & photo',
                          style: TextStyle(fontSize: 12, color: earth.ink3),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: earth.ink3, size: 20),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 18, endIndent: 18),
            Flexible(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                padding: EdgeInsets.fromLTRB(18, 14, 18, 16 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Compact Profile Header & Avatar Card
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x1F241D14)),
                      ),
                      child: Row(
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
                                  color: Palette.green700,
                                  elevation: 2,
                                  shadowColor: Colors.black26,
                                  shape: const CircleBorder(
                                    side: BorderSide(color: Colors.white, width: 2),
                                  ),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: (_loading || _avatarUploading)
                                        ? null
                                        : _changeAvatar,
                                    child: Padding(
                                      padding: const EdgeInsets.all(7),
                                      child: _avatarUploading
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.camera_alt_rounded,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.profile.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Palette.green900,
                                  ),
                                ),
                                Text(
                                  widget.profile.handle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Palette.green700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                InkWell(
                                  onTap: (_loading || _avatarUploading) ? null : _changeAvatar,
                                  child: const Text(
                                    'Change Photo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Palette.green800,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Form Inputs Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x1F241D14)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _ProfileFormLabel('Display Name'),
                          _ProfileFormField(
                            controller: _nameCtrl,
                            hint: 'How your name appears on your tree logs',
                            icon: Icons.badge_outlined,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          const _ProfileFormLabel('Bio'),
                          _ProfileFormField(
                            controller: _bioCtrl,
                            hint: 'Share what trees or places you love mapping',
                            icon: Icons.notes_outlined,
                            maxLines: 2,
                            maxLength: 500,
                            textInputAction: TextInputAction.newline,
                          ),
                          const SizedBox(height: 12),
                          const _ProfileFormLabel('Location'),
                          LocationAutocompleteField(
                            controller: _locCtrl,
                            enabled: !_loading,
                            locating: _locating,
                            onUseCurrentLocation: _useCurrentLocation,
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Palette.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Palette.danger.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 16, color: Palette.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Palette.danger, fontSize: 12.5, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading ? null : () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              side: BorderSide(color: earth.line, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _save,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Save Changes',
                                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditCredentialsSheet extends ConsumerStatefulWidget {
  const _EditCredentialsSheet({required this.profile});
  final MeProfile profile;

  @override
  ConsumerState<_EditCredentialsSheet> createState() => _EditCredentialsSheetState();
}

class _EditCredentialsSheetState extends ConsumerState<_EditCredentialsSheet> {
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _currentPassCtrl;
  late final TextEditingController _newPassCtrl;
  late final TextEditingController _confirmPassCtrl;

  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.profile.username);
    _emailCtrl = TextEditingController(text: widget.profile.email);
    _currentPassCtrl = TextEditingController();
    _newPassCtrl = TextEditingController();
    _confirmPassCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final currentPass = _currentPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirmPass = _confirmPassCtrl.text;

    if (currentPass.isEmpty) {
      setState(() => _error = 'Please enter your current password to authorize changes.');
      return;
    }
    if (username.isEmpty || username.length < 3) {
      setState(() => _error = 'Username must be at least 3 characters long.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (newPass.isNotEmpty) {
      if (newPass.length < 8) {
        setState(() => _error = 'New password must be at least 8 characters long.');
        return;
      }
      if (newPass != confirmPass) {
        setState(() => _error = 'New password and confirm password do not match.');
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(profileRepositoryProvider).updateCredentials(
            username: username != widget.profile.username ? username : null,
            email: email != widget.profile.email ? email : null,
            currentPassword: currentPass,
            newPassword: newPass.isNotEmpty ? newPass : null,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = authErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final earth = context.earth;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        maxWidth: 560,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: earth.line,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 14, 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                              color: Palette.green50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.key_outlined, size: 18, color: Palette.green700),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Account Credentials',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontFamily: 'RobotoSlab',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Palette.green900,
                                  ),
                                ),
                                Text(
                                  'Update username, email, or password',
                                  style: TextStyle(fontSize: 12, color: earth.ink3),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: earth.ink3, size: 20),
                            onPressed: () => Navigator.pop(context, false),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 18, endIndent: 18),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                        padding: EdgeInsets.fromLTRB(18, 14, 18, 16 + bottomInset),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0x1F241D14)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _ProfileFormLabel('Username'),
                                  _ProfileFormField(
                                    controller: _usernameCtrl,
                                    hint: 'Your unique @handle',
                                    icon: Icons.alternate_email_rounded,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 12),
                                  const _ProfileFormLabel('Email Address'),
                                  _ProfileFormField(
                                    controller: _emailCtrl,
                                    hint: 'your.email@example.com',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 12),
                                  const _ProfileFormLabel('New Password (Optional)'),
                                  _ProfileFormField(
                                    controller: _newPassCtrl,
                                    hint: 'Leave blank to keep current password',
                                    icon: Icons.lock_outline_rounded,
                                    obscureText: _obscureNew,
                                    textInputAction: TextInputAction.next,
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const _ProfileFormLabel('Confirm New Password'),
                                  _ProfileFormField(
                                    controller: _confirmPassCtrl,
                                    hint: 'Re-enter new password',
                                    icon: Icons.lock_reset_rounded,
                                    obscureText: _obscureConfirm,
                                    textInputAction: TextInputAction.next,
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(height: 1),
                                  const SizedBox(height: 14),
                                  const _ProfileFormLabel('Current Password (Required)'),
                                  _ProfileFormField(
                                    controller: _currentPassCtrl,
                                    hint: 'Required to authorize changes',
                                    icon: Icons.security_rounded,
                                    obscureText: _obscureCurrent,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _save(),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                                      onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Palette.danger.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Palette.danger.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, size: 16, color: Palette.danger),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(color: Palette.danger, fontSize: 12.5, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _loading ? null : () => Navigator.pop(context, false),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                      side: BorderSide(color: earth.line, width: 1.5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _save,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Palette.green700,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(0, 44),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Update Credentials',
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final earth = context.earth;
    final radius = BorderRadius.circular(maxLines > 1 ? 12 : Dims.radiusPill);
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: earth.line, width: 1.5),
    );
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      obscureText: obscureText,
      keyboardType: keyboardType,
      scrollPadding: const EdgeInsets.all(24),
      onSubmitted: onSubmitted,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1F241D14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Trees Logged Activity',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.green900),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Last 6 months',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF77694F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasLogs)
            const Text(
              'No tree logs in the last 6 months.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF77694F)),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = (constraints.maxWidth / data.length * 0.45).clamp(8.0, 22.0);
              final monthSize = constraints.maxWidth < 320 ? 9.5 : 11.0;
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
    final monthBand = (MediaQuery.textScalerOf(context).scale(monthSize) + 4).clamp(12.0, 24.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plotHeight = (constraints.maxHeight - monthBand).clamp(0.0, constraints.maxHeight);

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
                          top: Radius.circular(6),
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
  const _SettingRow(
    this.icon,
    this.title,
    this.subtitle,
    this.onTap, {
    this.danger = false,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Palette.danger : Palette.green700;
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(16))
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: isLast ? null : const Border(bottom: BorderSide(color: Color(0x18241D14))),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: danger ? const Color(0xFFF6E0DA) : Palette.green50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: danger ? Palette.danger : Palette.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF77694F)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF77694F), size: 20),
          ],
        ),
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
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0x18241D14))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Palette.green50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: Palette.green700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Palette.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF77694F)),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
