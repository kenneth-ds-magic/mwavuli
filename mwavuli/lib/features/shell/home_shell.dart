import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../widgets/offline_banner.dart';

/// Persistent app frame: offline banner + tab body + thumb-zone bottom bar
/// with a centered camera FAB (the primary "Log a tree" action).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: shell),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _CameraFab(onTap: () => context.push('/log')),
      bottomNavigationBar: _BottomBar(shell: shell),
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

class _NavItem extends StatelessWidget {
  const _NavItem(this.shell, this.index, this.icon, this.label);
  final StatefulNavigationShell shell;
  final int index;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final selected = shell.currentIndex == index;
    final color = selected ? Palette.green700 : context.earth.ink3;
    return Expanded(
      child: InkResponse(
        onTap: () => shell.goBranch(index,
            initialLocation: index == shell.currentIndex),
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
