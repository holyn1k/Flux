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
                              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
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
                                '${l10n.registrationTitle.toUpperCase()} :',
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
                                l10n.registrationSubtitle,
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
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black12,
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
                                      color: Colors.grey.shade100,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Symbols.person,
                                        size: 40,
                                        color: Colors.black54,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                              child: Text(
                                l10n.editProfileFirstName.toUpperCase(),
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
                                controller: _firstNameController,
                                enabled: !_isSubmitting,
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => setState(() {}),
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12.0),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                              child: Text(
                                l10n.editProfileLastName.toUpperCase(),
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
                                controller: _lastNameController,
                                enabled: !_isSubmitting,
                                textInputAction: TextInputAction.done,
                                onChanged: (_) => setState(() {}),
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12.0),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (widget.presetAvatars.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          Text(
                            l10n.registrationChooseAvatar.toUpperCase(),
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          for (final category in widget.presetAvatars)
                            _buildAvatarCategory(cs, category),
                        ],
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24.0, top: 32.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _canSubmit ? _submit : null,
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
                              child: _isSubmitting
                                  ? SmallSpinner(size: 20, color: Colors.white)
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
                color: Colors.black54,
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
                      color: selected ? Colors.black : Colors.black12,
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
                            Container(color: Colors.grey.shade100),
                        errorWidget: (_, __, ___) =>
                            Container(color: Colors.grey.shade100),
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
