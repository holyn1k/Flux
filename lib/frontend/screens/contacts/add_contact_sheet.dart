import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:flux/backend/modules/contacts.dart';
import 'package:flux/core/config/countries.dart';
import 'package:flux/frontend/screens/auth/phone_input_formatter.dart';
import 'package:flux/frontend/screens/auth/select_country_screen.dart';
import 'package:flux/frontend/screens/contacts/contact_sheet_common.dart';
import 'package:flux/frontend/screens/contacts/open_contact_profile.dart';
import 'package:flux/frontend/widgets/custom_notification.dart';
import 'package:flux/l10n/app_localizations.dart';
import 'package:flux/main.dart';

Future<void> showAddContactSheet(BuildContext context) {
  return showBlurredCard<void>(
    context,
    (host) => _AddContactCard(hostContext: host),
  );
}

class _AddContactCard extends StatefulWidget {
  final BuildContext hostContext;

  const _AddContactCard({required this.hostContext});

  @override
  State<_AddContactCard> createState() => _AddContactCardState();
}

class _AddContactCardState extends State<_AddContactCard> {
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _firstCtrl = TextEditingController();
  final TextEditingController _lastCtrl = TextEditingController();

  late CountryName _country;
  bool _loading = false;
  String? _notFoundPhone;

  @override
  void initState() {
    super.initState();
    final allowed = api.registrationCountries;
    _country =
        countriesByCode['RU'] ??
        (allowed.isNotEmpty ? allowed.first : allCountries.first);
    if (allowed.isNotEmpty && !allowed.any((c) => c.code == _country.code)) {
      _country = allowed.first;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    super.dispose();
  }

  String get _digits => _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
  bool get _phoneValid => _digits.length == _country.phoneDigits;
  bool get _canSave =>
      _phoneValid && _firstCtrl.text.trim().isNotEmpty && !_loading;

  Future<void> _pickCountry() async {
    final picked = await Navigator.of(context).push<CountryName>(
      MaterialPageRoute(
        builder: (_) => SelectCountryScreen(
          selectedCountry: _country,
          countries: api.registrationCountries,
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _country = picked;
        _phoneCtrl.clear();
      });
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _loading = true);
    final phone = '${_country.phoneCode}$_digits';
    final result = await ContactsModule.addContactByPhone(
      api,
      phone: phone,
      firstName: _firstCtrl.text.trim(),
      lastName: _lastCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);

    switch (result.status) {
      case AddContactStatus.added:
        final contact = result.contact;
        Navigator.of(context).pop();
        if (contact == null) return;
        final name = (contact.lastName != null && contact.lastName!.isNotEmpty)
            ? '${contact.firstName} ${contact.lastName}'
            : contact.firstName;
        if (!widget.hostContext.mounted) return;
        await openContactDialogProfile(
          widget.hostContext,
          contactId: contact.id,
          name: name,
          avatarUrl: contact.baseUrl,
        );
      case AddContactStatus.notFound:
        setState(() => _notFoundPhone = phone);
      case AddContactStatus.error:
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.addContactError,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE2E5EB);
    final width = MediaQuery.sizeOf(context).width;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width > 420 ? 380 : double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _notFoundPhone != null
                  ? _buildNotFound()
                  : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final l10n = AppLocalizations.of(context)!;
    const textColor = Color(0xFF1A1A1A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.addContactTitle,
            style: const TextStyle(
              color: textColor,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 18),
          _buildPhoneRow(),
          _divider(),
          _buildTextRow(
            controller: _firstCtrl,
            hint: l10n.addContactFirstName,
          ),
          _divider(),
          _buildTextRow(
            controller: _lastCtrl,
            hint: l10n.addContactLastName,
          ),
          const SizedBox(height: 12),
          _buildSaveButton(l10n),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: const Color(0xFFE4E7ED).withValues(alpha: 0.8),
    );
  }

  Widget _buildPhoneRow() {
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          InkWell(
            onTap: _loading ? null : _pickCountry,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    contactFlagEmoji(_country.code),
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _country.phoneCode,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Symbols.keyboard_arrow_down,
                    size: 18,
                    color: subtitleColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: ValueKey(_country.code),
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                PhoneInputFormatter(_country),
              ],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: _country.phoneMask.replaceAll('#', '0'),
                hintStyle: const TextStyle(
                  color: Color(0xFFBDBDBD),
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextRow({
    required TextEditingController controller,
    required String hint,
  }) {
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: 60,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                counterText: '',
                hintText: hint,
                hintStyle: const TextStyle(
                  color: subtitleColor,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${controller.text.characters.length}/60',
            style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(AppLocalizations l10n) {
    const primaryColor = Color(0xFF2C3E50);

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: _canSave ? _save : null,
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          disabledBackgroundColor: const Color(0xFFE2E5EB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                l10n.addContactSave,
                style: TextStyle(
                  color: _canSave ? Colors.white : const Color(0xFF9E9E9E),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildNotFound() {
    final l10n = AppLocalizations.of(context)!;
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.addContactNotFound(_notFoundPhone ?? ''),
            style: const TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.addContactNotFoundSubtitle,
            style: const TextStyle(color: subtitleColor, fontSize: 14),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => setState(() => _notFoundPhone = null),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD6D9E0), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l10n.addContactSearchOther,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
