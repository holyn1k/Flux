import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/calls/call_session.dart';
import '../../../core/config/app_fonts.dart';
import '../../../core/games/checkers.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/sheet_helpers.dart';

Future<void> showFluxHub(
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
      child: _FluxHub(session: session),
    ),
  );
}

enum _HubPage { menu, chat, games, checkers }

class _FluxHub extends StatefulWidget {
  final CallSession session;

  const _FluxHub({required this.session});

  @override
  State<_FluxHub> createState() => _FluxHubState();
}

class _FluxHubState extends State<_FluxHub> {
  _HubPage _page = _HubPage.menu;

  void _go(_HubPage page) => setState(() => _page = page);

  void _back() {
    switch (_page) {
      case _HubPage.menu:
        Navigator.of(context).maybePop();
        break;
      case _HubPage.checkers:
        _go(_HubPage.games);
        break;
      case _HubPage.chat:
      case _HubPage.games:
        _go(_HubPage.menu);
        break;
    }
  }

  String get _title {
    final l10n = AppLocalizations.of(context)!;
    switch (_page) {
      case _HubPage.menu:
        return 'Flux Hub';
      case _HubPage.chat:
        return l10n.hubChatPageTitle;
      case _HubPage.games:
        return l10n.hubGamesTitle;
      case _HubPage.checkers:
        return l10n.hubCheckersTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const Center(
                  child: SheetGrabber(margin: EdgeInsets.only(bottom: 8)),
                ),
                _header(),
                Flexible(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    const textColor = Color(0xFF1A1A1A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _back,
            icon: Icon(
              _page == _HubPage.menu ? Symbols.close : Symbols.arrow_back,
              color: textColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _title,
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: displayFontOf(context),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_page) {
      case _HubPage.menu:
        return _menu();
      case _HubPage.games:
        return _games();
      case _HubPage.chat:
        return _FluxChatView(session: widget.session);
      case _HubPage.checkers:
        return _CheckersView(session: widget.session);
    }
  }

  Widget _menu() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tile(
          Symbols.forum,
          l10n.hubChatTileTitle,
          l10n.hubChatTileSubtitle,
          () => _go(_HubPage.chat),
        ),
        _tile(
          Symbols.stadia_controller,
          l10n.hubGamesTitle,
          l10n.hubGamesTileSubtitle,
          () => _go(_HubPage.games),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _games() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tile(
          Symbols.grid_on,
          l10n.hubCheckersTitle,
          l10n.hubCheckersTileSubtitle,
          () => _go(_HubPage.checkers),
        ),
        _tile(
          Symbols.more_horiz,
          l10n.hubMoreSoonTitle,
          l10n.hubMoreSoonSubtitle,
          null,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _tile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? onTap,
  ) {
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);
    const accentColor = Color(0xFF1E88E5);
    final enabled = onTap != null;

    return ListTile(
      onTap: onTap,
      enabled: enabled,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF3F4F7) : const Color(0xFFF8F9FA),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE2E5EB), width: 1),
        ),
        child: Icon(
          icon,
          color: enabled ? accentColor : const Color(0xFFBDBDBD),
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? textColor : const Color(0xFFBDBDBD),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: enabled ? subtitleColor : const Color(0xFFBDBDBD),
          fontSize: 13,
        ),
      ),
      trailing: enabled
          ? const Icon(Symbols.chevron_right, color: subtitleColor, size: 20)
          : null,
    );
  }
}

class _FluxChatView extends StatefulWidget {
  final CallSession session;

  const _FluxChatView({required this.session});

  @override
  State<_FluxChatView> createState() => _FluxChatViewState();
}

class _FluxChatViewState extends State<_FluxChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  StreamSubscription<CallChatMessage>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.session.chatMessages.listen((_) {
      if (mounted) setState(() {});
      _scrollToBottom();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.session.sendChatMessage(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const subtitleColor = Color(0xFF757575);
    const primaryColor = Color(0xFF2C3E50);
    final messages = widget.session.chatLog;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDE6ED), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Symbols.lock, size: 16, color: primaryColor, fill: 1),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.hubChatPrivacyNote,
                    style: const TextStyle(color: subtitleColor, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        Flexible(
          child: messages.isEmpty
              ? _empty()
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _bubble(messages[i]),
                ),
        ),
        _input(),
      ],
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          AppLocalizations.of(context)!.hubChatEmpty,
          style: const TextStyle(color: Color(0xFF757575), fontSize: 14),
        ),
      ),
    );
  }

  Widget _bubble(CallChatMessage message) {
    const primaryColor = Color(0xFF2C3E50);
    const bubbleBgOther = Color(0xFFF3F4F7);
    const textColor = Color(0xFF1A1A1A);

    return Align(
      alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: message.mine ? primaryColor : bubbleBgOther,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: message.mine
                ? Colors.transparent
                : const Color(0xFFE2E5EB),
            width: 1,
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.mine ? Colors.white : textColor,
            fontSize: 15,
            height: 1.25,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _input() {
    const primaryColor = Color(0xFF2C3E50);
    const inputBorderColor = Color(0xFFD6D9E0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 15),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.hubChatInputHint,
                hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF7F8FA),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: inputBorderColor, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 1.6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: primaryColor,
              shape: const CircleBorder(),
            ),
            onPressed: _send,
            icon: const Icon(Symbols.send, fill: 1, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _CheckersView extends StatefulWidget {
  final CallSession session;

  const _CheckersView({required this.session});

  @override
  State<_CheckersView> createState() => _CheckersViewState();
}

class _CheckersViewState extends State<_CheckersView> {
  List<int> _board = Checkers.initial();
  CheckersSide _turn = CheckersSide.white;
  List<int> _path = const [];
  List<List<int>> _legal = const [];
  CheckersSide? _result;
  late final CheckersSide _me;
  StreamSubscription>? _sub;

  @override
  void initState() {
    super.initState();
    final self = widget.session.selfUserId;
    final peer = widget.session.peerUserId ?? (self + 1);
    _me = self <= peer ? CheckersSide.white : CheckersSide.black;
    _recompute();
    _sub = widget.session.gameMessages.listen(_onGame);
  }

  void _recompute() {
    _legal = Checkers.legalMoves(_board, _turn);
    _result = _legal.isEmpty ? Checkers.opponent(_turn) : null;
  }

  void _restart() {
    _board = Checkers.initial();
    _turn = CheckersSide.white;
    _path = const [];
    _recompute();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onGame(Map<String, dynamic> data) {
    if (data['g'] != 'checkers') return;
    if (data['a'] == 'reset') {
      setState(_restart);
      return;
    }
    if (data['a'] == 'move') {
      final raw = data['path'];
      if (raw is! List) return;
      _applyMove(raw.map((e) => e as int).toList(), fromRemote: true);
    }
  }

  void _applyMove(List<int> path, {required bool fromRemote}) {
    if (!_legal.any((p) => _listEq(p, path))) return;
    setState(() {
      _board = Checkers.applyMove(_board, path);
      _turn = Checkers.opponent(_turn);
      _path = const [];
      _recompute();
    });
    if (!fromRemote) {
      widget.session.sendGame({'g': 'checkers', 'a': 'move', 'path': path});
    }
  }

  void _reset() {
    setState(_restart);
    widget.session.sendGame({'g': 'checkers', 'a': 'reset'});
  }

  void _onTap(int square) {
    if (_turn != _me || _result != null) return;

    if (_path.isEmpty) {
      if (_legal.any((p) => p.first == square)) {
        setState(() => _path = [square]);
      }
      return;
    }

    final prefix = [..._path, square];
    final matching = _legal.where((p) => _startsWith(p, prefix)).toList();
    if (matching.isEmpty) {
      setState(
        () =>
            _path = _legal.any((p) => p.first == square) ? [square] : const [],
      );
      return;
    }
    if (matching.any((p) => p.length == prefix.length)) {
      _applyMove(prefix, fromRemote: false);
    } else {
      setState(() => _path = prefix);
    }
  }

  Set<int> _options() {
    if (_turn != _me || _result != null) return const {};
    if (_path.isEmpty) return {for (final p in _legal) p.first};
    final next = <int>{};
    for (final p in _legal) {
      if (_startsWith(p, _path) && p.length > _path.length) {
        next.add(p[_path.length]);
      }
    }
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);
    const accentColor = Color(0xFF1E88E5);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _status(),
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Symbols.refresh, size: 20, color: accentColor),
                label: Text(
                  l10n.hubCheckersRestart,
                  style: const TextStyle(color: accentColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _boardWidget(),
          const SizedBox(height: 10),
          Text(
            _me == CheckersSide.white
                ? l10n.hubCheckersYouWhite
                : l10n.hubCheckersYouBlack,
            style: const TextStyle(color: subtitleColor, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _status() {
    final l10n = AppLocalizations.of(context)!;
    final w = _result;
    if (w != null) return w == _me ? l10n.hubCheckersWon : l10n.hubCheckersLost;
    return _turn == _me
        ? l10n.hubCheckersYourMove
        : l10n.hubCheckersOpponentMove;
  }

  Widget _boardWidget() {
    final flip = _me == CheckersSide.black;
    final options = _options();
    final selected = _path.isNotEmpty ? _path.last : -1;

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD6D9E0), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Checkers.size,
          ),
          itemCount: Checkers.size * Checkers.size,
          itemBuilder: (_, i) {
            final square = flip ? (Checkers.size * Checkers.size - 1 - i) : i;
            final rb = square ~/ Checkers.size;
            final cb = square % Checkers.size;
            final dark = (rb + cb) % 2 == 1;
            return GestureDetector(
              onTap: dark ? () => _onTap(square) : null,
              child: _cell(
                dark: dark,
                piece: _board[square],
                option: options.contains(square),
                selected: square == selected,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _cell({
    required bool dark,
    required int piece,
    required bool option,
    required bool selected,
  }) {
    const darkCell = Color(0xFFE2E7ED);
    const lightCell = Color(0xFFFAFBFC);
    const selectedCell = Color(0xFFBBDEFB);

    final base = dark ? darkCell : lightCell;
    return Container(
      color: selected ? selectedCell : base,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (option && piece == Checkers.empty)
            FractionallySizedBox(
              widthFactor: 0.34,
              heightFactor: 0.34,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E88E5).withValues(alpha: 0.6),
                ),
              ),
            ),
          if (piece != Checkers.empty) _piece(piece, option),
        ],
      ),
    );
  }

  Widget _piece(int piece, bool option) {
    final white = Checkers.sideOf(piece) == CheckersSide.white;
    final king = Checkers.isKing(piece);
    const accentColor = Color(0xFF1E88E5);

    return FractionallySizedBox(
      widthFactor: 0.76,
      heightFactor: 0.76,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: white ? Colors.white : const Color(0xFF2C3E50),
          border: Border.all(
            color: option
                ? accentColor
                : (white ? const Color(0xFFB0BEC5) : const Color(0xFF1A252F)),
            width: option ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: king
            ? Icon(
                Symbols.star,
                fill: 1,
                size: 16,
                color: white
                    ? const Color(0xFFD4AF37)
                    : const Color(0xFFFFD54F),
              )
            : null,
      ),
    );
  }

  bool _startsWith(List<int> path, List<int> prefix) {
    if (path.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (path[i] != prefix[i]) return false;
    }
    return true;
  }

  bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
