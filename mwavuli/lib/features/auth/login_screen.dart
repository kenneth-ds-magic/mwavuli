import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import 'auth_controller.dart';
import 'auth_errors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _loading = false, _obscure = true;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_id.text.trim().isEmpty || _pw.text.isEmpty) {
      setState(() => _error = 'Enter your email/username and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authControllerProvider.notifier).login(_id.text.trim(), _pw.text);
      if (mounted) context.go('/explore');
    } catch (e) {
      if (!mounted) return;
      // Login may have succeeded while a navigation race threw — don't flash
      // a false credential/server error if we already have a session.
      if (ref.read(authControllerProvider) == AuthStatus.authenticated) {
        context.go('/explore');
        return;
      }
      setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final earth = context.earth;
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.go('/welcome'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
          children: [
            Text('Welcome back', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Log in to keep mapping.',
                style: TextStyle(color: earth.ink2, fontSize: 14.5)),
            const SizedBox(height: 24),
            TextField(
              controller: _id,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                  labelText: 'Email or username', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pw,
              obscureText: _obscure,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Palette.danger)),
            ],
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Log in'),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => context.push('/register'),
                child: const Text('New here? Create an account',
                    style: TextStyle(
                        color: Palette.green700, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
