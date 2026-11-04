import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:flux/core/calls/audio_devices.dart';
import 'package:flux/core/calls/call_session.dart';
import 'package:flux/core/calls/pulse_audio.dart';
import 'package:flux/core/config/app_fonts.dart';
import 'package:flux/core/config/call_no_mute.dart';
import 'package:flux/frontend/widgets/custom_notification.dart';
import 'package:flux/frontend/widgets/sheet_helpers.dart';
import 'package:flux/l10n/app_localizations.dart';

Future<void> showCallMicrophoneSheet(
  BuildContext context, {
  required CallSession session,
  required ColorScheme scheme,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
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
    const accentColor = Color(0xFF1E88E5);
    const borderColor = Color(0xFFE2E5EB);

    final l10n = AppLocalizations.of(context)!;
    final options = _options;
    final inputs = options?.where((o) => !o.isMonitor).toList() ?? const [];
    final monitors = options?.where((o) => o.isMonitor).toList() ?? const [];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: borderColor, width: 1.2),
          left: BorderSide(color: borderColor, width: 1.2),
          right: BorderSide(color: borderColor, width: 1.2),
        ),
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
              _header(l10n),
              if (CallNoMute.enabled) _noMuteHint(l10n),
              if (options == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: accentColor,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    children: [
                      _tile(
                        id: null,
                        label: l10n.callMicrophoneSystem,
                        icon: Symbols.settings_voice,
                        viaDevice: true,
                      ),
                      if (options.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Text(
                            l10n.callMicrophoneEmpty,
                            style: const TextStyle(
                              color: subtitleColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      for (final option in inputs)
                        _tile(
                          id: option.id,
                          label: option.label,
                          detail: option.detail,
                          icon: Symbols.mic,
                          viaDevice: option.isDevice,
                        ),
                      if (monitors.isNotEmpty) ...[
                        _group(l10n.callMicrophoneMonitors),
                        for (final option in monitors)
                          _tile(
                            id: option.id,
                            label: option.label,
                            detail: option.detail,
                            icon: Symbols.graphic_eq,
                            viaDevice: option.isDevice,
                          ),
