import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/gs_colors.dart';
import '../../../core/theme/gs_typography.dart';
import '../providers/auth_providers.dart';

enum _Step { email, code, password }

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Step _step = _Step.email;
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Schritt 1: Code anfordern ─────────────────────────────────
  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetCode(_email);
      // Supabase meldet aus Sicherheitsgründen keinen Fehler, wenn die Email
      // nicht existiert — wir gehen also immer zum Code-Schritt weiter.
      if (mounted) {
        setState(() => _step = _Step.code);
        _showMessage('Code an $_email gesendet.');
      }
    } on AuthException catch (e) {
      _showMessage(_humanizeSendError(e));
    } catch (e) {
      _showMessage('Konnte keinen Code senden: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetCode(_email);
      _showMessage('Neuer Code an $_email gesendet.');
    } on AuthException catch (e) {
      _showMessage(_humanizeSendError(e));
    } catch (e) {
      _showMessage('Konnte keinen Code senden: $e');
    }
  }

  /// Übersetzt die häufigsten Supabase-Fehler beim Mailversand.
  String _humanizeSendError(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('rate') || m.contains('seconds') || m.contains('after')) {
      return 'Zu viele Anfragen — bitte ~1 Minute warten und erneut versuchen.';
    }
    if (m.contains('smtp') ||
        m.contains('sending') ||
        m.contains('confirmation email')) {
      return 'Server kann keine Mail senden (SMTP nicht eingerichtet). '
          'Bitte in Supabase prüfen.';
    }
    return 'Konnte keinen Code senden: ${e.message}';
  }

  // ── Schritt 2: Code prüfen ────────────────────────────────────
  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).verifyPasswordResetCode(
            email: _email,
            token: _codeController.text,
          );
      if (mounted) setState(() => _step = _Step.password);
    } on AuthException catch (_) {
      _showMessage('Code ist falsch oder abgelaufen.');
    } catch (_) {
      _showMessage('Etwas ist schiefgelaufen. Bitte erneut versuchen.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Schritt 3: Neues Passwort setzen ──────────────────────────
  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updatePassword(_passwordController.text);
      // Der User ist durch die Recovery-Session jetzt eingeloggt.
      if (mounted) {
        _showMessage('Passwort geändert. Du bist angemeldet.');
        context.go('/');
      }
    } on AuthException catch (e) {
      _showMessage('Passwort konnte nicht gesetzt werden: ${e.message}');
    } catch (_) {
      _showMessage('Etwas ist schiefgelaufen. Bitte erneut versuchen.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _back() {
    if (_isLoading) return;
    switch (_step) {
      case _Step.email:
        context.go('/login');
      case _Step.code:
        setState(() => _step = _Step.email);
      case _Step.password:
        setState(() => _step = _Step.code);
    }
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
                    // ── Zurück ──────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _back,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: subtleColor,
                        ),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: Text(
                          _step == _Step.email ? 'Zum Login' : 'Zurück',
                          style:
                              GSTypography.body(color: subtleColor, size: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Logo ────────────────────────────────
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: GSColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.lock_reset,
                            color: GSColors.cream,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    ..._buildStep(textColor, subtleColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStep(Color textColor, Color subtleColor) {
    return switch (_step) {
      _Step.email => _emailStep(textColor, subtleColor),
      _Step.code => _codeStep(textColor, subtleColor),
      _Step.password => _passwordStep(textColor, subtleColor),
    };
  }

  // ── Step 1 UI ─────────────────────────────────────────────────
  List<Widget> _emailStep(Color textColor, Color subtleColor) {
    return [
      _Headline('Passwort zurücksetzen', textColor),
      const SizedBox(height: 8),
      _Subtitle(
        'Gib deine Email ein — wir schicken dir einen Code zum Zurücksetzen.',
        subtleColor,
      ),
      const SizedBox(height: 36),
      _Label('Email', color: subtleColor),
      const SizedBox(height: 6),
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _sendCode(),
        decoration: const InputDecoration(hintText: 'du@example.com'),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Bitte Email eingeben';
          if (!v.contains('@') || !v.contains('.')) {
            return 'Keine gültige Email';
          }
          return null;
        },
      ),
      const SizedBox(height: 28),
      _PrimaryButton(
        label: 'Code anfordern',
        loading: _isLoading,
        onPressed: _sendCode,
      ),
    ];
  }

  // ── Step 2 UI ─────────────────────────────────────────────────
  List<Widget> _codeStep(Color textColor, Color subtleColor) {
    return [
      _Headline('Code eingeben', textColor),
      const SizedBox(height: 8),
      _Subtitle('Wir haben einen Code an $_email geschickt.', subtleColor),
      const SizedBox(height: 36),
      _Label('Code aus der Email', color: subtleColor),
      const SizedBox(height: 6),
      TextFormField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        // Supabase-OTP ist 6–10 Stellen lang (je nach Projekt-Einstellung),
        // daher keine feste Länge erzwingen.
        maxLength: 10,
        onFieldSubmitted: (_) => _verifyCode(),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: GSTypography.headline(color: textColor, size: 26)
            .copyWith(letterSpacing: 6),
        decoration: const InputDecoration(
          hintText: 'Code',
          counterText: '',
        ),
        validator: (v) {
          if (v == null || v.trim().length < 6) {
            return 'Bitte den Code aus der Email eingeben';
          }
          return null;
        },
      ),
      const SizedBox(height: 28),
      _PrimaryButton(
        label: 'Bestätigen',
        loading: _isLoading,
        onPressed: _verifyCode,
      ),
      const SizedBox(height: 14),
      Center(
        child: TextButton(
          onPressed: _isLoading ? null : _resendCode,
          child: Text(
            'Keinen Code erhalten? Erneut senden',
            style: GSTypography.body(color: GSColors.primary, size: 13),
          ),
        ),
      ),
    ];
  }

  // ── Step 3 UI ─────────────────────────────────────────────────
  List<Widget> _passwordStep(Color textColor, Color subtleColor) {
    return [
      _Headline('Neues Passwort', textColor),
      const SizedBox(height: 8),
      _Subtitle('Wähle ein neues Passwort für dein Konto.', subtleColor),
      const SizedBox(height: 36),
      _Label('Neues Passwort', color: subtleColor),
      const SizedBox(height: 6),
      TextFormField(
        controller: _passwordController,
        obscureText: _obscure,
        textInputAction: TextInputAction.next,
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
          if (v == null || v.isEmpty) return 'Bitte Passwort eingeben';
          if (v.length < 6) return 'Mindestens 6 Zeichen';
          return null;
        },
      ),
      const SizedBox(height: 16),
      _Label('Passwort wiederholen', color: subtleColor),
      const SizedBox(height: 6),
      TextFormField(
        controller: _confirmController,
        obscureText: _obscure,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _savePassword(),
        decoration: const InputDecoration(hintText: '••••••••'),
        validator: (v) {
          if (v != _passwordController.text) {
            return 'Passwörter stimmen nicht überein';
          }
          return null;
        },
      ),
      const SizedBox(height: 28),
      _PrimaryButton(
        label: 'Passwort speichern',
        loading: _isLoading,
        onPressed: _savePassword,
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────

class _Headline extends StatelessWidget {
  const _Headline(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GSTypography.headline(color: color, size: 30),
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GSTypography.body(color: color, size: 14),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });
  final String label;
  final bool loading;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: GSColors.cream,
              ),
            )
          : Text(label),
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
