import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _name = TextEditingController();
  final _pw = TextEditingController();
  final _confirmPw = TextEditingController();
  final _birthYear = TextEditingController();
  bool _accept = false, _loading = false, _obscure = true, _obscureConfirm = true;
  String? _error;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    for (final c in [_email, _username, _name, _pw, _confirmPw, _birthYear]) {
      c.dispose();
    }
    _animController.dispose();
    super.dispose();
  }

  String? _validate() {
    final year = int.tryParse(_birthYear.text.trim());
    if (_email.text.trim().isEmpty || !_email.text.contains('@')) {
      return 'Please enter a valid email address.';
    }
    if (_username.text.trim().length < 3) {
      return 'Username must be at least 3 characters.';
    }
    if (_name.text.trim().isEmpty) {
      return 'Please enter a display name.';
    }
    if (_birthYear.text.trim().isEmpty || year == null || year < 1900) {
      return 'Please enter a valid birth year.';
    }
    if (DateTime.now().year - year < 13) {
      return 'You must be at least 13 years old to use Mwavuli.';
    }
    if (_pw.text.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (_confirmPw.text != _pw.text) {
      return 'Passwords do not match.';
    }
    if (!_accept) {
      return 'Please accept the Terms & Privacy Policy.';
    }
    return null;
  }

  Future<void> _submit() async {
    HapticFeedback.lightImpact();
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
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
    return Scaffold(
      backgroundColor: Palette.cream50,
      body: Stack(
        children: [
          // Background Forest Decorative Header Curve
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F2D12),
                    Palette.green800,
                    Palette.green700,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: -30,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Palette.gold500.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top Navigation AppBar Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: Material(
              color: Colors.white.withValues(alpha: 0.15),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => context.go('/welcome'),
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),

          // Main Registration Content Layout
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          // Brand Logo Badge & Title (Fixed Header)
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Palette.green900.withValues(alpha: 0.25),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.park_rounded,
                                size: 36,
                                color: Palette.green700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Mwavuli',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Join the community mapping the world\'s trees',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Responsive Registration Form Card
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.07),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                                border: Border.all(
                                  color: Palette.green700.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Fixed Card Title & Header Area
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(22, 18, 22, 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Create Account',
                                          style: TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold,
                                            color: Palette.ink,
                                          ),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          'Fill in your details to get started',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Palette.ink2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1, color: Color(0xFFF0F0F0)),

                                  // Scrollable Form Fields Area
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Email Input
                                          _buildTextField(
                                            controller: _email,
                                            label: 'Email address',
                                            hint: 'e.g. name@example.com',
                                            icon: Icons.email_outlined,
                                            keyboard: TextInputType.emailAddress,
                                            autofills: const [AutofillHints.email],
                                          ),
                                          const SizedBox(height: 12),

                                          // Username Input
                                          _buildTextField(
                                            controller: _username,
                                            label: 'Username',
                                            hint: 'e.g. tree_hunter',
                                            icon: Icons.alternate_email_rounded,
                                            autofills: const [AutofillHints.username],
                                          ),
                                          const SizedBox(height: 12),

                                          // Display Name Input
                                          _buildTextField(
                                            controller: _name,
                                            label: 'Display Name',
                                            hint: 'e.g. Jane Doe',
                                            icon: Icons.person_outline_rounded,
                                            autofills: const [AutofillHints.name],
                                          ),
                                          const SizedBox(height: 12),

                                          // Birth Year Input
                                          _buildTextField(
                                            controller: _birthYear,
                                            label: 'Birth Year',
                                            hint: 'e.g. 1998',
                                            icon: Icons.cake_outlined,
                                            keyboard: TextInputType.number,
                                          ),
                                          const SizedBox(height: 12),

                                          // Password Input
                                          TextField(
                                            controller: _pw,
                                            obscureText: _obscure,
                                            style: const TextStyle(fontSize: 14),
                                            textInputAction: TextInputAction.next,
                                            decoration: InputDecoration(
                                              labelText: 'Password',
                                              labelStyle: const TextStyle(fontSize: 13),
                                              hintText: 'At least 8 characters',
                                              hintStyle: const TextStyle(fontSize: 13),
                                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                              filled: true,
                                              fillColor: Palette.cream50.withValues(alpha: 0.5),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(16),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(16),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(16),
                                                borderSide: const BorderSide(color: Palette.green700, width: 2),
                                              ),
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                  _obscure
                                                      ? Icons.visibility_off_outlined
                                                      : Icons.visibility_outlined,
                                                  color: Palette.ink2,
                                                  size: 20,
                                                ),
                                                onPressed: () => setState(() => _obscure = !_obscure),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                          // Confirm Password Input
                                          TextField(
                                            controller: _confirmPw,
                                            obscureText: _obscureConfirm,
                                            style: const TextStyle(fontSize: 14),
                                            textInputAction: TextInputAction.done,
                                            onSubmitted: (_) => _submit(),
                                            decoration: InputDecoration(
                                              labelText: 'Confirm Password',
                                              labelStyle: const TextStyle(fontSize: 13),
                                              hintText: 'Re-enter your password',
                                              hintStyle: const TextStyle(fontSize: 13),
                                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                              filled: true,
                                              fillColor: Palette.cream50.withValues(alpha: 0.5),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(16),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(16),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(16),
                                                borderSide: const BorderSide(color: Palette.green700, width: 2),
                                              ),
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                  _obscureConfirm
                                                      ? Icons.visibility_off_outlined
                                                      : Icons.visibility_outlined,
                                                  color: Palette.ink2,
                                                  size: 20,
                                                ),
                                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                          // Terms & Privacy Checkbox
                                          InkWell(
                                            onTap: () => setState(() => _accept = !_accept),
                                            borderRadius: BorderRadius.circular(12),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: Checkbox(
                                                      value: _accept,
                                                      onChanged: (v) => setState(() => _accept = v ?? false),
                                                      activeColor: Palette.green700,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      'I\'m 13+ and accept the Terms & Privacy Policy. GPS location is stripped from shared photos by default.',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Palette.ink2.withValues(alpha: 0.9),
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          if (_error != null) ...[
                                            const SizedBox(height: 12),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Palette.danger.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Palette.danger.withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.error_outline_rounded,
                                                      size: 18, color: Palette.danger),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      _error!,
                                                      style: const TextStyle(
                                                        color: Palette.danger,
                                                        fontSize: 12.5,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 18),

                                          // Create Account Action Button
                                          SizedBox(
                                            width: double.infinity,
                                            height: 48,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Palette.green700,
                                                foregroundColor: Colors.white,
                                                elevation: 3,
                                                shadowColor: Palette.green700.withValues(alpha: 0.35),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                              ),
                                              onPressed: _loading ? null : _submit,
                                              child: _loading
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2.2,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  : const Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          'Create Account',
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            fontWeight: FontWeight.bold,
                                                            letterSpacing: 0.3,
                                                          ),
                                                        ),
                                                        SizedBox(width: 8),
                                                        Icon(Icons.arrow_forward_rounded, size: 18),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Already have an account Footer Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Palette.green700.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Already have an account?',
                                  style: TextStyle(
                                    color: Palette.ink2,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    context.push('/login');
                                  },
                                  child: const Text(
                                    'Log in',
                                    style: TextStyle(
                                      color: Palette.green700,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboard,
    List<String>? autofills,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      autofillHints: autofills,
      textInputAction: TextInputAction.next,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13),
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Palette.cream50.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Palette.green700, width: 2),
        ),
      ),
    );
  }
}
