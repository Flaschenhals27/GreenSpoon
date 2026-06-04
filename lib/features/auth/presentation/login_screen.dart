import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // Auth-State-Listener im Router übernimmt die Weiterleitung.
    } on AuthException catch (e) {
      if (mounted) _showError(_humanizeAuthError(e));
    } catch (_) {
      if (mounted) {
        _showError('Etwas ist schiefgelaufen. Bitte erneut versuchen.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _humanizeAuthError(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid_credentials')) {
      return 'Email oder Passwort sind nicht korrekt.';
    }
    if (m.contains('email not confirmed')) {
      return 'Bitte bestätige zuerst deine Email-Adresse.';
    }
    return 'Login fehlgeschlagen: ${e.message}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? GSColors.paper : GSColors.forest;
    final subtleColor = isDark
        ? GSColors.paper.withValues(alpha: 0.55)
        : GSColors.forest.withValues(alpha: 0.55);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Logo / Brand ───────────────────────
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: GSColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            '🥄',
                            style: TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Headline ───────────────────────────
                    Text(
                      'Willkommen zurück',
                      textAlign: TextAlign.center,
                      style: GSTypography.headline(
                        color: textColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Melde dich an, um deinen Vorrat zu sehen.',
                      textAlign: TextAlign.center,
                      style: GSTypography.body(
                        color: subtleColor,
                        size: 14,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ── Email ──────────────────────────────
                    _Label('Email', color: subtleColor),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'du@example.com',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Bitte Email eingeben';
                        }
                        if (!v.contains('@') || !v.contains('.')) {
                          return 'Keine gültige Email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Passwort ───────────────────────────
                    _Label('Passwort', color: subtleColor),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: subtleColor,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Bitte Passwort eingeben';
                        }
                        if (v.length < 6) {
                          return 'Mindestens 6 Zeichen';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // ── Passwort vergessen ─────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => context.go('/reset-password'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Passwort vergessen?',
                          style: GSTypography.body(
                            color: GSColors.primary,
                            size: 13,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Submit ─────────────────────────────
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: GSColors.paper,
                              ),
                            )
                          : const Text('Anmelden'),
                    ),
                    const SizedBox(height: 18),

                    // ── Wechsel zur Registrierung ──────────
                    Center(
                      child: TextButton(
                        onPressed:
                            _isLoading ? null : () => context.go('/signup'),
                        child: RichText(
                          text: TextSpan(
                            style: GSTypography.body(
                              color: subtleColor,
                              size: 13,
                            ),
                            children: [
                              const TextSpan(text: 'Noch kein Konto? '),
                              TextSpan(
                                text: 'Registrieren',
                                style: GSTypography.body(
                                  color: GSColors.primary,
                                  size: 13,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ],
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
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text.toUpperCase(), style: GSTypography.label(color: color)),
    );
  }
}
