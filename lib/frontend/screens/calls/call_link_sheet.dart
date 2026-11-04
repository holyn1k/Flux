import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:flux/backend/modules/calls.dart';
import 'package:flux/frontend/screens/chats/chat_list_screen.dart';
import 'package:flux/frontend/screens/contacts/contact_sheet_common.dart';
import 'package:flux/frontend/widgets/custom_notification.dart';
import 'package:flux/frontend/widgets/small_spinner.dart';
import 'package:flux/l10n/app_localizations.dart';
import 'package:flux/main.dart' show messagesModule;
import '../../../core/config/app_shape.dart';

Future<bool> showCreatedCallSheet(
  BuildContext context, {
  required CreatedCall call,
}) async {
  final started = await showBlurredCard<bool>(
    context,
    (host) => _CreatedCallCard(call: call, hostContext: host),
  );
  return started ?? false;
}

class _CreatedCallCard extends StatefulWidget {
  final CreatedCall call;
  final BuildContext hostContext;

  const _CreatedCallCard({required this.call, required this.hostContext});

  @override
  State<_CreatedCallCard> createState() => _CreatedCallCardState();
}

class _CreatedCallCardState extends State<_CreatedCallCard> {
  bool _sending = false;

  Future<void> _copy() async {
    final message = AppLocalizations.of(context)!.sharedLinkCopied;
    await Clipboard.setData(ClipboardData(text: widget.call.url));
    if (!mounted) return;
    showCustomNotification(context, message);
  }

  Future<void> _sendInFlux() async {
    if (_sending) return;
    final target = await openForwardScreen(context: context);
    if (target == null || !mounted) return;

    setState(() => _sending = true);
    final ok = await messagesModule.sendLinkMessage(
      target.chatId,
      widget.call.url,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    final l10n = AppLocalizations.of(context)!;
    showCustomNotification(
      context,
      ok ? l10n.callLinkSent : l10n.callLinkSendFailed,
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool busy = false,
  }) {
    const textColor = Color(0xFF1A1A1A);
    const accentColor = Color(0xFF1E88E5);

    return InkWell(
      onTap: busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: busy
                  ? const SmallSpinner(size: 22, color: accentColor)
                  : Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF1A1A1A);
    const primaryColor = Color(0xFF2C3E50);
    const accentColor = Color(0xFF1E88E5);
    const cardBorderColor = Color(0xFFE2E5EB);
    const actionBgColor = Color(0xFFF7F8FA);

    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final title = widget.call.callName ?? l10n.callLinkGroupCall;

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
              border: Border.all(color: cardBorderColor, width: 1.2),
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
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF2C3E50),
                          Color(0xFF4A6572),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2C3E50).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Symbols.call,
                      fill: 1,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.call.url,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: actionBgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorderColor, width: 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _action(
                          icon: Symbols.content_copy,
                          label: l10n.sharedCopyLink,
                          onTap: _copy,
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: cardBorderColor.withValues(alpha: 0.8),
                        ),
                        _action(
                          icon: Symbols.reply,
                          label: l10n.callLinkSendInMax,
                          onTap: _sendInFlux,
                          busy: _sending,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: AppShape.buttonBorder,
                        elevation: 0,
                      ),
                      child: Text(
                        l10n.callLinkStart,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
