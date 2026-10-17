import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:komet/l10n/app_localizations.dart';
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
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final firstName = _firstNameController.text.trim();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: cs.onSurfaceVariant),
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
          children: [
            Text(
              l10n.registrationTitle,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.registrationSubtitle,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.outlineVariant,
                    width: 1,
                  ),
                ),
                child: ClipOval(
                  child: _selectedAvatarUrl != null
                      ? CachedNetworkImage(
                          imageUrl: _selectedAvatarUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: cs.surfaceContainerHigh,
                          alignment: Alignment.center,
                          child: Icon(
                            Symbols.person,
                            size: 48,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildInputField(
              label: l10n.editProfileFirstName,
              content: TextField(
                controller: _firstNameController,
                enabled: !_isSubmitting,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: cs.onSurface, fontSize: 14),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildInputField(
              label: l10n.editProfileLastName,
              content: TextField(
                controller: _lastNameController,
                enabled: !_isSubmitting,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: cs.onSurface, fontSize: 14),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (widget.presetAvatars.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(
                l10n.registrationChooseAvatar,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              for (final category in widget.presetAvatars)
                _buildAvatarCategory(cs, category),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSubmit ? _submit : null,
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
                child: _isSubmitting
                    ? SmallSpinner(size: 20, color: cs.surface)
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
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({required String label, required Widget content}) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerLeft,
          child: content,
        ),
        Positioned(
          top: -8,
          left: 12,
          child: Container(
            color: cs.surface,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarCategory(ColorScheme cs, PresetAvatarCategory category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (category.name.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              category.name,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w400,
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
                      color: selected ? cs.primary : cs.outlineVariant,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatar.url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: cs.surfaceContainerHigh),
                        errorWidget: (_, __, ___) =>
                            Container(color: cs.surfaceContainerHigh),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
