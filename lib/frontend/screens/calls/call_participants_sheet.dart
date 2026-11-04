import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/calls/call_admin.dart';
import '../../../core/calls/call_session.dart';
import '../../../core/config/app_fonts.dart';
import '../../widgets/animated_slash_icon.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/flux_avatar.dart';
import '../../widgets/prompt_dialog.dart';
import '../../widgets/sheet_helpers.dart';

class CallParticipantView {
  final String name;
  final String? avatarUrl;

  const CallParticipantView({required this.name, this.avatarUrl});
}

typedef CallParticipantResolver =
    CallParticipantView Function(CallParticipant participant);

Future<void> showCallParticipantsSheet(
  BuildContext context, {
  required CallSession session,
  required ColorScheme scheme,
  required CallParticipantResolver resolve,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => Theme(
      data: Theme.of(context).copyWith(colorScheme: scheme),
      child: _ParticipantsSheet(session: session, resolve: resolve),
    ),
  );
}

class _ParticipantsSheet extends StatefulWidget {
  final CallSession session;
  final CallParticipantResolver resolve;

  const _ParticipantsSheet({required this.session, required this.resolve});

  @override
  State<_ParticipantsSheet> createState() => _ParticipantsSheetState();
}

class _ParticipantsSheetState extends State<_ParticipantsSheet> {
  final Map<CallOption, bool> _options = {};
  final Map<CallFeature, Set<CallRoleName>> _features = {};
  bool _recording = false;
  StreamSubscription<void>? _infoSub;

  @override
  void initState() {
    super.initState();
    _infoSub = widget.session.infoUpdates.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _infoSub?.cancel();
    super.dispose();
  }

  CallParticipant? get _self {
    for (final p in widget.session.participants) {
      if (p.isSelf) return p;
    }
    return null;
  }

  Future<bool> _run(Future<void> Function(CallAdmin admin) action) async {
    final admin = widget.session.admin;
    if (admin == null) {
      showCustomNotification(context, 'Нет связи с сервером звонка');
      return false;
    }
    try {
      await action(admin);
      return true;
    } catch (e) {
      if (mounted) showCustomNotification(context, 'Не удалось: $e');
      return false;
    }
  }

  CallParticipantRef _ref(CallParticipant p) => CallParticipantRef(p.id);

  void _participantActions(CallParticipant p) {
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);
    final view = widget.resolve(p);
    final isAdmin = p.isAdmin;
    final isSpeaker = p.isSpeaker;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Center(
                child: SheetGrabber(margin: EdgeInsets.only(bottom: 12)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  view.name,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: displayFontOf(context),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  p.roles.isEmpty ? 'Участник' : p.roles.join(' · '),
                  style: const TextStyle(color: subtitleColor, fontSize: 13),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE4E7ED)),
              const SizedBox(height: 6),
              _action(Symbols.mic_off, 'Выключить микрофон', () {
                Navigator.pop(sheetContext);
                _run((a) => a.muteMicrophone(_ref(p)));
              }),
              _action(Symbols.videocam_off, 'Запросить камеру', () {
                Navigator.pop(sheetContext);
                _run(
                  (a) =>
                      a.requestMedia({CallMedia.video}, participant: _ref(p)),
                );
              }),
              _action(
                isAdmin ? Symbols.remove_moderator : Symbols.shield_person,
                isAdmin ? 'Снять администратора' : 'Назначить администратором',
                () {
                  Navigator.pop(sheetContext);
                  _run(
                    (a) => a.setRoles(_ref(p), [
                      CallRoleName.admin,
                    ], revoke: isAdmin),
                  );
                },
              ),
              _action(
                isSpeaker ? Symbols.voice_over_off : Symbols.record_voice_over,
                isSpeaker ? 'Убрать из спикеров' : 'Сделать спикером',
                () {
                  Navigator.pop(sheetContext);
                  _run(
                    (a) => a.setRoles(_ref(p), [
                      CallRoleName.speaker,
                    ], revoke: isSpeaker),
                  );
                },
              ),
              _action(Symbols.arrow_upward, 'Повысить (promote)', () {
                Navigator.pop(sheetContext);
                _run((a) => a.setPromoted(_ref(p), true));
              }),
              _action(Symbols.arrow_downward, 'Понизить (demote)', () {
                Navigator.pop(sheetContext);
                _run((a) => a.setPromoted(_ref(p), false));
              }),
              _action(Symbols.push_pin, 'Закрепить', () {
                Navigator.pop(sheetContext);
                _run((a) => a.setPinned(_ref(p), true));
              }),
              _action(Symbols.keep_off, 'Открепить', () {
                Navigator.pop(sheetContext);
                _run((a) => a.setPinned(_ref(p), false));
              }),
              _action(Symbols.person_remove, 'Удалить из звонка', () {
                Navigator.pop(sheetContext);
                _run((a) => a.removeParticipant(_ref(p)));
              }, destructive: true),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions() {
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);
    const primaryColor = Color(0xFF2C3E50);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (_, setSheet) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Center(
                  child: SheetGrabber(margin: EdgeInsets.only(bottom: 12)),
                ),
                _sheetTitle('Настройки звонка'),
                for (final option in CallOption.values)
                  SwitchListTile(
                    activeTrackColor: primaryColor,
                    activeThumbColor: Colors.white,
                    value: _options[option] ?? false,
                    title: Text(
                      _optionLabel(option),
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      option.wire,
                      style: const TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                      ),
                    ),
                    onChanged: (value) async {
                      setSheet(() => _options[option] = value);
                      final ok = await _run(
                        (a) => a.setOptions({option: value}),
                      );
                      if (!ok) setSheet(() => _options[option] = !value);
                    },
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFeatures() {
    const textColor = Color(0xFF1A1A1A);
    const borderColor = Color(0xFFD6D9E0);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (_, setSheet) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Center(
                  child: SheetGrabber(margin: EdgeInsets.only(bottom: 12)),
                ),
                _sheetTitle('Кому доступны функции'),
                for (final feature in CallFeature.values)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _featureLabel(feature),
                          style: const TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final role in CallRoleName.values) ...[
                              Builder(
                                builder: (_) {
                                  final isSelected =
                                      _features[feature]?.contains(role) ?? false;
                                  return FilterChip(
                                    label: Text(role.wire),
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : textColor,
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                    selected: isSelected,
                                    showCheckmark: false,
                                    backgroundColor: const Color(0xFFF3F4F7),
                                    selectedColor: const Color(0xFF2C3E50),
                                    side: BorderSide(
                                      color: isSelected
                                          ? Colors.transparent
                                          : borderColor,
                                      width: 1.1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    onSelected: (selected) {
                                      final set = _features.putIfAbsent(
                                        feature,
                                        () => <CallRoleName>{},
                                      );
                                      setSheet(() {
                                        selected
                                            ? set.add(role)
                                            : set.remove(role);
                                      });
                                      _run(
                                        (a) => a.enableFeatureForRoles(
                                          feature,
                                          set.toList(),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addByLink() async {
    final link = await showTextInputDialog(
      context,
      title: 'Добавить участника',
      description: 'Ссылка-приглашение участника',
      confirmLabel: 'Добавить',
    );
    if (link == null || link.trim().isEmpty || !mounted) return;
    await _run((a) => a.addParticipantByLink(link.trim()));
  }

  String _optionLabel(CallOption option) => switch (option) {
    CallOption.requireAuthToJoin => 'Только авторизованные',
    CallOption.waitingHall => 'Зал ожидания',
    CallOption.recurring => 'Повторяющийся звонок',
    CallOption.feedback => 'Сбор отзывов',
    CallOption.audienceMode => 'Режим зрителей',
    CallOption.asr => 'Расшифровка речи',
    CallOption.waitForAdmin => 'Ждать администратора',
    CallOption.adminIsHere => 'Администратор на месте',
  };

  String _featureLabel(CallFeature feature) => switch (feature) {
    CallFeature.addParticipant => 'Добавлять участников',
    CallFeature.admin => 'Права администратора',
    CallFeature.asr => 'Расшифровка речи',
    CallFeature.movieShare => 'Совместный просмотр',
    CallFeature.record => 'Запись звонка',
    CallFeature.speaker => 'Быть спикером',
  };

  Widget _sheetTitle(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: Text(
      text,
      style: TextStyle(
        color: const Color(0xFF1A1A1A),
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: displayFontOf(context),
        letterSpacing: -0.2,
      ),
    ),
  );

  Widget _action(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool destructive = false,
  }) {
    final color = destructive ? const Color(0xFFE53935) : const Color(0xFF1A1A1A);
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final participants = widget.session.participants;
    final self = _self;
    final handRaised = self?.handRaised ?? false;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const Center(
            child: SheetGrabber(margin: EdgeInsets.only(bottom: 12)),
          ),
          _sheetTitle('Участники · ${participants.length}'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(Symbols.mic_off, 'Заглушить всех', () {
                  _run((a) => a.muteEveryone());
                }),
                _chip(Symbols.do_not_touch, 'Опустить руки', () {
                  _run((a) => a.lowerAllHands());
                }),
                _chip(
                  handRaised ? Symbols.back_hand : Symbols.front_hand,
                  handRaised ? 'Опустить руку' : 'Поднять руку',
                  () => _run((a) => a.setHandRaised(!handRaised)),
                  active: handRaised,
                ),
                _chip(
                  _recording
                      ? Symbols.stop_circle
                      : Symbols.radio_button_checked,
                  _recording ? 'Остановить запись' : 'Начать запись',
                  () async {
                    final next = !_recording;
                    setState(() => _recording = next);
                    final ok = await _run(
                      (a) => next
                          ? a.startRecord(name: 'Запись звонка')
                          : a.stopRecord(),
                    );
                    if (!ok && mounted) setState(() => _recording = !next);
                  },
                  active: _recording,
                ),
                _chip(Symbols.tune, 'Настройки', _showOptions),
                _chip(Symbols.shield_person, 'Права ролей', _showFeatures),
                _chip(Symbols.person_add, 'Добавить по ссылке', _addByLink),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: participants.length,
              separatorBuilder: (_, __) => Divider(
                color: const Color(0xFFE4E7ED).withValues(alpha: 0.6),
                height: 1,
              ),
              itemBuilder: (_, i) => _tile(participants[i]),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _chip(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool active = false,
  }) {
    const primaryColor = Color(0xFF2C3E50);
    const borderColor = Color(0xFFD6D9E0);

    return ActionChip(
      avatar: Icon(
        icon,
        size: 18,
        color: active ? Colors.white : const Color(0xFF616161),
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: active ? Colors.white : const Color(0xFF1A1A1A),
        fontSize: 13,
        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
      ),
      backgroundColor: active ? primaryColor : const Color(0xFFF3F4F7),
      side: BorderSide(
        color: active ? Colors.transparent : borderColor,
        width: 1.1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onPressed: onTap,
    );
  }

  Widget _tile(CallParticipant p) {
    const textColor = Color(0xFF1A1A1A);
    const accentColor = Color(0xFF1E88E5);
    const subtitleColor = Color(0xFF757575);

    final view = widget.resolve(p);
    final subtitle = <String>[
      if (p.isCreator) 'Создатель' else if (p.isAdmin) 'Администратор',
      if (p.isSpeaker) 'Спикер',
      if (p.handRaised) 'Поднял руку',
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: FluxAvatar(name: view.name, imageUrl: view.avatarUrl, size: 40),
      title: Text(
        view.name,
        style: const TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle.join(' · '),
              style: const TextStyle(
                color: accentColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.screenSharing)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Symbols.screen_share, size: 18, color: accentColor),
            ),
          if (p.videoEnabled)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Symbols.videocam, size: 18, color: subtitleColor),
            ),
          AnimatedSlashIcon(
            icon: Symbols.mic,
            slashedIcon: Symbols.mic_off,
            slashed: !p.audioEnabled,
            size: 18,
            color: p.audioEnabled ? subtitleColor : const Color(0xFFE53935),
          ),
        ],
      ),
      onTap: p.isSelf ? null : () => _participantActions(p),
    );
  }
}
