import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/navigation/tab_refresh.dart';
import '../../widgets/offline_banner.dart';

bool _isShellPath(String path) =>
    path == '/explore' ||
    path == '/map' ||
    path == '/community' ||
    path == '/profile';

/// Full-screen routes pushed above the shell (not tabs).
bool _isOverlayPath(String path) =>
    path == '/log' ||
    path.startsWith('/tree/') ||
    path.startsWith('/user/');

/// Persistent app frame: offline banner + tab body + thumb-zone bottom bar
/// with a centered camera FAB (the primary "Log a tree" action).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  GoRouter? _router;
  String? _lastFullPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (!identical(_router, router)) {
      _router?.routerDelegate.removeListener(_onRouteChange);
      _router = router;
      _lastFullPath = router.state.uri.path;
      _router!.routerDelegate.addListener(_onRouteChange);
    }
  }

  void _onRouteChange() {
    final path = _router?.state.uri.path;
    if (path == null) return;
    final previous = _lastFullPath;
    _lastFullPath = path;
    if (previous == null) return;
    // Returning from log / tree / user → refresh the visible tab.
    if (_isOverlayPath(previous) && _isShellPath(path) && mounted) {
      refreshShellTab(ref, widget.shell.currentIndex);
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: widget.shell),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _CameraFab(onTap: () => context.push('/log')),
      bottomNavigationBar: _BottomBar(shell: widget.shell),
    );
  }
}

class _CameraFab extends StatelessWidget {
  const _CameraFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Log a tree',
      child: SizedBox(
        width: 64,
        height: 64,
        child: Material(
          shape: const CircleBorder(
              side: BorderSide(color: Colors.white, width: 4)),
          clipBehavior: Clip.antiAlias,
          color: Palette.green700,
          elevation: 4,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Palette.green600, Palette.green800],
                ),
              ),
              child: const Icon(Icons.photo_camera_rounded,
                  color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      elevation: 8,
      height: 74,
      padding: EdgeInsets.zero,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        children: [
          _NavItem(shell, 0, Icons.search_rounded, 'Explore'),
          _NavItem(shell, 1, Icons.map_outlined, 'Map'),
          const SizedBox(width: 64), // notch gap for the FAB
          _NavItem(shell, 2, Icons.groups_outlined, 'Community'),
          _NavItem(shell, 3, Icons.person_outline_rounded, 'Profile'),
        ],
      ),
    );
  }
}

class _NavItem extends ConsumerWidget {
  const _NavItem(this.shell, this.index, this.icon, this.label);
  final StatefulNavigationShell shell;
  final int index;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = shell.currentIndex == index;
    final color = selected ? Palette.green700 : context.earth.ink3;
    return Expanded(
      child: InkResponse(
        onTap: () {
          final leaving = shell.currentIndex != index;
          shell.goBranch(index, initialLocation: !leaving);
          // Fresh data when entering a tab, or when re-tapping the active tab.
          refreshShellTab(ref, index);
        },
        child: Semantics(
          selected: selected,
          button: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
