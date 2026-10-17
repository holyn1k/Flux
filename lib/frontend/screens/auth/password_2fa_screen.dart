import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../backend/modules/account/account_models.dart';
import '../../../core/protocol/packet.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../widgets/animated_slash_icon.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/login_success_screen.dart';
import '../../widgets/small_spinner.dart';
import 'session_stale_recovery.dart';

class Password2FAScreen extends StatefulWidget {
  final String trackId;
  final String? hint;

  const Password2FAScreen({super.key, required this.trackId, this.hint});

  @override
  State<Password2FAScreen> createState() => _Password2FAScreenState();
}

class _Password2FAScreenState extends State<Password2FAScreen>
    with SessionStaleRecovery {
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  String get connectionDroppedMessage => 'Соединение прервалось…';

  @override
  void initState() {
    super.initState();
    startSessionRecovery();
  }

  @override
  void dispose() {
    stopSessionRecovery();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void recoverStaleSession() {
    if (recovering || !mounted) return;
    recovering = true;
    showCustomNotification(context, 'Соединение прервалось — войдите заново');
    Navigator.of(context).pop();
  }

  Future<void> _checkPassword() async {
    if (_passwordController.text.isEmpty || _isLoading || recovering) return;

    if (sessionStale) {
      recoverStaleSession();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    var passed = false;
    try {
      final result = await accountModule.checkPassword(
        password: _passwordController.text,
        trackId: widget.trackId,
      );
      passed = true;

      if (!mounted) return;

      final loginResult = await accountModule.login(
        accountId: result.accountId,
        token: result.loginToken,
      );

      if (!mounted) return;

      final avatar = await precacheLoginAvatar(
        context,
        loginResult.profile.baseUrl,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (_, _, _) => LoginSuccessScreen(avatar: avatar),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      final l10n = AppLocalizations.of(context)!;
      if (!passed && (isSessionStateError(e) || sessionStale)) {
        recoverStaleSession();
      } else if (e is WrongPasswordException) {
        showCustomNotification(context, l10n.passwordEntryWrongPassword);
      } else {
        showCustomNotification(context, l10n.devicesGenericError('$e'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: cs.onSurfaceVariant),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.passwordEntryTitle,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.passwordEntrySubtitle,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
              if (widget.hint != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Подсказка: ${widget.hint}',
                  style: TextStyle(
                    color: cs.tertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    height: 54,
                    padding: const EdgeInsets.only(left: 16, right: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      autofocus: true,
                      enabled: !_isLoading,
                      style: TextStyle(color: cs.onSurface, fontSize: 14),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        suffixIcon: IconButton(
                          icon: AnimatedSlashIcon(
                            icon: Symbols.visibility,
                            slashedIcon: Symbols.visibility_off,
                            slashed: _isPasswordVisible,
                            color: cs.onSurfaceVariant,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _checkPassword(),
                    ),
                  ),
                  Positioned(
                    top: -8,
                    left: 12,
                    child: Container(
                      color: cs.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        AppLocalizations.of(context)!.passwordEntryHint,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _passwordController.text.isNotEmpty && !_isLoading
                      ? _checkPassword
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.onSurface,
                    foregroundColor: cs.surface,
                    disabledBackgroundColor: cs.onSurface.withValues(alpha: 0.12),
                    disabledForegroundColor: cs.onSurface.withValues(alpha: 0.38),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? SmallSpinner(size: 20, color: cs.surface)
                      : Text(
                          AppLocalizations.of(context)!.passwordEntryContinue.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
