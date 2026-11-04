import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/calls/audio_devices.dart';
import '../../../core/calls/call_session.dart';
import '../../../core/calls/pulse_audio.dart';
import '../../../core/config/app_fonts.dart';
import '../../../core/config/call_no_mute.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/sheet_helpers.dart';

Future<void> showCallMicrophoneSheet(
  BuildContext context, {
  required CallSession session,
  required ColorScheme scheme,
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
      child: _MicrophoneSheet(session: session),
    ),
  );
}

class _MicOption {
  const _MicOption({
    required this.id,
    required this.label,
    this.detail,
    this.isMonitor = false,
    this.isDevice = false,
  });

  final String id;
  final String label;
  final String? detail;
  final bool isMonitor;
  final bool isDevice;
}

class _MicrophoneSheet extends StatefulWidget {
  final CallSession session;

  const _MicrophoneSheet({required this.session});

  @override
  State<_MicrophoneSheet> createState() => _MicrophoneSheetState();
}

class _MicrophoneSheetState extends State<_MicrophoneSheet> {
  List<_MicOption>? _options;
  bool _pulseMode = false;
  String? _selected;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pulse = PulseAudio.supported && await PulseAudio.isAvailable()
        ? await PulseAudio.sources()
        : const <PulseSource>[];
    final devices = await AudioDevices.microphones();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final routed = pulse.map((source) => source.name).toSet();
    setState(() {
      _pulseMode = pulse.isNotEmpty;
      _selected = widget.session.pulseSource ?? widget.session.micDeviceId;
      _options = [
        for (final source in pulse)
          _MicOption(
            id: source.name,
            label: source.label,
            detail: source.name,
            isMonitor: source.isMonitor,
          ),
        for (var i = 0; i < devices.length; i++)
          if (!routed.contains(devices[i].id))
            _MicOption(
              id: devices[i].id,
              label: devices[i].label.isNotEmpty
                  ? devices[i].label
                  : l10n.callMicrophoneFallback(i + 1),
              isDevice: true,
            ),
      ];
    });
  }

  Future<void> _select(String? id, {required bool viaDevice}) async {
    if (_switching || id == _selected) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _switching = true);
    try {
      if (_pulseMode && !viaDevice) {
        await widget.session.setPulseSource(id);
      } else {
        await widget.session.setMicrophone(id);
      }
      if (mounted) setState(() => _selected = id);
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, l10n.callMicrophoneFailed(e));
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);
    const primaryColor = Color(0xFF2C3E50);
    const accentColor = Color(0xFF1E88E5);
    const cardBorderColor = Color(0xFFE2E5EB);

    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final options = _options;
    final inputs = options?.where((o) => !o.isMonitor).toList() ?? const [];
    final monitors = options?.where((o) => o.isMonitor).toList() ?? const [];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Center(
                child: SheetGrabber(margin: EdgeInsets.only(bottom: 12)),
              ),
              _header(l10n, textColor, subtitleColor),
              if (CallNoMute.enabled) _noMuteHint(accentColor, l10n),
              if (options == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    children: [
                      _tile(
                        textColor: textColor,
                        accentColor: accentColor,
                        id: null,
                        label: l10n.callMicrophoneSystem,
                        icon: Symbols.settings_voice,
                        viaDevice: true,
                      ),
                      if (options.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Text(
                            l10n.callMicrophoneEmpty,
                            style: const TextStyle(
                              color: subtitleColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      for (final option in inputs) ...[
                        const SizedBox(height: 4),
                        _tile(
                          textColor: textColor,
                          accentColor: accentColor,
                          id: option.id,
                          label: option.label,
                          detail: option.detail,
                          icon: Symbols.mic,
                          viaDevice: option.isDevice,
                        ),
                      ],
                      if (monitors.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Divider(
                            color: cardBorderColor.withValues(alpha: 0.8),
                            height: 1,
                          ),
                        ),
                        _group(subtitleColor, l10n.callMicrophoneMonitors),
                        for (final option in monitors) ...[
                          const SizedBox(height: 4),
                          _tile(
                            textColor: textColor,
                            accentColor: accentColor,
                            id: option.id,
                            label: option.label,
                            detail: option.detail,
                            icon: Symbols.graphic_eq,
                            viaDevice: option.isDevice,
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
    AppLocalizations l10n,
    Color textColor,
    Color iconColor,
  ) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.callMicrophoneTitle,
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: displayFontOf(context),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() => _options = null);
                _load();
              },
              tooltip: l10n.callMicrophoneRefresh,
              icon: Icon(Symbols.refresh, color: iconColor),
            ),
          ],
        ),
      );

  Widget _noMuteHint(Color accentColor, AppLocalizations l10n) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F7FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Symbols.graphic_eq, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.callNoMuteHint,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _group(Color subtitleColor, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Text(
          title,
          style: TextStyle(
            color: subtitleColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      );

  Widget _tile({
    required Color textColor,
    required Color accentColor,
    required String? id,
    required String label,
    required IconData icon,
    String? detail,
    bool viaDevice = false,
  }) {
    final selected = _selected == id;
    return Container(
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF3F7FA) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? accentColor.withValues(alpha: 0.35)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(
          icon,
          color: selected ? accentColor : const Color(0xFF616161),
          size: 24,
        ),
        title: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? accentColor : textColor,
            fontSize: 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: detail == null
            ? null
            : Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF757575),
                  fontSize: 12,
                ),
              ),
        trailing: selected
            ? const Icon(Symbols.check, color: accentColor, size: 22)
            : null,
        enabled: !_switching,
        onTap: () => _select(id, viaDevice: viaDevice),
      ),
    );
  }
}
