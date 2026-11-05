import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/connection_status.dart';

import '../../../core/config/flux_settings.dart';
import '../../../main.dart';
import '../../widgets/section_header.dart';
import '../../widgets/settings_card.dart';

class FluxSettingsScreen extends StatelessWidget {
  const FluxSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: 'Flux',
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            const SectionHeader(
              'Сообщения',
              padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
              fontSize: 14,
            ),
            SettingsCard(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: FluxSettings.viewDeleted,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.delete_history,
                    label: 'View deleted message',
                    subtitle: 'Показывать удалённые сообщения',
                    value: value,
                    onChanged: FluxSettings.setViewDeleted,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: FluxSettings.viewRedacted,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.history_edu,
                    label: 'View redacted message history',
                    subtitle: 'Показывать историю у редактированных сообщений',
                    value: value,
                    onChanged: FluxSettings.setViewRedacted,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: FluxSettings.fullTimestamp,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.schedule,
                    label: 'View full timestamp',
                    subtitle: 'Показывать время в секундах у сообщений',
                    value: value,
                    onChanged: FluxSettings.setFullTimestamp,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionHeader(
              'Папки',
              padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
              fontSize: 14,
            ),
            SettingsCard(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: FluxSettings.hideAllChatsFolder,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.folder_off,
                    label: 'Hide "All" folder',
                    subtitle:
                        'Скрыть папку «Все», когда есть другие папки. '
                        'Чаты сортируются только по вашим папкам',
                    value: value,
                    onChanged: FluxSettings.setHideAllChatsFolder,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: FluxSettings.showHiddenChats,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.visibility_lock,
                    label: 'Show hidden chats',
                    subtitle:
                        'Показывать скрытые чаты (например, от групповых '
                        'звонков), которые обычно не отображаются в списке',
                    value: value,
                    onChanged: FluxSettings.setShowHiddenChats,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionHeader(
              'Ghost Mode',
              padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
              fontSize: 14,
            ),
            SettingsCard(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: FluxSettings.ghostMode,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.visibility_off,
                    label: 'Ghost Mode',
                    subtitle: 'Вас не видно в сети',
                    value: value,
                    onChanged: _setGhostMode,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: FluxSettings.antiRead,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.mark_chat_read,
                    label: 'Anti read',
                    subtitle: 'Нечиталка сообщений',
                    value: value,
                    onChanged: FluxSettings.setAntiRead,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: FluxSettings.selfOnlineCheck,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.radar,
                    label: 'Self Online Check',
                    subtitle:
                        'Каждые ~10 секунд сверяет, когда вы были онлайн. '
                        'Полезно для проверки ghost mode',
                    value: value,
                    onChanged: FluxSettings.setSelfOnlineCheck,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setGhostMode(bool value) async {
    await FluxSettings.setGhostMode(value);
    api.sendPing(interactive: !value);
  }
}
