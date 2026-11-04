import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flux/l10n/app_localizations.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/account.dart';
import '../../../main.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/login_success_screen.dart';
import '../../widgets/small_spinner.dart';

class RegistrationScreen extends StatefulWidget {
  final String phoneNumber;
  final String registerToken;
  final List<PresetAvatarCategory> presetAvatars;

  const RegistrationScreen({
    super.key,
    required this.phoneNumber,
    required this.registerToken,
    required this.presetAvatars,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  int? _selectedPhotoId;
  String? _selectedAvatarUrl;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_isSubmitting && _firstNameController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    final firstName = _firstNameController.text.trim();
    if (firstName.isEmpty) return;
    final lastName = _lastNameController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      final accountId = await accountModule.completeRegistration(
        token: widget.registerToken,
        firstName: firstName,
        lastName: lastName.isEmpty ? null : lastName,
        photoId: _selectedPhotoId,
      );

      final loginResult = await accountModule.login(
        accountId: accountId,
        token: '',
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
          pageBuilder: (_, __, ___) => LoginSuccessScreen(avatar: avatar),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showCustomNotification(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);
    const primaryColor = Color(0xFF2C3E50);
    const accentColor = Color(0xFF1E88E5);

    final l10n = AppLocalizations.of(context)!;
    final firstName = _firstNameController.text.trim();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back, color: textColor),
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _canSubmit ? _submit : null,
        backgroundColor: _canSubmit ? primaryColor : const Color(0xFFE2E5EB),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        child: _isSubmitting
            ? const SmallSpinner(size: 22, color: Colors.white)
            : Icon(
                Symbols.arrow_forward,
                color: _canSubmit ? Colors.white : const Color(0xFF9E9E9E),
              ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
          children: [
            Text(
              l10n.registrationTitle,
              style: const TextStyle(
                color: textColor,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.registrationSubtitle,
              style: const TextStyle(
                color: subtitleColor,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.6),
                    width: 3.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: ClipOval(
                    child: _selectedAvatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _selectedAvatarUrl!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: const Color(0xFFF0F4F8),
                            alignment: Alignment.center,
                            child: Text(
                              firstName.isNotEmpty
                                  ? firstName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: primaryColor,
                                fontSize: 38,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField(
              label: l10n.editProfileFirstName,
              controller: _firstNameController,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: l10n.editProfileLastName,
              controller: _lastNameController,
              textInputAction: TextInputAction.done,
            ),
            if (widget.presetAvatars.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(
                l10n.registrationChooseAvatar,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              for (final category in widget.presetAvatars)
                _buildAvatarCategory(category),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required TextInputAction textInputAction,
  }) {
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);
    const accentColor = Color(0xFF1E88E5);
    const inputBgColor = Color(0xFFF7F8FA);
    const inputBorderColor = Color(0xFFD6D9E0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: subtitleColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TextField(
          controller: controller,
          enabled: !_isSubmitting,
          textInputAction: textInputAction,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: inputBgColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: inputBorderColor,
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: accentColor,
                width: 1.8,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: inputBorderColor,
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarCategory(PresetAvatarCategory category) {
    const subtitleColor = Color(0xFF757575);
    const accentColor = Color(0xFF1E88E5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        if (category.name.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              category.name,
              style: const TextStyle(
                color: subtitleColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: category.avatars.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final avatar = category.avatars[index];
              final selected = _selectedPhotoId == avatar.id;
              return GestureDetector(
                onTap: _isSubmitting
                    ? null
                    : () => setState(() {
                          _selectedPhotoId = avatar.id;
                          _selectedAvatarUrl = avatar.url;
                        }),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? accentColor : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatar.url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: const Color(0xFFF0F4F8)),
                        errorWidget: (_, __, ___) =>
                            Container(color: const Color(0xFFF0F4F8)),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
