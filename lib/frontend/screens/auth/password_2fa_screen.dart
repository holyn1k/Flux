import 'package:flutter/material.dart';
import 'package:flux/backend/modules/account/account_models.dart';
import 'package:flux/core/protocol/packet.dart';
import 'package:flux/l10n/app_localizations.dart';
import 'package:flux/main.dart';
import 'package:material_symbols_icons/symbols.dart';
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
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);
    const primaryColor = Color(0xFF2C3E50);
    const accentColor = Color(0xFF1E88E5);
    const inputBgColor = Color(0xFFF7F8FA);
    const inputBorderColor = Color(0xFFD6D9E0);

    final hasText = _passwordController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'flux',
          style: TextStyle(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Двухфакторная аутентификация',
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Введите пароль для завершения входа',
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
              if (widget.hint != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD1DBE5)),
                  ),
                  child: Text(
                    'Подсказка: ${widget.hint}',
                    style: const TextStyle(
                      color: Color(0xFF37474F),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                autofocus: true,
                enabled: !_isLoading,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Пароль',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: inputBgColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: inputBorderColor,
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: accentColor,
                      width: 1.8,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: inputBorderColor,
                      width: 1.2,
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: AnimatedSlashIcon(
                      icon: Symbols.visibility,
                      slashedIcon: Symbols.visibility_off,
                      slashed: _isPasswordVisible,
                      color: const Color(0xFF616161),
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
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    onPressed: (_isLoading || !hasText) ? null : _checkPassword,
                    backgroundColor: hasText
                        ? primaryColor
                        : const Color(0xFFE2E5EB),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: _isLoading
                        ? const SmallSpinner(size: 24, color: Colors.white)
                        : Icon(
                            Symbols.arrow_forward,
                            color: hasText
                                ? Colors.white
                                : const Color(0xFF9E9E9E),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
