import 'dart:async';
import 'package:flutter/material.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'password_2fa_screen.dart';
import 'registration_screen.dart';
import 'session_stale_recovery.dart';
import '../../../backend/api.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/utils/sms_code_listener.dart';
import '../../../main.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/login_success_screen.dart';
import '../../widgets/small_spinner.dart';

class CodeConfirmationScreen extends StatefulWidget {
  final String phoneNumber;
  final String rawPhone;
  final String token;

  const CodeConfirmationScreen({
    super.key,
    required this.phoneNumber,
    required this.rawPhone,
    required this.token,
  });

  @override
  State<CodeConfirmationScreen> createState() => _CodeConfirmationScreenState();
}

class _CodeConfirmationScreenState extends State<CodeConfirmationScreen>
    with TickerProviderStateMixin, SessionStaleRecovery {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final SmsCodeListener _smsListener = SmsCodeListener();
  int _timerSeconds = 30;
  Timer? _timer;
  Timer? _errorTimer;

  String? _errorMessage;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  bool _keyboardScheduled = false;
  Animation<double>? _routeAnimation;
  AnimationStatusListener? _routeAnimationListener;

  late String _token;
  bool _verifying = false;

  @override
  String get connectionDroppedMessage =>
      'Соединение прервалось, восстанавливаем…';

  @override
  void initState() {
    super.initState();
    _token = widget.token;
    startSessionRecovery();
    _startTimer();
    _listenForSmsCode();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleKeyboardOpen();
  }

  @override
  void dispose() {
    if (_routeAnimationListener != null) {
      _routeAnimation?.removeStatusListener(_routeAnimationListener!);
    }
    _smsListener.dispose();
    stopSessionRecovery();
    _timer?.cancel();
    _errorTimer?.cancel();
    _shakeController.dispose();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Future<void> recoverStaleSession() async {
    if (recovering) return;
    setState(() => recovering = true);
    try {
      if (api.state != SessionState.online) {
        final back = await api.stateStream
            .firstWhere((s) => s == SessionState.online)
            .timeout(
              const Duration(seconds: 12),
              onTimeout: () => SessionState.disconnected,
            );
        if (back != SessionState.online) {
          if (mounted) {
            showCustomNotification(context, 'Нет соединения с сервером');
          }
          return;
        }
      }
      final fresh = await accountModule.requestCode(widget.rawPhone);
      if (!mounted) return;
      setState(() {
        _token = fresh.token;
        sessionEpoch = api.sessionEpoch;
        dropNotified = false;
        _codeController.clear();
        _errorMessage = null;
      });
      _startTimer();
      _listenForSmsCode();
      showCustomNotification(
        context,
        'Соединение восстановлено — выслали новый код',
      );
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, 'Не удалось обновить код: $e');
      }
    } finally {
      if (mounted) setState(() => recovering = false);
    }
  }

  void _scheduleKeyboardOpen() {
    if (_keyboardScheduled) return;
    _keyboardScheduled = true;

    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openKeyboard();
      });
      return;
    }

    _routeAnimation = animation;
    _routeAnimationListener = (status) {
      if (status == AnimationStatus.completed) {
        animation.removeStatusListener(_routeAnimationListener!);
        _routeAnimationListener = null;
        if (mounted) _openKeyboard();
      }
    };
    animation.addStatusListener(_routeAnimationListener!);
  }

  void _openKeyboard() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  void _startTimer() {
    _timer?.cancel();
    _timerSeconds = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timerSeconds > 0) {
          _timerSeconds--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  Future<void> _listenForSmsCode() async {
    await _smsListener.start((code) {
      if (!mounted) return;
      _applyAutoCode(code);
    });
  }

  void _applyAutoCode(String code) {
    if (_verifying || recovering) return;
    if (_codeController.text == code) return;
    _codeController.text = code;
    _codeController.selection = TextSelection.collapsed(offset: code.length);
    if (_errorMessage != null) _errorMessage = null;
    setState(() {});
    if (code.length == 6) _verifyCode();
  }

  void _showError(String message) {
    _errorTimer?.cancel();
    _shakeController.forward(from: 0);
    setState(() => _errorMessage = message);
    _errorTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _errorMessage = null);
    });
  }

  void _resendCode() {
    if (_timerSeconds == 0) {
      _startTimer();
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.length != 6 || recovering || _verifying) return;

    if (sessionStale) {
      recoverStaleSession();
      return;
    }

    setState(() => _verifying = true);
    var verified = false;
    try {
      final result = await accountModule.verifyCode(
        _codeController.text,
        _token,
      );
      verified = true;

      if (!mounted) return;

      if (result.requiresPassword) {
        final trackId = result.challengeTrackId;

        if (trackId == null) {
          showCustomNotification(
            context,
            AppLocalizations.of(context)!.codeError2faMissing,
          );
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                Password2FAScreen(trackId: trackId, hint: result.challengeHint),
          ),
        );
        return;
      }

      if (result.isRegistration) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RegistrationScreen(
              phoneNumber: widget.phoneNumber,
              registerToken: result.registerToken!,
              presetAvatars: result.presetAvatars,
            ),
          ),
        );
        return;
      }

      final loginResult = await accountModule.login();

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
      if (!verified && (isSessionStateError(e) || sessionStale)) {
        recoverStaleSession();
      } else {
        _showError(e.toString());
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasError = _errorMessage != null;

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
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Symbols.arrow_back_ios_new,
                              size: 20,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Center(
                          child: Icon(
                            Icons.check_circle_outline, // Business checkmark logo
                            size: 48,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'flux',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                widget.phoneNumber,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.codeConfirmationSmsSent,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(_shakeAnimation.value, 0),
                            child: child,
                          ),
                          child: Stack(
                            children: [
                              Opacity(
                                opacity: 0,
                                child: SizedBox(
                                  height: 0,
                                  width: 0,
                                  child: TextField(
                                    controller: _codeController,
                                    focusNode: _focusNode,
                                    keyboardType: TextInputType.number,
                                    autofillHints: const [AutofillHints.oneTimeCode],
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    onChanged: (value) {
                                      if (hasError) setState(() => _errorMessage = null);
                                      setState(() {});
                                      if (value.length == 6) _verifyCode();
                                    },
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _openKeyboard,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: List.generate(6, (index) {
                                    final isFocused =
                                        _codeController.text.length == index &&
                                        _focusNode.hasFocus;
                                    final hasValue =
                                        _codeController.text.length > index;
                                    final char = hasValue
                                        ? _codeController.text[index]
                                        : '';

                                    Color borderColor;
                                    if (hasError) {
                                      borderColor = Colors.red;
                                    } else if (isFocused || hasValue) {
                                      borderColor = Colors.black;
                                    } else {
                                      borderColor = Colors.black38;
                                    }

                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 44,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: borderColor,
                                            width: isFocused || hasValue || hasError ? 2.0 : 1.0,
                                          ),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 100),
                                        transitionBuilder:
                                            (Widget child, Animation<double> animation) {
                                          return ScaleTransition(
                                            scale: animation,
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: Text(
                                          char,
                                          key: ValueKey<String>(
                                            char + index.toString() + (hasError ? 'e' : ''),
                                          ),
                                          style: TextStyle(
                                            color: hasError ? Colors.red : Colors.black,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.center,
                          child: hasError
                              ? Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: AnimatedOpacity(
                                    opacity: hasError ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Center(
                                      child: Text(
                                        _errorMessage!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: GestureDetector(
                            onTap: _resendCode,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                color: _timerSeconds > 0 ? Colors.black54 : Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                decoration: _timerSeconds > 0 ? TextDecoration.none : TextDecoration.underline,
                              ),
                              child: Text(
                                _timerSeconds > 0
                                    ? l10n.codeResendInSeconds(_timerSeconds)
                                    : l10n.codeResendSms,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Text(
                            l10n.codeConfirmation2faWarning,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              height: 1.35,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: (recovering || _verifying || _codeController.text.length != 6)
                                  ? null
                                  : () {
                                      if (_codeController.text.length == 6) _verifyCode();
                                    },
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
                              child: recovering || _verifying
                                  ? const SmallSpinner(
                                      size: 20,
                                      color: Colors.white,
                                    )
                                  : Text(
                                      l10n.loginDone.toUpperCase(),
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
