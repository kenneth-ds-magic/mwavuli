import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../auth/auth_controller.dart';

/// Entry screen: brand hero + auth options. Returning users (with a stored
/// session) are sent straight to Explore once auth bootstraps.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthStatus>(authControllerProvider, (_, next) {
      // Only auto-enter the app from this screen. Login/register sit above
      // welcome via push — redirecting here races their own go('/explore')
      // and surfaces a false red error on the form.
      if (next != AuthStatus.authenticated) return;
      final path = GoRouterState.of(context).uri.path;
      if (path == '/welcome') context.go('/explore');
    });

    return Scaffold(
      backgroundColor: Palette.green800,
      body: Column(
        children: [
          Expanded(child: _hero(context)),
          _sheet(context),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.green700, Palette.green900],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.park_rounded, color: Color(0xFFEAF6DF), size: 52),
            ),
            const SizedBox(height: 22),
            Text('mwavuli',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(color: Colors.white, fontSize: 40)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48, vertical: 8),
              child: Text(
                'Identify, map, and celebrate the trees around you — '
                'with a community of thousands.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 15.5),
              ),
            ),
            const SizedBox(height: 26),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Prop(Icons.photo_camera_rounded, 'Snap & ID'),
                SizedBox(width: 18),
                _Prop(Icons.place_rounded, 'Geolocate'),
                SizedBox(width: 18),
                _Prop(Icons.groups_rounded, 'Community'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheet(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Palette.cream50,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: () => context.push('/register'),
                child: const Text('Create free account')),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
                onPressed: () => context.push('/login'),
                child: const Text('Log in')),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => context.go('/explore'),
            child: const Text('Explore as guest  →',
                style: TextStyle(
                    color: Palette.green700, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Text(
            'mwavuli is for ages 13+. By continuing you agree to our Terms & '
            'Privacy Policy. We strip GPS from shared photos by default.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: context.earth.ink3, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Prop extends StatelessWidget {
  const _Prop(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
