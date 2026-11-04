import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flux/core/config/countries.dart';
import 'package:flux/l10n/app_localizations.dart';
import 'package:flux/l10n/terms_of_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'code_confirmation_screen.dart';
import 'token_login_screen.dart';
import 'phone_input_formatter.dart';
import 'proxy_settings_sheet.dart';
import 'server_settings_sheet.dart';
import '../profile/spoof_screen.dart';
import '../profile/debug_menu_screen.dart';
import '../digital_id/digital_id_web_screen.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/adaptive_shell.dart';
import '../../widgets/sheet_helpers.dart';
import '../../widgets/small_spinner.dart';
import '../../../backend/api.dart';
import '../../../core/protocol/packet.dart';
import '../../../main.dart';
import '../../../core/config/app_frost.dart';
import '../../../core/config/app_shape.dart';

class LoginScreen extends StatefulWidget {
  final int? returnToAccountId;

  const LoginScreen({super.key, this.returnToAccountId});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _countrySearchController = TextEditingController();

  late CountryName _selectedCountry;
  bool _isPhoneValid = false;
  bool _isTOSRead = false;
  bool _hasAcceptedWelcome = false;
  String? _phoneError;
  Timer? _phoneErrorTimer;
  int _logoTapCount = 0;
  Timer? _logoTapTimer;
  late SessionState _sessionState;
  StreamSubscription<SessionState>? _stateSub;
  String _countrySearchQuery = '';

  bool get _isOnline => _sessionState == SessionState.online;

  @override
  void initState() {
    super.initState();
    _sessionState = api.state;
    if (api.state == SessionState.disconnected) {
      unawaited(api.connect());
    }
    _stateSub = api.stateStream.listen((state) {
      if (mounted) setState(() => _sessionState = state);
    });

    _selectedCountry = countriesByCode['RU'] ?? allCountries.first;
    _clampCountryToAllowed();
    _checkTOS();
  }

  Future<void> _onBackPressed() async {
    if (_hasAcceptedWelcome) {
      setState(() => _hasAcceptedWelcome = false);
      return;
    }

    final returnId = widget.returnToAccountId;
    if (returnId != null) {
      await resetDigitalIdSession();
      try {
        await accountModule.switchAccount(returnId);
      } catch (_) {
        if (!mounted) return;
        showCustomNotification(context, 'Не удалось переключить аккаунт');
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdaptiveShell()),
        (route) => false,
      );
      return;
    }
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  void _clampCountryToAllowed() {
    final allowed = api.registrationCountries;
    if (allowed.any((c) => c.code == _selectedCountry.code)) return;
    _selectedCountry = allowed.firstWhere(
      (c) => c.code == 'RU',
      orElse: () => allowed.first,
    );
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _phoneErrorTimer?.cancel();
    _logoTapTimer?.cancel();
    _phoneController.dispose();
    _countrySearchController.dispose();
    super.dispose();
  }

  Future<void> _checkTOS() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isTOSRead = prefs.getBool('IsReadeTOS') ?? false;
        if (_isTOSRead) {
          _hasAcceptedWelcome = true;
        }
      });
    }
  }

  void _onLogoTap() {
    _logoTapTimer?.cancel();
    _logoTapTimer = Timer(const Duration(milliseconds: 600), () {
      _logoTapCount = 0;
    });
    _logoTapCount++;
    if (_logoTapCount >= 7) {
      _logoTapTimer?.cancel();
      _logoTapCount = 0;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DebugMenuScreen()),
      );
    }
  }

  Future<void> _markTOSRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('IsReadeTOS', true);
    if (mounted) {
      setState(() {
        _isTOSRead = true;
      });
    }
  }

  String _countryDisplayName(CountryName country) {
    final lang = Localizations.localeOf(context).languageCode;
    return country.displayName(lang);
  }

  String _phoneMaskHint(CountryName country) {
    return country.phoneMask.replaceAll('#', '0');
  }

  void _showLanguagePicker() {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final appContext = context;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 24.0,
              horizontal: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    l10n.loginLanguage,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ListTile(
                  title: Text(
                    l10n.languageNameRu,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    FluxApp.stateOf(
                      appContext,
                    )?.applyLocale(const Locale('ru'));
                  },
                ),
                ListTile(
                  title: Text(
                    l10n.languageNameEn,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    FluxApp.stateOf(
                      appContext,
                    )?.applyLocale(const Locale('en'));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTOS(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final termsLocale = Localizations.localeOf(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      isScrollControlled: true,
      shape: kSheetShape,
      builder: (context) {
        double progress = _isTOSRead ? 1.0 : 0.0;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final cs = Theme.of(context).colorScheme;
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 1.0,
              snap: true,
              snapSizes: const [0.7, 1.0],
              expand: false,
              builder: (context, scrollController) => Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.loginTermsOfUse,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Symbols.close, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: NotificationListener<ScrollUpdateNotification>(
                        onNotification: (ScrollUpdateNotification notification) {
                          if (_isTOSRead) return false;
                          final metrics = notification.metrics;
                          if (metrics.maxScrollExtent > 0) {
                            double newProgress =
                                metrics.pixels / metrics.maxScrollExtent;
                            newProgress = newProgress.clamp(0.0, 1.0);
                            if (newProgress >= 0.99 && !_isTOSRead) {
                              _markTOSRead();
                              setModalState(() {
                                progress = 1.0;
                              });
                            } else {
                              setModalState(() {
                                progress = newProgress;
                              });
                            }
                          }
                          return false;
                        },
                        child: ListView(
                          controller: scrollController,
                          children: [
                            Text(
                              termsOfServiceBody(termsLocale),
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 48,
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.only(
                            right: progress == 1.0 ? 56.0 : 0.0,
                          ),
                          child: Container(
                            height: 4,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progress < 1.0 ? progress : 1.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: progress == 1.0 ? 1.0 : 0.0,
                          curve: Curves.easeIn,
                          child: IgnorePointer(
                            ignoring: progress < 1.0,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              transform: Matrix4.translationValues(
                                progress == 1.0 ? 0 : 20,
                                0,
                                0,
                              ),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.pop(context),
                                  child: Icon(
                                    Symbols.check,
                                    color: cs.onPrimaryContainer,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPhoneError(String message) {
    _phoneErrorTimer?.cancel();
    setState(() => _phoneError = message);
    _phoneErrorTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _phoneError = null);
    });
  }

  void _showPhoneConfirmationDialog(String formattedPhone) {
    final screenContext = context;
    final l10n = AppLocalizations.of(screenContext)!;

    showGeneralDialog(
      context: screenContext,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: AppFrost.scrim(),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final cs = Theme.of(context).colorScheme;
        final curve = Curves.easeOutQuart.transform(anim1.value);
        return Opacity(
          opacity: anim1.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - curve)),
            child: Transform.scale(
              scale: 0.8 + (0.2 * curve),
              child: AlertDialog(
                backgroundColor: cs.surfaceContainerHigh,
                surfaceTintColor: Colors.transparent,
                shape: AppShape.dialogBorder,
                contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.loginConfirmPhoneTitle,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_selectedCountry.phoneCode} $formattedPhone',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          l10n.loginEdit,
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);

                          final fullPhone =
                              '${_selectedCountry.phoneCode}${_phoneController.text}';

                          if (!_isOnline) {
                            _showPhoneError(
                              'Нет соединения с сервером. Подождите подключения.',
                            );
                            return;
                          }

                          try {
                            final result = await accountModule.requestCode(
                              fullPhone,
                            );

                            if (!screenContext.mounted) return;
                            Navigator.push(
                              screenContext,
                              MaterialPageRoute(
                                builder: (context) => CodeConfirmationScreen(
                                  phoneNumber:
                                      '${_selectedCountry.phoneCode} $formattedPhone',
                                  rawPhone: fullPhone,
                                  token: result.token,
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!screenContext.mounted) return;
                            _showPhoneError(
                              isSessionStateError(e)
                                  ? 'Нет соединения с сервером. Попробуйте ещё раз.'
                                  : e.toString(),
                            );
                          }
                        },
                        child: Text(
                          l10n.loginDone,
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _validateAndSubmit() {
    if (!_isTOSRead) {
      _showTOS(context);
      return;
    }
    _showPhoneConfirmationDialog(_phoneController.text);
  }

  void _notifyConnecting() {
    showCustomNotification(context, 'Подключаемся к серверу, секунду…');
  }

  void _showServerSettingsSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (_) {
        return SafeArea(child: const ServerSettingsSheet());
      },
    );
  }

  void _showProxySettingsSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (_) {
        return SafeArea(child: const ProxySettingsSheet());
      },
    );
  }

  void _showSecurityOptions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 24.0,
              horizontal: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Symbols.security, color: cs.onSurface),
                  title: Text(
                    l10n.loginSpoofRedacted,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SpoofScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Symbols.vpn_lock, color: cs.onSurface),
                  title: Text(
                    l10n.loginProxy,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showProxySettingsSheet(context);
                  },
                ),
                ListTile(
                  leading: Icon(Symbols.dns, color: cs.onSurface),
                  title: Text(
                    l10n.loginChangeServer,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showServerSettingsSheet(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOtherLoginMethods(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 24.0,
              horizontal: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Symbols.qr_code_2, color: cs.onSurface),
                  title: Text(
                    l10n.loginSignInWithQr,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(Symbols.key, color: cs.onSurface),
                  title: Text(
                    l10n.loginSignInWithToken,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TokenLoginScreen(
                          returnToAccountId: widget.returnToAccountId,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Symbols.description, color: cs.onSurface),
                  title: Text(
                    l10n.loginSignInWithSessionFile,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<CountryName> get _filteredCountries {
    final allowed = api.registrationCountries;
    if (_countrySearchQuery.trim().isEmpty) return allowed;
    final query = _countrySearchQuery.trim().toLowerCase();
    return allowed.where((c) {
      final name = _countryDisplayName(c).toLowerCase();
      final code = c.phoneCode.toLowerCase();
      return name.contains(query) || code.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: !_hasAcceptedWelcome
              ? _buildWelcomeScreen(context)
              : _buildPhoneEntryScreen(context),
        ),
      ),
    );
  }

  Widget _buildWelcomeScreen(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      key: const ValueKey('WelcomeScreenView'),
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => _showSecurityOptions(context),
                icon: Icon(
                  Symbols.admin_panel_settings,
                  color: cs.onSurfaceVariant,
                ),
              ),
              IconButton(
                onPressed: _showLanguagePicker,
                icon: Icon(
                  Symbols.language,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onLogoTap,
            child: _buildFluxBubbleLogo(size: 130),
          ),
          const SizedBox(height: 36),
          Text(
            'Добро пожаловать\nв flux',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(
                    text: 'Ознакомьтесь с нашими ',
                  ),
                  TextSpan(
                    text: 'Политиками конфиденциальности',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _showTOS(context),
                  ),
                  const TextSpan(
                    text: '. Нажмите "Принять и продолжить", чтобы принять ',
                  ),
                  TextSpan(
                    text: 'Пользовательское соглашение',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _showTOS(context),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () async {
              await _markTOSRead();
              setState(() => _hasAcceptedWelcome = true);
            },
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: double.infinity,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.8),
                  width: 1.5,
                ),
                color: cs.primaryContainer.withValues(alpha: 0.3),
              ),
              child: Text(
                'Принять и продолжить',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPhoneEntryScreen(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filteredCountries;

    return Column(
      key: const ValueKey('PhoneEntryScreenView'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _onBackPressed,
                icon: Icon(Symbols.arrow_back, color: cs.onSurfaceVariant),
              ),
              GestureDetector(
                onTap: _onLogoTap,
                child: Text(
                  'flux',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _showOtherLoginMethods(context),
                icon: Icon(Symbols.more_vert, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'ВЕДИТЕ НОМЕР ТЕЛЕФОНА:',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.primary,
                width: 1.4,
              ),
              color: cs.surfaceContainerLowest,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  _countryFlag(_selectedCountry.code),
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 8),
                Text(
                  _selectedCountry.phoneCode,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 1.2,
                  height: 24,
                  color: cs.outlineVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: ValueKey(_selectedCountry.code),
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      PhoneInputFormatter(_selectedCountry),
                    ],
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: _phoneMaskHint(_selectedCountry),
                      hintStyle: TextStyle(
                        color: cs.outline.withValues(alpha: 0.6),
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      final digits = value.replaceAll(RegExp(r'\D'), '');
                      setState(() {
                        _isPhoneValid =
                            digits.length == _selectedCountry.phoneDigits;
                      });
                    },
                  ),
                ),
                if (_isPhoneValid)
                  IconButton(
                    onPressed: _isOnline ? _validateAndSubmit : _notifyConnecting,
                    icon: _isOnline
                        ? Icon(Symbols.arrow_circle_right, color: cs.primary, size: 28)
                        : SmallSpinner(size: 20, color: cs.primary),
                  ),
              ],
            ),
          ),
        ),
        if (_phoneError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 6, 28, 0),
            child: Text(
              _phoneError!,
              style: TextStyle(
                color: cs.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => Divider(
              color: cs.outlineVariant.withValues(alpha: 0.3),
              height: 1,
            ),
            itemBuilder: (context, index) {
              final item = filtered[index];
              final isSelected = item.code == _selectedCountry.code;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCountry = item;
                    _phoneController.clear();
                    _isPhoneValid = false;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    children: [
                      Text(
                        _countryFlag(item.code),
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _countryDisplayName(item),
                          style: TextStyle(
                            color: isSelected ? cs.primary : cs.onSurface,
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      Text(
                        item.phoneCode,
                        style: TextStyle(
                          color: isSelected ? cs.primary : cs.onSurfaceVariant,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: cs.outlineVariant,
                width: 1.2,
              ),
              color: cs.surfaceContainerLowest,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Symbols.search, color: cs.onSurfaceVariant, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _countrySearchController,
                    onChanged: (text) {
                      setState(() => _countrySearchQuery = text);
                    },
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ПОИСК ПО СТРАНЕ',
                      hintStyle: TextStyle(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_countrySearchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _countrySearchController.clear();
                      setState(() => _countrySearchQuery = '');
                    },
                    child: Icon(Symbols.close, color: cs.onSurfaceVariant, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFluxBubbleLogo({required double size}) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.5),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.78,
          height: size * 0.78,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                Colors.teal.withValues(alpha: 0.25),
                Colors.purple.withValues(alpha: 0.25),
                Colors.lightGreen.withValues(alpha: 0.25),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            'flux',
            style: TextStyle(
              fontSize: size * 0.28,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  String _countryFlag(String countryCode) {
    return countryCode.toUpperCase().runes.map((rune) {
      return String.fromCharCode(rune + 127397);
    }).join();
  }
}
