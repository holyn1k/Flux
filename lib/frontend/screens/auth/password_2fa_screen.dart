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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 44),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Symbols.arrow_back,
                                color: Colors.black54,
                                weight: 400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Center(
                          child: Column(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'flux',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -1.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Symbols.check_circle,
                                    color: Colors.blue,
                                    size: 28,
                                    fill: 1.0,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 48),
                              Text(
                                '${AppLocalizations.of(context)!.passwordEntryTitle.toUpperCase()} :',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppLocalizations.of(context)!.passwordEntrySubtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                              child: Text(
                                AppLocalizations.of(context)!.passwordEntryHint.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.black,
                                    width: 1.0,
                                  ),
                                ),
                              ),
                              child: TextField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                autofocus: true,
                                enabled: !_isLoading,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 2.0,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                                  suffixIcon: IconButton(
                                    icon: AnimatedSlashIcon(
                                      icon: Symbols.visibility,
                                      slashedIcon: Symbols.visibility_off,
                                      slashed: _isPasswordVisible,
                                      color: Colors.black54,
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
                            if (widget.hint != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Подсказка: ${widget.hint}',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24.0, top: 32.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _passwordController.text.isNotEmpty && !_isLoading
                                  ? _checkPassword
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.black12,
                                disabledForegroundColor: Colors.black38,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? SmallSpinner(size: 20, color: Colors.white)
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
