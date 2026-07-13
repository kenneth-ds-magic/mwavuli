import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import 'auth_controller.dart';
import 'auth_errors.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _name = TextEditingController();
  final _pw = TextEditingController();
  final _birthYear = TextEditingController();
  bool _accept = false, _loading = false, _obscure = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _username, _name, _pw, _birthYear]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    final year = int.tryParse(_birthYear.text.trim());
    if (_email.text.trim().isEmpty || !_email.text.contains('@')) {
      return 'Enter a valid email.';
    }
    if (_username.text.trim().length < 3) return 'Username must be 3+ characters.';
    if (_name.text.trim().isEmpty) return 'Enter a display name.';
    if (_pw.text.length < 8) return 'Password must be at least 8 characters.';
    if (year == null || year < 1900) return 'Enter your birth year.';
    if (DateTime.now().year - year < 13) {
      return 'You must be at least 13 to use mwavuli.';
    }
    if (!_accept) return 'Please accept the Terms & Privacy Policy.';
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authControllerProvider.notifier).register(
            email: _email.text.trim(),
            username: _username.text.trim(),
            password: _pw.text,
            displayName: _name.text.trim(),
            birthYear: int.parse(_birthYear.text.trim()),
          );
      if (mounted) context.go('/explore');
    } catch (e) {
      if (!mounted) return;
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
            Text('Create your account', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Join the community mapping the world\'s trees.',
                style: TextStyle(color: earth.ink2, fontSize: 14.5)),
            const SizedBox(height: 22),
            _field(_email, 'Email', keyboard: TextInputType.emailAddress),
            _field(_username, 'Username'),
            _field(_name, 'Display name'),
            _field(_birthYear, 'Birth year', keyboard: TextInputType.number),
            TextField(
              controller: _pw,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              value: _accept,
              onChanged: (v) => setState(() => _accept = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: Palette.green700,
              title: Text(
                'I\'m 13+ and accept the Terms & Privacy Policy. GPS is stripped from shared photos by default.',
                style: TextStyle(fontSize: 12.5, color: earth.ink2),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: Palette.danger)),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Create account'),
            ),
            Center(
              child: TextButton(
                onPressed: () => context.push('/login'),
                child: const Text('Already have an account? Log in',
                    style: TextStyle(
                        color: Palette.green700, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        textInputAction: TextInputAction.next,
        decoration:
            InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
