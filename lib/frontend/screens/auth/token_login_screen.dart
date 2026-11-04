import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_shape.dart';
import '../../../core/storage/spoofing_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../models/spoof_profile.dart';
import '../../widgets/adaptive_shell.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/section_header.dart';
import '../../widgets/small_spinner.dart';

class TokenLoginScreen extends StatefulWidget {
  final int? returnToAccountId;

  const TokenLoginScreen({super.key, this.returnToAccountId});

  @override
  State<TokenLoginScreen> createState() => _TokenLoginScreenState();
}

class _TokenLoginScreenState extends State<TokenLoginScreen> {
  final _tokenController = TextEditingController();
  final _deviceNameController = TextEditingController();
  final _osVersionController = TextEditingController();
  final _screenController = TextEditingController();
  final _timezoneController = TextEditingController();
  final _localeController = TextEditingController();
  final _deviceLocaleController = TextEditingController();
  final _deviceIdController = TextEditingController();
  final _appVersionController = TextEditingController(
    text: SpoofingService.hardcodedAppVersion,
  );
  final _buildNumberController = TextEditingController(
    text: '${SpoofingService.hardcodedBuildNumber}',
  );
  final _pushDeviceTypeController = TextEditingController(text: 'GCM');
  final _instanceIdController = TextEditingController();
  final _clientSessionIdController = TextEditingController();
  final _userAgentController = TextEditingController();

  String _selectedDeviceType = 'ANDROID';
  String _selectedArch = 'arm64-v8a';
  bool _isLoading = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _deviceNameController.dispose();
    _osVersionController.dispose();
    _screenController.dispose();
    _timezoneController.dispose();
    _localeController.dispose();
    _deviceLocaleController.dispose();
    _deviceIdController.dispose();
    _appVersionController.dispose();
    _buildNumberController.dispose();
    _pushDeviceTypeController.dispose();
    _instanceIdController.dispose();
    _clientSessionIdController.dispose();
    _userAgentController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _tokenController.text.trim().isNotEmpty &&
      _deviceNameController.text.trim().isNotEmpty &&
      _osVersionController.text.trim().isNotEmpty &&
      _deviceIdController.text.trim().isNotEmpty;

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_isValid) {
      showCustomNotification(context, l10n.tokenLoginError);
      return;
    }

    setState(() => _isLoading = true);

    final profile = SpoofProfile(
      enabled: true,
      deviceName: _deviceNameController.text.trim(),
      osVersion: _osVersionController.text.trim(),
      screen: _screenController.text.trim(),
      timezone: _timezoneController.text.trim(),
      locale: _localeController.text.trim(),
      deviceLocale: _deviceLocaleController.text.trim(),
      deviceId: _deviceIdController.text.trim(),
      deviceType: _selectedDeviceType,
      arch: _selectedArch,
      appVersion: _appVersionController.text.trim(),
      buildNumber:
          int.tryParse(_buildNumberController.text.trim()) ??
          SpoofingService.hardcodedBuildNumber,
      pushDeviceType: _pushDeviceTypeController.text.trim(),
      instanceId: _instanceIdController.text.trim(),
      clientSessionId: int.tryParse(_clientSessionIdController.text.trim()),
      userAgent: _userAgentController.text.trim(),
    );

    try {
      await SpoofingService.saveProfile(SpoofingService.pendingScope, profile);
      await accountModule.loginWithToken(_tokenController.text.trim());
      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdaptiveShell()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showCustomNotification(context, '${l10n.tokenLoginFailed}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF1A1A1A);
    const primaryColor = Color(0xFF2C3E50);

    final l10n = AppLocalizations.of(context)!;

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
      body: AbsorbPointer(
        absorbing: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.tokenLoginTitle,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 16),
              _buildNoteCard(l10n),
              const SizedBox(height: 16),
              _buildTokenCard(l10n),
              const SizedBox(height: 16),
              _buildDeviceCard(l10n),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: FilledButton(
          onPressed: _isLoading ? null : _login,
          style: FilledButton.styleFrom(
            backgroundColor: primaryColor,
            disabledBackgroundColor: const Color(0xFFE2E5EB),
            minimumSize: const Size.fromHeight(52),
            shape: AppShape.buttonBorder,
            elevation: 0,
          ),
          child: _isLoading
              ? const SmallSpinner(size: 22, color: Colors.white)
              : Text(
                  l10n.tokenLoginButton,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildNoteCard(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE082), width: 1.2),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Symbols.warning, size: 20, color: Color(0xFFF57F17)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.tokenLoginNote,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF5D4037),
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenCard(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E5EB), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _tokenController,
        minLines: 1,
        maxLines: 3,
        style: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        onChanged: (_) => setState(() {}),
        decoration: _decoration(l10n.tokenLoginTokenLabel, Symbols.key),
      ),
    );
  }

  Widget _buildDeviceCard(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E5EB), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            l10n.spoofMainSectionTitle,
            padding: const EdgeInsets.only(bottom: 16, top: 2),
            fontSize: 18,
          ),
          Text(
            l10n.spoofDeviceTypeTitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF424242),
            ),
          ),
          const SizedBox(height: 8),
          _chips(
            const [
              _Opt('ANDROID', 'Android', Symbols.android),
              _Opt('IOS', 'iOS', Symbols.phone_iphone),
            ],
            _selectedDeviceType,
            (v) => setState(() => _selectedDeviceType = v),
          ),
          const SizedBox(height: 16),
          _field(
            _deviceNameController,
            l10n.spoofFieldDeviceName,
            Symbols.smartphone,
          ),
          const SizedBox(height: 14),
          _field(
            _osVersionController,
            l10n.spoofFieldOsVersion,
            Symbols.layers,
          ),
          const SizedBox(height: 14),
          _field(
            _screenController,
            l10n.spoofFieldScreen,
            Symbols.fullscreen,
          ),
          const SizedBox(height: 14),
          _field(
            _timezoneController,
            l10n.spoofFieldTimezone,
            Symbols.public,
          ),
          const SizedBox(height: 14),
          _field(_localeController, l10n.spoofFieldLocale, Symbols.language),
          const SizedBox(height: 14),
          _field(
            _deviceLocaleController,
            l10n.spoofFieldDeviceLocale,
            Symbols.translate,
          ),
          const SizedBox(height: 24),
          SectionHeader(
            l10n.spoofIdentifiersSectionTitle,
            padding: const EdgeInsets.only(bottom: 16, top: 4),
            fontSize: 18,
          ),
          _field(
            _deviceIdController,
            l10n.spoofFieldDeviceId,
            Symbols.tag,
            onChanged: true,
          ),
          const SizedBox(height: 14),
          _field(
            _instanceIdController,
            l10n.spoofFieldInstanceId,
            Symbols.fingerprint,
          ),
          const SizedBox(height: 14),
          _field(
            _clientSessionIdController,
            l10n.spoofFieldClientSessionId,
            Symbols.vpn_key,
            number: true,
          ),
          const SizedBox(height: 14),
          _field(
            _appVersionController,
            l10n.spoofFieldAppVersion,
            Symbols.info,
          ),
          const SizedBox(height: 14),
          _field(
            _buildNumberController,
            l10n.spoofFieldBuildNumber,
            Symbols.numbers,
            number: true,
          ),
          const SizedBox(height: 14),
          _field(
            _pushDeviceTypeController,
            l10n.spoofFieldPushDeviceType,
            Symbols.notifications,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.spoofFieldArchitecture,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF424242),
            ),
          ),
          const SizedBox(height: 8),
          _chips(
            const [
              _Opt('arm64-v8a', 'arm64-v8a', Symbols.memory),
              _Opt('armeabi-v7a', 'armeabi-v7a', Symbols.memory),
              _Opt('arm64', 'arm64', Symbols.memory),
              _Opt('x86_64', 'x86_64', Symbols.memory),
              _Opt('x86', 'x86', Symbols.memory),
            ],
            _selectedArch,
            (v) => setState(() => _selectedArch = v),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool number = false,
    bool onChanged = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : null,
      onChanged: onChanged ? (_) => setState(() {}) : null,
      style: const TextStyle(
        color: Color(0xFF1A1A1A),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: _decoration(label, icon),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF757575), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF616161), size: 20),
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD6D9E0), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 1.8),
      ),
    );
  }

  Widget _chips(
    List<_Opt> options,
    String selected,
    ValueChanged<String> onSelected,
  ) {
    const accentColor = Color(0xFF1E88E5);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt.value == selected;
        return ChoiceChip(
          label: Text(
            opt.label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF424242),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          avatar: Icon(
            isSelected ? Symbols.check : opt.icon,
            size: 18,
            color: isSelected ? Colors.white : const Color(0xFF757575),
          ),
          selected: isSelected,
          showCheckmark: false,
          onSelected: (_) => onSelected(opt.value),
          backgroundColor: const Color(0xFFF3F4F7),
          selectedColor: const Color(0xFF2C3E50),
          side: BorderSide(
            color: isSelected ? Colors.transparent : const Color(0xFFD6D9E0),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }).toList(),
    );
  }
}

class _Opt {
  final String value;
  final String label;
  final IconData icon;

  const _Opt(this.value, this.label, this.icon);
}
