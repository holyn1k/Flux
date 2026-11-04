import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/config/app_fonts.dart';
import '../../../core/config/app_frost.dart';
import '../../../core/config/app_shape.dart';
import '../../../core/config/debug_test.dart';
import '../../../core/contacts/device_contacts_service.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/token_storage.dart';
import '../../../backend/modules/contacts.dart';
import '../../../backend/modules/messages.dart' show ContactCache;
import '../../../main.dart';
import '../../../models/contact_info.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/flux_avatar.dart';
import '../../widgets/sheet_helpers.dart';
import '../../widgets/small_spinner.dart';
import '../../widgets/springy_tap.dart';
import '../chats/chat_info_screen.dart';
import 'nfc_exchange_sheet.dart';
import 'open_contact_profile.dart';

enum _SearchMode { phone, id }

class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
  List<CachedContact> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    ContactsModule.revision.addListener(_loadContacts);
    _loadDeviceContacts();
  }

  Future<void> _loadDeviceContacts() async {
    final changed = await DeviceContactsService.ensureLoadedInteractive();
    if (changed && mounted) setState(() {});
  }

  @override
  void dispose() {
    ContactsModule.revision.removeListener(_loadContacts);
    super.dispose();
  }

  Future<void> _openNfcExchange() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: AppFrost.scrim(),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => const Align(
        alignment: Alignment.topCenter,
        child: NfcExchangeSheet(),
      ),
      transitionBuilder: (_, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  Future<void> _openSearchById() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _SearchContactSheet(),
    );
  }

  Future<void> _loadContacts() async {
    if (DebugTest.enabled) {
      final debug = ContactsModule.debugContacts()
        ..sort((a, b) => a.firstName.compareTo(b.firstName));
      if (mounted) {
        setState(() {
          _contacts = debug;
          _isLoading = false;
        });
      }
      return;
    }

    final p = await AppDatabase.loadActiveProfile();
    if (p == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final contacts = await ContactsModule.getContacts(p.id);
    contacts.sort((a, b) => a.firstName.compareTo(b.firstName));
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    }
  }

  Widget _buildContactItem(
    BuildContext context,
    CachedContact contact,
  ) {
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);
    const accentColor = Color(0xFF1E88E5);

    final fullName =
        '${contact.firstName}${contact.lastName != null ? ' ${contact.lastName}' : ''}'
            .trim();
    final book = DeviceContactsService.nameForPhone(contact.phone);
    final nameToDisplay =
        book ?? (fullName.isEmpty ? '+${contact.phone}' : fullName);

    return SpringyTap(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openContactDialogProfile(
            context,
            contactId: contact.id,
            name: nameToDisplay,
            avatarUrl: contact.baseUrl,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                FluxAvatar(
                  name: nameToDisplay,
                  imageUrl: contact.baseUrl,
                  size: 48,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              nameToDisplay,
                              style: const TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (contact.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Symbols.verified,
                              color: accentColor,
                              size: 16,
                              weight: 600,
                              fill: 1,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.updateTime > 0
                            ? 'Был(а) недавно'
                            : '+${contact.phone}',
                        style: const TextStyle(
                          color: subtitleColor,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);
    const borderColor = Color(0xFFE2E5EB);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Контакты',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            fontFamily: displayFontOf(context),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const ConnectionStatusLine(),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Symbols.nfc, color: textColor, size: 24),
                    onPressed: _openNfcExchange,
                  ),
                  IconButton(
                    icon: const Icon(Symbols.search, color: textColor, size: 24),
                    onPressed: _openSearchById,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: SmallSpinner(size: 36))
                  : _contacts.isEmpty
                  ? const Center(
                      child: Text(
                        'Нет контактов',
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: _contacts.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 84,
                        color: borderColor.withValues(alpha: 0.6),
                      ),
                      itemBuilder: (context, index) {
                        final contact = _contacts[index];
                        return _buildContactItem(context, contact);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchContactSheet extends StatefulWidget {
  const _SearchContactSheet();

  @override
  State<_SearchContactSheet> createState() => _SearchContactSheetState();
}

class _SearchContactSheetState extends State<_SearchContactSheet> {
  final _controller = TextEditingController();
  _SearchMode _mode = _SearchMode.phone;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setMode(_SearchMode mode) {
    if (_mode == mode || _loading) return;
    setState(() {
      _mode = mode;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_mode == _SearchMode.phone) {
      await _submitPhone();
    } else {
      await _submitId();
    }
  }

  String? _phoneCandidate(String query) {
    if (!RegExp(r'^[+\d\s\-()]+$').hasMatch(query)) return null;
    final digits = query.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 5) return null;
    return query;
  }

  Future<void> _submitPhone() async {
    final query = _phoneCandidate(_controller.text.trim());
    if (query == null) {
      setState(() => _error = 'Введите корректный номер телефона');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ContactsModule.findByPhone(api, query);
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _loading = false;
          _error = 'Контакт с таким номером не найден';
        });
        return;
      }
      final navigator = Navigator.of(context);
      final accountId = await TokenStorage.getActiveAccountId();
      final existing = accountId == null
          ? null
          : await AppDatabase.findDialogChatByParticipant(accountId, result.id);
      final chatId = existing ?? ((accountId ?? 0) ^ result.id);
      if (!mounted) return;
      navigator.pop();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatInfoScreen(
            chatId: chatId,
            name:
                ContactCache.get(result.id) ??
                result.name ??
                'User #${result.id}',
            imageUrl: result.avatarUrl ?? '',
            chatType: 'DIALOG',
            dialogPeerId: result.id,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Ошибка: $e';
        });
      }
    }
  }

  Future<void> _submitId() async {
    final raw = _controller.text.trim();
    final id = int.tryParse(raw);
    if (id == null) {
      setState(() => _error = 'Введите числовой ID');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final packet = await api.sendRequest(Opcode.contactInfo, {
        'contactIds': [id],
      });
      final contacts = (packet.payload as Map?)?['contacts'] as List?;
      if (contacts == null || contacts.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Контакт с таким ID не найден';
          });
        }
        return;
      }
      final rawMap = Map<String, dynamic>.from(contacts.first as Map);
      final info = ContactInfo.fromMap(rawMap);
      ContactsModule.primeContactCache(rawMap);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final accountId = await TokenStorage.getActiveAccountId();
      final existing = accountId == null
          ? null
          : await AppDatabase.findDialogChatByParticipant(accountId, id);
      final chatId = existing ?? ((accountId ?? 0) ^ id);
      if (!mounted) return;
      navigator.pop();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatInfoScreen(
            chatId: chatId,
            name: ContactCache.get(id) ?? info.displayName ?? 'User #$id',
            imageUrl: info.avatarUrl ?? '',
            chatType: 'DIALOG',
            dialogPeerId: id,
          ),
        ),
      );
    } on PacketError catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Ошибка: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);
    const primaryColor = Color(0xFF2C3E50);
    const accentColor = Color(0xFF1E88E5);
    const borderColor = Color(0xFFD6D9E0);
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: SheetGrabber(margin: EdgeInsets.only(bottom: 12)),
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Найти контакт',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Symbols.close, color: subtitleColor),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE4E7ED), width: 1),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _tabOption(
                        title: 'Номер',
                        icon: Symbols.call,
                        selected: _mode == _SearchMode.phone,
                        onTap: () => _setMode(_SearchMode.phone),
                      ),
                      _tabOption(
                        title: 'ID',
                        icon: Symbols.tag,
                        selected: _mode == _SearchMode.id,
                        onTap: () => _setMode(_SearchMode.id),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: _mode == _SearchMode.phone
                      ? TextInputType.phone
                      : TextInputType.number,
                  enabled: !_loading,
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: _mode == _SearchMode.phone
                        ? 'Введите номер телефона'
                        : 'Введите ID контакта',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(
                      _mode == _SearchMode.phone ? Symbols.call : Symbols.tag,
                      color: subtitleColor,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: borderColor, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: accentColor, width: 1.8),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFFCDD2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Symbols.error_outline,
                          size: 18,
                          color: Color(0xFFD32F2F),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      disabledBackgroundColor: const Color(0xFFE2E5EB),
                      shape: AppShape.buttonBorder,
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SmallSpinner(size: 20, color: Colors.white)
                        : const Text(
                            'Найти',
                            style: TextStyle(
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
    );
  }

  Widget _tabOption({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: _loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
