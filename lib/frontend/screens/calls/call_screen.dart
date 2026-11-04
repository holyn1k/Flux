import 'dart:async';
import 'dart:math' show cos, pi;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart'
    show MediaStream, RTCVideoRenderer, RTCVideoValue, RTCVideoViewObjectFit;
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/messages.dart' show ContactCache;
import '../../../core/cache/info_cache.dart';
import '../../../core/calls/active_call.dart';
import '../../../core/calls/call_controller.dart';
import '../../../core/calls/call_info.dart';
import '../../../core/calls/call_session.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/config/app_fonts.dart';
import '../../../core/config/call_no_mute.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/screen_wake.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/animated_slash_icon.dart';
import '../../widgets/call_video_view.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/sheet_helpers.dart';
import '../../widgets/small_spinner.dart';
import 'call_mic_sheet.dart';
import 'call_participants_sheet.dart';
import 'flux_hub.dart';

class CallScreen extends StatefulWidget {
  final String name;
  final String? avatarUrl;
  final CallSession? session;
  final IncomingCall? incoming;
  final bool isGroup;
  final bool autoAccept;

  const CallScreen({
    super.key,
    required this.name,
    this.avatarUrl,
    this.session,
    this.incoming,
    this.isGroup = false,
    this.autoAccept = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  CallSession? _session;
  StreamSubscription<CallSessionState>? _stateSub;
  StreamSubscription<void>? _canceledSub;
  StreamSubscription<void>? _infoSub;
  StreamSubscription<void>? _fluxSub;
  StreamSubscription<CallChatMessage>? _chatSub;
  StreamSubscription<MediaStream>? _remoteStreamSub;
  bool _chatOpen = false;
  CallSessionState _state = CallSessionState.connecting;
  bool _incomingPending = false;

  bool _isMuted = false;
  bool _isSpeaker = false;

  late final AnimationController _dotsController;
  late final AnimationController _videoController;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<int, RTCVideoRenderer> _tileRenderers = {};
  StreamSubscription<int>? _tileStreamSub;
  bool _rendererReady = false;
  bool _localRendererReady = false;
  bool _videoAttached = false;
  MediaStream? _pendingStream;

  late String _name = widget.name;
  late String? _avatarUrl = widget.avatarUrl;

  final Map<int, _PeerInfo> _peerInfo = {};

  bool get _isGroup => widget.isGroup || (_session?.participantCount ?? 0) > 2;

  void _onTileStream(int id) {
    final stream = _session?.streamOf(id);
    final existing = _tileRenderers[id];
    if (existing != null) {
      existing.srcObject = stream;
      if (mounted) setState(() {});
      return;
    }
    if (stream == null) return;
    unawaited(_createTileRenderer(id, stream));
  }

  Future<void> _createTileRenderer(int id, MediaStream stream) async {
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    if (!mounted) {
      await renderer.dispose();
      return;
    }
    renderer.srcObject = stream;
    _tileRenderers[id] = renderer;
    setState(() {});
  }

  RTCVideoRenderer? _tileRenderer(CallParticipant p) {
    if (p.isSelf) return null;
    final own = _tileRenderers[p.id];
    final src = own?.srcObject;
    if (src != null && src.getVideoTracks().isNotEmpty) return own;
    return _tileVideoReady ? _remoteRenderer : null;
  }

  bool get _tileVideoReady {
    if (_session?.topology == 'SERVER') return false;
    final others = (_session?.participants ?? const <CallParticipant>[])
        .where((x) => !x.isSelf)
        .length;
    if (others != 1) return false;
    final src = _remoteRenderer.srcObject;
    return src != null && src.getVideoTracks().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    ActiveCall.instance.enterScreen();
    unawaited(ScreenWake.instance.acquire(this));
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _videoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _initRenderer();

    _incomingPending = widget.session == null && widget.incoming != null;
    if (widget.session != null) _bind(widget.session!);

    final incoming = widget.incoming;
    if (incoming != null && (_name.isEmpty || _avatarUrl == null)) {
      _resolvePeerInfo(incoming.callerId);
    }
    if (incoming != null) {
      _canceledSub = CallController.instance.incomingCanceled.listen((_) {
        if (mounted && _incomingPending) _close();
      });
    }
    if (widget.autoAccept && incoming != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _incomingPending) _accept();
      });
    }
  }

  Future<void> _resolvePeerInfo(int id) async {
    var name = ContactCache.get(id);
    var avatar = ContactCache.getAvatar(id);
    if (name == null || avatar == null) {
      final info = await ContactInfoFetch.get(id);
      if (info != null) {
        name ??= info.displayName;
        avatar ??= info.avatarUrl;
        if (name != null) ContactCache.put(id, name);
        ContactCache.putAvatar(id, avatar);
      }
    }
    if (!mounted) return;
    setState(() {
      if (name != null && name.isNotEmpty) _name = name;
      if (avatar != null && avatar.isNotEmpty) _avatarUrl = avatar;
    });
    _publishActiveCall();
  }

  Future<void> _initRenderer() async {
    await _remoteRenderer.initialize();
    await _localRenderer.initialize();
    if (!mounted) return;
    _rendererReady = true;
    _localRendererReady = true;
    if (_pendingStream != null) {
      _remoteRenderer.srcObject = _pendingStream;
      _pendingStream = null;
    }
    _syncLocalPreview();
    setState(() {});
  }

  void _attachStream(MediaStream stream) {
    if (!_rendererReady) {
      _pendingStream = stream;
      return;
    }
    final hasVideo = stream.getVideoTracks().isNotEmpty;
    if (!identical(_remoteRenderer.srcObject, stream)) {
      _remoteRenderer.srcObject = stream;
    } else if (hasVideo && !_videoAttached) {
      _remoteRenderer.srcObject = null;
      _remoteRenderer.srcObject = stream;
    } else {
      return;
    }
    if (hasVideo) _videoAttached = true;
    if (mounted) setState(() {});
  }

  void _syncVideo() {
    if (_session?.peerVideo == true) {
      _videoController.forward();
    } else {
      _videoController.reverse();
    }
  }

  void _bind(CallSession session) {
    _session = session;
    _state = session.currentState;
    _stateSub = session.stateStream.listen(_onState);
    _infoSub = session.infoUpdates.listen((_) {
      if (!mounted) return;
      _isMuted = session.isMuted;
      _resolveParticipants();
      _syncVideo();
      _syncLocalPreview();
      _isSpeaker = session.isSpeaker;
      setState(() {});
      _publishActiveCall();
    });
    _remoteStreamSub = session.remoteStreamStream.listen(_attachStream);
    _tileStreamSub = session.participantStreamUpdates.listen(_onTileStream);
    _fluxSub = session.peerKometDetected.listen((_) => _showFluxBadge());
    _chatSub = session.chatMessages.listen(_onChatMessage);
    if (session.peerIsKomet) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showFluxBadge());
    }
    final existing = session.remoteStream;
    if (existing != null) _attachStream(existing);
    _resolveParticipants();
    _syncVideo();
    _isSpeaker = session.isSpeaker;
    _publishActiveCall();
  }

  void _publishActiveCall() {
    final session = _session;
    if (session == null) return;
    ActiveCall.instance.attach(
      session: session,
      name: _name,
      avatarUrl: _avatarUrl,
      isGroup: _isGroup,
    );
  }

  void _showFluxBadge() {
    if (!mounted) return;
    showCustomNotification(context, 'Собеседник использует Flux');
  }

  void _onChatMessage(CallChatMessage message) {
    if (!mounted || message.mine || _chatOpen) return;
    showCustomNotification(context, message.text);
  }

  Future<void> _openFluxHub() async {
    final session = _session;
    if (session == null) return;
    setState(() => _chatOpen = true);
    await showFluxHub(
      context,
      session: session,
      scheme: Theme.of(context).colorScheme,
    );
    if (mounted) setState(() => _chatOpen = false);
  }

  void _resolveParticipants() {
    final session = _session;
    if (session == null) return;
    for (final p in session.participants) {
      final ext = p.externalId;
      if (ext == null || p.isSelf || _peerInfo.containsKey(ext)) continue;
      _peerInfo[ext] = const _PeerInfo(resolving: true);
      unawaited(_resolveParticipant(ext));
    }
  }

  Future<void> _resolveParticipant(int id) async {
    var name = ContactCache.get(id);
    var avatar = ContactCache.getAvatar(id);
    if (name == null) {
      final info = await ContactInfoFetch.get(id);
      if (info != null) {
        name = info.displayName;
        avatar ??= info.avatarUrl;
        if (name != null) ContactCache.put(id, name);
        ContactCache.putAvatar(id, avatar);
      }
    }
    if (!mounted) return;
    setState(() => _peerInfo[id] = _PeerInfo(name: name, avatar: avatar));
  }

  void _onState(CallSessionState state) {
    if (!mounted) return;
    setState(() => _state = state);
    if (state == CallSessionState.ended) _close();
  }

  Future<void> _accept() async {
    final incoming = widget.incoming;
    if (incoming == null) return;
    setState(() {
      _incomingPending = false;
      _state = CallSessionState.connecting;
    });
    try {
      final session = await CallController.instance.acceptIncoming(incoming);
      if (!mounted) return;
      _bind(session);
    } catch (_) {
      _close();
    }
  }

  Future<void> _decline() async {
    final incoming = widget.incoming;
    if (incoming != null) {
      await CallController.instance.rejectIncoming(incoming);
    }
    _close();
  }

  Future<void> _hangup() async {
    final session = _session;
    if (session != null) {
      await session.hangup();
    }
    _close();
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _toggleMute() async {
    final next = !_isMuted;
    setState(() => _isMuted = next);
    await _session?.setMuted(next);
  }

  Future<void> _toggleSpeaker() async {
    final session = _session;
    if (session == null) return;
    final next = !session.isSpeaker;
    setState(() => _isSpeaker = next);
    await session.setSpeaker(next);
  }

  bool _videoBusy = false;

  Future<void> _toggleVideo() async {
    final session = _session;
    if (session == null || _videoBusy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _videoBusy = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      await session.setVideoEnabled(!session.localVideo);
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, l10n.callCameraUnavailable(e));
      }
    } finally {
      _syncLocalPreview();
      if (mounted) setState(() => _videoBusy = false);
    }
  }

  Future<void> _toggleScreen() async {
    final session = _session;
    if (session == null || _videoBusy) return;
    setState(() => _videoBusy = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      await session.setScreenSharing(!session.localScreen);
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, 'Трансляция не запустилась: $e');
      }
    } finally {
      _syncLocalPreview();
      if (mounted) setState(() => _videoBusy = false);
    }
  }

  void _syncLocalPreview() {
    if (!_localRendererReady) return;
    _localRenderer.srcObject = _session?.localVideoStream;
  }

  @override
  void dispose() {
    ActiveCall.instance.leaveScreen();
    unawaited(ScreenWake.instance.release(this));
    _stateSub?.cancel();
    _canceledSub?.cancel();
    _infoSub?.cancel();
    _fluxSub?.cancel();
    _chatSub?.cancel();
    _remoteStreamSub?.cancel();
    _tileStreamSub?.cancel();
    for (final renderer in _tileRenderers.values) {
      renderer.srcObject = null;
      renderer.dispose();
    }
    _tileRenderers.clear();
    _dotsController.dispose();
    _videoController.dispose();
    if (_rendererReady) _remoteRenderer.srcObject = null;
    _remoteRenderer.dispose();
    if (_localRendererReady) _localRenderer.srcObject = null;
    _localRenderer.dispose();
    super.dispose();
  }

  void _showParticipants() {
    final session = _session;
    if (session == null) return;
    final l10n = AppLocalizations.of(context)!;
    showCallParticipantsSheet(
      context,
      session: session,
      scheme: Theme.of(context).colorScheme,
      resolve: (p) {
        if (p.isSelf) {
          return CallParticipantView(
            name: l10n.callParticipantYou,
            avatarUrl: _avatarUrl,
          );
        }
        final ext = p.externalId;
        final info = ext != null ? _peerInfo[ext] : null;
        return CallParticipantView(
          name: info?.name?.isNotEmpty == true
              ? info!.name!
              : l10n.callParticipantFallback,
          avatarUrl: info?.avatar,
        );
      },
    );
  }

  void _showMicrophones() {
    final session = _session;
    if (session == null) return;
    showCallMicrophoneSheet(
      context,
      session: session,
      scheme: Theme.of(context).colorScheme,
    );
  }

  void _showInfoSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CallInfoSheet(
        session: _session,
        incoming: widget.incoming,
        name: _displayName,
        renderer: _remoteRenderer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = _isGroup && !_incomingPending;

    final Widget body = group
        ? _buildGroupBody()
        : AnimatedBuilder(
            animation: _videoController,
            builder: (context, _) => _buildBody(
              avatar: _buildAvatar(),
              name: _buildName(),
              status: _buildStatus(),
              peerBar: _peerStateBar(),
              controls: _buildControls(),
            ),
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            body,
            if (_session?.localVideo == true || _session?.localScreen == true)
              _localPreview(),
          ],
        ),
      ),
    );
  }

  Widget _localPreview() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).padding.top + 56,
      child: SafeArea(
        child: Container(
          width: 96,
          height: 140,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFF7F8FA),
            border: Border.all(color: const Color(0xFFD6D9E0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _localRendererReady && _localRenderer.srcObject != null
              ? CallVideoView(
                  renderer: _localRenderer,
                  mirror: _session?.localScreen != true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  placeholder: _localPreviewIcon(),
                )
              : _localPreviewIcon(),
        ),
      ),
    );
  }

  Widget _localPreviewIcon() => const Center(
    child: Icon(
      Symbols.videocam,
      color: Color(0xFF757575),
      size: 28,
    ),
  );

  Widget _buildGroupBody() {
    final l10n = AppLocalizations.of(context)!;
    final participants = _session?.participants ?? const <CallParticipant>[];
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(0),
          const SizedBox(height: 4),
          _groupHeader(participants.length),
          const SizedBox(height: 8),
          Expanded(
            child: participants.isEmpty
                ? Center(child: _statusWithDots(l10n.callStatusConnecting))
                : _participantGrid(participants),
          ),
          const SizedBox(height: 12),
          _activeControls(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _groupHeader(int count) {
    final l10n = AppLocalizations.of(context)!;
    final String subtitle;
    if (count == 0) {
      subtitle = l10n.callGroupConnecting;
    } else if (count <= 1) {
      subtitle = l10n.callGroupWaitingParticipants;
    } else {
      subtitle =
          '$count ${pluralRu(count, 'участник', 'участника', 'участников')}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            _displayName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF1A1A1A),
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFamily: displayFontOf(context),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: count > 0 ? _showParticipants : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Symbols.chevron_right,
                      size: 16,
                      color: Color(0xFF757575),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _participantGrid(List<CallParticipant> ps) {
    final cols = ps.length <= 1
        ? 1
        : ps.length <= 4
        ? 2
        : 3;
    return GridView.count(
      crossAxisCount: cols,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.84,
      children: [for (final p in ps) _participantTile(p)],
    );
  }

  Widget _participantTile(CallParticipant p) {
    final l10n = AppLocalizations.of(context)!;
    final ext = p.externalId;
    final info = ext != null ? _peerInfo[ext] : null;
    final name = p.isSelf
        ? l10n.callParticipantYou
        : (info?.name?.isNotEmpty == true
              ? info!.name!
              : l10n.callParticipantFallback);
    final url = p.isSelf ? _avatarUrl : info?.avatar;
    final muted = p.isSelf ? _isMuted : !p.audioEnabled;
    final speaking = !muted && _session?.isSpeaking(p.id) == true;
    final renderer = _tileRenderer(p);
    final showVideo =
        !p.isSelf && (p.videoEnabled || p.screenSharing) && renderer != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: speaking ? kSuccessGreen : const Color(0xFFE2E5EB),
          width: speaking ? 2.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(showVideo ? 0 : 12),
      clipBehavior: Clip.antiAlias,
      child: showVideo
          ? _videoTile(renderer, name, muted, p.handRaised, p.screenSharing)
          : _avatarTile(name, url, muted, p.handRaised, p.screenSharing),
    );
  }

  Widget _avatarTile(
    String name,
    String? url,
    bool muted,
    bool hand,
    bool screen,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest.shortestSide.clamp(48.0, 96.0);
              return Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _circleAvatar(size, name: name, url: url),
                      if (hand)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: _tileBadge(
                            Symbols.front_hand,
                            const Color(0xFFFFF3E0),
                            const Color(0xFFF57C00),
                          ),
                        ),
                      if (screen)
                        Positioned(
                          top: -2,
                          left: -2,
                          child: _tileBadge(
                            Symbols.screen_share,
                            const Color(0xFFE3F2FD),
                            const Color(0xFF1E88E5),
                          ),
                        ),
                      if (muted)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: _tileBadge(
                            Symbols.mic_off,
                            const Color(0xFFFFEBEE),
                            const Color(0xFFE53935),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _videoTile(
    RTCVideoRenderer renderer,
    String name,
    bool muted,
    bool hand,
    bool screen,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CallVideoView(
            renderer: renderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            placeholder: const ColoredBox(color: Color(0xFFF0F4F8)),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Row(
              children: [
                if (muted)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Symbols.mic_off,
                      size: 16,
                      color: Colors.white,
                      fill: 1,
                    ),
                  ),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hand)
            Positioned(
              top: 8,
              right: 8,
              child: _tileBadge(
                Symbols.front_hand,
                const Color(0xFFFFF3E0),
                const Color(0xFFF57C00),
              ),
            ),
          if (screen)
            Positioned(
              top: 8,
              left: 8,
              child: _tileBadge(
                Symbols.screen_share,
                const Color(0xFFE3F2FD),
                const Color(0xFF1E88E5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tileBadge(IconData icon, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, size: 14, color: fg, fill: 1),
    );
  }

  Widget _buildBody({
    required Widget avatar,
    required Widget name,
    required Widget status,
    required Widget? peerBar,
    required Widget controls,
  }) {
    final t = Curves.easeInOut.transform(_videoController.value);
    final showVideo = t > 0.001 && _remoteRenderer.srcObject != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (showVideo)
          Center(
            child: Opacity(
              opacity: t,
              child: FractionallySizedBox(
                widthFactor: 0.62 + 0.38 * t,
                heightFactor: 0.46 + 0.54 * t,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24 * (1 - t)),
                  child: ValueListenableBuilder<RTCVideoValue>(
                    valueListenable: _remoteRenderer,
                    builder: (context, value, _) {
                      final ar = value.aspectRatio > 0
                          ? value.aspectRatio
                          : 16 / 9;
                      return Center(
                        child: AspectRatio(
                          aspectRatio: ar,
                          child: RepaintBoundary(
                            child: CallVideoView(
                              renderer: _remoteRenderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        if (t > 0.001)
          IgnorePointer(
            child: Opacity(opacity: t, child: _videoScrim()),
          ),
        SafeArea(
          child: Column(
            children: [
              _buildTopBar(t),
              const Spacer(flex: 2),
              _collapse(t, avatar),
              SizedBox(height: 36 * (1 - t)),
              _collapse(t, name),
              SizedBox(height: 12 * (1 - t)),
              _collapse(t, status),
              if (peerBar != null) ...[
                SizedBox(height: 14 * (1 - t)),
                _collapse(t, peerBar),
              ],
              const Spacer(flex: 5),
              controls,
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _collapse(double t, Widget child) {
    if (t <= 0.001) return child;
    if (t >= 0.999) return const SizedBox.shrink();
    return Opacity(
      opacity: 1 - t,
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1 - t,
          child: child,
        ),
      ),
    );
  }

  Widget _videoScrim() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.65),
            Colors.transparent,
            Colors.transparent,
            Colors.white.withValues(alpha: 0.75),
          ],
          stops: const [0.0, 0.34, 0.70, 1.0],
        ),
      ),
    );
  }

  Widget _buildTopBar(double t) {
    final l10n = AppLocalizations.of(context)!;
    final showTimer =
        t > 0.001 &&
        _session != null &&
        _state == CallSessionState.active &&
        _session!.mediaConnected;
    const iconColor = Color(0xFF1A1A1A);

    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: l10n.callTooltipMinimize,
              icon: const Icon(
                Symbols.close_fullscreen,
                color: iconColor,
                weight: 500,
                size: 24,
              ),
            ),
          ),
          if (_session != null)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_session?.peerIsKomet == true)
                    IconButton(
                      onPressed: _openFluxHub,
                      tooltip: 'Flux Hub',
                      icon: const Icon(
                        Symbols.auto_awesome,
                        color: Color(0xFF1E88E5),
                        weight: 500,
                        size: 24,
                      ),
                    ),
                  IconButton(
                    onPressed: _showMicrophones,
                    tooltip: l10n.callTooltipMicrophone,
                    icon: const Icon(
                      Symbols.settings_voice,
                      color: iconColor,
                      weight: 500,
                      size: 24,
                    ),
                  ),
                  IconButton(
                    onPressed: _showInfoSheet,
                    tooltip: l10n.callInfoTitle,
                    icon: const Icon(
                      Symbols.info,
                      color: iconColor,
                      weight: 500,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          if (showTimer)
            Align(
              alignment: Alignment.center,
              child: Opacity(
                opacity: t,
                child: _ElapsedText(
                  session: _session!,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _peerStateBar() {
    final l10n = AppLocalizations.of(context)!;
    final session = _session;
    if (session == null) return null;
    final pills = <Widget>[
      if (session.peerMuted)
        _statePill(Symbols.mic_off, l10n.callPeerMicOff),
      if (session.peerVideo)
        _statePill(Symbols.videocam, l10n.callPeerCameraOn),
    ];
    if (pills.isEmpty) return null;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: pills,
    );
  }

  Widget _statePill(IconData icon, String label) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F7),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFE2E5EB), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF616161), fill: 1),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF424242),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarSize = (MediaQuery.of(context).size.shortestSide * 0.42).clamp(
      128.0,
      172.0,
    );
    return _avatarCircle(avatarSize);
  }

  String get _displayName =>
      _name.isEmpty ? AppLocalizations.of(context)!.callUnknownName : _name;

  Widget _avatarCircle(double size) =>
      _circleAvatar(size, name: _displayName, url: _avatarUrl);

  Widget _circleAvatar(
    double size, {
    required String name,
    String? url,
  }) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF0F4F8),
        border: Border.all(
          color: const Color(0xFF1E88E5).withValues(alpha: 0.35),
          width: 3.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: (url != null && url.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: 420,
              memCacheHeight: 420,
              errorWidget: (_, _, _) => _avatarFallback(size, name),
            )
          : _avatarFallback(size, name),
    );
  }

  Widget _avatarFallback(double size, String name) {
    final letter = (name.isEmpty ? '?' : name[0]).toUpperCase();
    return Container(
      color: const Color(0xFFF0F4F8),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: const Color(0xFF2C3E50),
          fontSize: size * 0.40,
          fontWeight: FontWeight.w700,
          fontFamily: displayFontOf(context),
        ),
      ),
    );
  }

  Widget _buildName() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        _displayName,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: const Color(0xFF1A1A1A),
          fontSize: 30,
          fontWeight: FontWeight.w700,
          fontFamily: displayFontOf(context),
          letterSpacing: -0.5,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildStatus() {
    final l10n = AppLocalizations.of(context)!;
    if (!_incomingPending && _state == CallSessionState.active) {
      final session = _session;
      if (session == null) return const SizedBox.shrink();
      if (!session.mediaConnected) {
        return _statusWithDots(l10n.callStatusConnecting);
      }
      return _ElapsedText(
        session: session,
        style: const TextStyle(
          color: Color(0xFF757575),
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      );
    }

    if (_incomingPending) {
      return Text(
        l10n.callIncoming,
        style: const TextStyle(
          color: Color(0xFF757575),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    String text;
    switch (_state) {
      case CallSessionState.connecting:
        text = l10n.callStatusConnecting;
      case CallSessionState.ringing:
        text = l10n.callStatusRinging;
      case CallSessionState.active:
        text = '';
      case CallSessionState.ended:
        text = l10n.callStatusEnded;
    }

    return _statusWithDots(text);
  }

  Widget _statusWithDots(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF757575),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        _CallingDots(
          animation: _dotsController,
          color: const Color(0xFF757575),
        ),
      ],
    );
  }

  Widget _buildControls() {
    if (_incomingPending) return _incomingControls();
    return _activeControls();
  }

  Widget _incomingControls() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 56),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CallButton(
            icon: Symbols.call_end,
            label: l10n.callDecline,
            background: kDangerRed,
            foreground: Colors.white,
            onTap: _decline,
          ),
          _CallButton(
            icon: Symbols.call,
            label: l10n.callAccept,
            background: kSuccessGreen,
            foreground: Colors.white,
            onTap: _accept,
          ),
        ],
      ),
    );
  }

  Widget _activeControls() {
    final l10n = AppLocalizations.of(context)!;
    final video = _session?.localVideo == true;
    final screen = _session?.localScreen == true;
    const defaultBg = Color(0xFFF3F4F7);
    const activeBg = Color(0xFF2C3E50);
    const defaultFg = Color(0xFF2C3E50);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CallButton(
            icon: _isSpeaker ? Symbols.volume_up : Symbols.volume_down,
            label: l10n.callSpeaker,
            background: _isSpeaker ? activeBg : defaultBg,
            foreground: _isSpeaker ? Colors.white : defaultFg,
            onTap: _toggleSpeaker,
          ),
          _CallButton(
            icon: Symbols.videocam,
            slashedIcon: Symbols.videocam_off,
            slashed: !video,
            label: l10n.callVideoLabel,
            background: video ? activeBg : defaultBg,
            foreground: video ? Colors.white : defaultFg,
            busy: _videoBusy,
            onTap: _toggleVideo,
          ),
          _CallButton(
            icon: Symbols.screen_share,
            label: l10n.callScreenLabel,
            background: screen ? activeBg : defaultBg,
            foreground: screen ? Colors.white : defaultFg,
            busy: _videoBusy,
            onTap: _toggleScreen,
          ),
          _CallButton(
            icon: Symbols.mic,
            slashedIcon: Symbols.mic_off,
            slashed: _isMuted,
            label: _isMuted
                ? (CallNoMute.enabled ? l10n.callMicStillLive : l10n.callUnmute)
                : l10n.callMute,
            background: _isMuted ? const Color(0xFFFFEBEE) : defaultBg,
            foreground: _isMuted ? const Color(0xFFE53935) : defaultFg,
            onTap: _toggleMute,
            onLongPress: _showMicrophones,
          ),
          _CallButton(
            icon: Symbols.call_end,
            label: l10n.callEndButton,
            background: kDangerRed,
            foreground: Colors.white,
            onTap: _hangup,
          ),
        ],
      ),
    );
  }
}

class _PeerInfo {
  final String? name;
  final String? avatar;
  final bool resolving;

  const _PeerInfo({this.name, this.avatar, this.resolving = false});
}

class _CallingDots extends StatelessWidget {
  final Animation<double> animation;
  final Color color;

  const _CallingDots({required this.animation, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final v = animation.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (v + i / 3) % 1.0;
            final alpha = 0.3 + 0.7 * (0.5 - 0.5 * cos(phase * 2 * pi));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: alpha),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final IconData? slashedIcon;
  final bool slashed;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool busy;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.onLongPress,
    this.slashedIcon,
    this.slashed = false,
    this.busy = false,
  });

  Widget _buildIcon() {
    final crossed = slashedIcon;
    if (crossed == null) {
      return Icon(icon, color: foreground, size: 26, fill: 1);
    }
    return AnimatedSlashIcon(
      icon: icon,
      slashedIcon: crossed,
      slashed: slashed,
      color: foreground,
      size: 26,
      fill: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 62,
          height: 62,
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(31),
            elevation: 0,
            child: InkWell(
              onTap: busy ? null : onTap,
              onLongPress: busy ? null : onLongPress,
              borderRadius: BorderRadius.circular(31),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(31),
                  border: Border.all(
                    color: const Color(0xFFD6D9E0).withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: busy
                      ? SmallSpinner(size: 22, color: foreground)
                      : _buildIcon(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF757575),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ElapsedText extends StatefulWidget {
  final CallSession session;
  final TextStyle style;

  const _ElapsedText({required this.session, required this.style});

  @override
  State<_ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<_ElapsedText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      formatSecondsMmSs(widget.session.elapsedSeconds, padMinutes: true),
      style: widget.style,
    );
  }
}

class _CallInfoSheet extends StatelessWidget {
  final CallSession? session;
  final IncomingCall? incoming;
  final String name;
  final RTCVideoRenderer renderer;

  const _CallInfoSheet({
    required this.session,
    required this.incoming,
    required this.name,
    required this.renderer,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final info = session?.info;

    final rows = <List<String>>[];
    void add(String k, String? v) {
      if (v != null && v.isNotEmpty) rows.add([k, v]);
    }

    add(l10n.callInfoClient, _clientLine(info));
    add(l10n.callInfoPlatform, info?.peerPlatform);
    add(l10n.callInfoCountry, incoming?.country);
    final isContact = incoming?.isContact;
    if (isContact != null) {
      add(
        l10n.callInfoInContacts,
        isContact ? l10n.callValueYes : l10n.callValueNo,
      );
    }
    add(l10n.callInfoPeerIp, info?.peerIp);
    add(l10n.callInfoPeerNetwork, info?.peerNetwork);
    add(l10n.callInfoPath, info?.path);
    add(l10n.callInfoCodec, info?.audioCodec);
    add(l10n.callInfoServer, info?.region);
    add(l10n.callInfoTopology, info?.topology);
    add('Conversation ID', info?.conversationId);
    if (info?.dtlsFingerprint != null) {
      add('DTLS', _shortFp(info!.dtlsFingerprint!));
    }
    if (session != null) {
      add(
        l10n.callInfoStatus,
        session!.mediaConnected
            ? l10n.callStatusValueConnected
            : l10n.callStatusValueConnecting,
      );
      add(
        l10n.callInfoPeerMic,
        session!.peerMuted ? l10n.callMicValueOff : l10n.callMicValueOn,
      );
      add(
        l10n.callInfoPeerCamera,
        session!.peerVideo ? l10n.callCameraValueOn : l10n.callCameraValueOff,
      );
    }

    final vtracks = renderer.srcObject?.getVideoTracks().length ?? 0;
    add(
      l10n.callInfoVideoTrack,
      vtracks > 0 ? l10n.callInfoVideoTrackPresent(vtracks) : l10n.callValueNo,
    );
    final w = renderer.value.width.toInt();
    final h = renderer.value.height.toInt();
    add(l10n.callInfoVideoSize, (w > 0 && h > 0) ? '$w×$h' : '—');
    add(
      l10n.callInfoFrameRendering,
      renderer.renderVideo ? l10n.callValueYes : l10n.callValueNo,
    );

    final badges = <Widget>[
      _badge(Symbols.lock, l10n.callBadgeEncrypted),
      _badge(Symbols.call, l10n.callBadgeAudio),
      if (info?.record == true)
        _badge(Symbols.radio_button_checked, l10n.callBadgeRecording),
      if (info?.denoise == true)
        _badge(Symbols.noise_control_on, l10n.callBadgeNoiseSuppression),
      if (info?.animoji == true)
        _badge(Symbols.mood, l10n.callBadgeAnimoji),
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: SheetGrabber(margin: EdgeInsets.only(bottom: 16)),
              ),
              Text(
                l10n.callInfoTitle,
                style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: displayFontOf(context),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: const TextStyle(color: Color(0xFF757575), fontSize: 14),
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: badges),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                Text(
                  l10n.callInfoNoDataYet,
                  style: const TextStyle(color: Color(0xFF757575), fontSize: 14),
                ),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(
                          r[0],
                          style: const TextStyle(
                            color: Color(0xFF757575),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SelectableText(
                          r[1],
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _clientLine(CallInfo? info) {
    if (info == null) return null;
    final engine = info.peerEngine;
    if (engine == null || engine == 'неизвестно') return null;
    return engine;
  }

  String _shortFp(String fp) => fp.length > 34 ? '${fp.substring(0, 34)}…' : fp;

  Widget _badge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F7),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFE2E5EB), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF616161), fill: 1),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
