import 'package:flutter/material.dart';

import 'package:flux/backend/modules/contacts.dart';
import 'package:flux/frontend/screens/contacts/contact_sheet_common.dart';
import 'package:flux/frontend/widgets/custom_notification.dart';
import 'package:flux/frontend/widgets/flux_avatar.dart';
import 'package:flux/l10n/app_localizations.dart';
import 'package:flux/main.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/config/app_shape.dart';

enum EditContactAction { updated, removed }

class EditContactResult {
  final EditContactAction action;
  final String firstName;
  final String lastName;

  const EditContactResult(
    this.action, {
    this.firstName = '',
    this.lastName = '',
  });
}

Future<EditContactResult?> showEditContactSheet(
  BuildContext context, {
  required int contactId,
  required String avatarUrl,
  required String customFirst,
  required String customLast,
  required String onemeFirst,
  required String onemeLast,
}) {
  return showBlurredCard<EditContactResult>(
    context,
    (_) => _EditContactCard(
      contactId: contactId,
      avatarUrl: avatarUrl,
      customFirst: customFirst,
      customLast: customLast,
      onemeFirst: onemeFirst,
      onemeLast: onemeLast,
    ),
  );
}

class _EditContactCard extends StatefulWidget {
  final int contactId;
  final String avatarUrl;
  final String customFirst;
  final String customLast;
  final String onemeFirst;
  final String onemeLast;

  const _EditContactCard({
    required this.contactId,
    required this.avatarUrl,
    required this.customFirst,
    required this.customLast,
    required this.onemeFirst,
    required this.onemeLast,
  });

  @override
  State<_EditContactCard> createState() => _EditContactCardState();
}

class _EditContactCardState extends State<_EditContactCard> {
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;

  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _firstCtrl = TextEditingController(text: widget.customFirst);
    _lastCtrl = TextEditingController(text: widget.customLast);
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    super.dispose();
  }

  bool get _busy => _saving || _deleting;

  bool get _dirty =>
      _firstCtrl.text.trim() != widget.customFirst.trim() ||
      _lastCtrl.text.trim() != widget.customLast.trim();

  Future<void> _save() async {
    if (!_dirty || _busy) return;
    setState(() => _saving = true);

    final first = _firstCtrl.text.trim();
    final last = _lastCtrl.text.trim();
    final sendFirst = first.isEmpty ? widget.onemeFirst : first;
    final sendLast = last.isEmpty ? widget.onemeLast : last;

    final updated = await ContactsModule.updateContact(
      api,
      contactId: widget.contactId,
      firstName: sendFirst,
      lastName: sendLast,
    );
    if (!mounted) return;

    if (updated == null) {
      setState(() => _saving = false);
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.editContactError,
      );
      return;
    }

    Navigator.of(context).pop(
      EditContactResult(
        EditContactAction.updated,
        firstName: updated.firstName,
        lastName: updated.lastName ?? '',
      ),
    );
  }

  Future<void> _delete() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: AppShape.dialogBorder,
        title: Text(
          l10n.editContactDeleteConfirmTitle,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          l10n.editContactDeleteConfirmBody,
          style: const TextStyle(
            color: Color(0xFF757575),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l10n.editContactDeleteCancel,
              style: const TextStyle(
                color: Color(0xFF757575),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.editContactDelete,
              style: const TextStyle(
                color: Color(0xFFE53935),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final ok = await ContactsModule.removeContact(api, widget.contactId);
    if (!mounted) return;

    if (!ok) {
      setState(() => _deleting = false);
      showCustomNotification(context, l10n.editContactError);
      return;
    }

    Navigator.of(context).pop(
      const EditContactResult(EditContactAction.removed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final avatarName = widget.customFirst.isNotEmpty
        ? widget.customFirst
        : widget.onemeFirst;
    const borderColor = Color(0xFFE2E5EB);

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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: FluxAvatar(
                      name: avatarName,
                      size: 88,
                      imageUrl: widget.avatarUrl.isEmpty
                          ? null
                          : widget.avatarUrl,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _inputRow(
                    controller: _firstCtrl,
                    hint: l10n.editContactFirstName,
                  ),
                  _divider(),
                  _inputRow(
                    controller: _lastCtrl,
                    hint: l10n.editContactLastName,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: _dirty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _saveButton(l10n),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: 8),
                  _deleteButton(l10n),
                ],
              ),
            ),
          ),
        ),
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

  Widget _inputRow({
    required TextEditingController controller,
    required String hint,
  }) {
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);
    final hasText = controller.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: 60,
              enabled: !_busy,
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
          if (hasText)
            InkWell(
              onTap: _busy ? null : () => setState(() => controller.clear()),
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Symbols.close,
                  size: 18,
                  color: subtitleColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _saveButton(AppLocalizations l10n) {
    const primaryColor = Color(0xFF2C3E50);

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: _busy ? null : _save,
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          disabledBackgroundColor: const Color(0xFFE2E5EB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                l10n.editContactSave,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _deleteButton(AppLocalizations l10n) {
    const errorColor = Color(0xFFE53935);

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: TextButton(
        onPressed: _busy ? null : _delete,
        style: TextButton.styleFrom(
          foregroundColor: errorColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _deleting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: errorColor,
                ),
              )
            : Text(
                l10n.editContactDelete,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: errorColor,
                ),
              ),
      ),
    );
  }
}
