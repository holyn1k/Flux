import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/download_history.dart';
import '../../core/utils/format.dart';
import '../../core/utils/save_file_as.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/chat_menu_overlay.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/custom_notification.dart';
import '../widgets/sheet_helpers.dart';
import '../widgets/small_spinner.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  late bool _loading = DownloadHistory.records.value.isEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_loading) {
      DownloadHistory.refresh().ignore();
      return;
    }
    await DownloadHistory.load();
    if (mounted) setState(() => _loading = false);
    await DownloadHistory.refresh();
  }

  Future<void> _open(DownloadRecord record) async {
    final file = await DownloadHistory.fileFor(record);
    if (!mounted) return;
    if (file == null) {
      await DownloadHistory.remove(record.cacheName);
      if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.downloadsOpenFailed,
        );
      }
      return;
    }
    final result = await OpenFilex.open(file.path);
    if (!mounted || result.type == ResultType.done) return;
    showCustomNotification(
      context,
      AppLocalizations.of(context)!.downloadsOpenFailed,
    );
  }

  Future<void> _saveAs(DownloadRecord record) async {
    final file = await DownloadHistory.fileFor(record);
    if (!mounted) return;
    if (file == null) {
      await DownloadHistory.remove(record.cacheName);
      if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.downloadsOpenFailed,
        );
      }
      return;
    }
    final result = await saveFileAs(
      source: file,
      fileName: _saveName(record),
      dialogTitle: AppLocalizations.of(context)!.photoViewerSaveAs,
    );
    if (!mounted || result.cancelled) return;
    showCustomNotification(
      context,
      result.saved ? 'Файл сохранён' : 'Не удалось сохранить файл',
    );
  }

  void _goToMessage(DownloadRecord record) {
    if (record.chatId == null || record.messageId?.isNotEmpty != true) return;
    Navigator.of(context).pop(record);
  }

  String _saveName(DownloadRecord record) {
    final name = record.name.trim();
    if (name.isNotEmpty) return p.basename(name);
    final extension = p.extension(record.cacheName);
    final stamp = record.downloadedAt > 0
        ? record.downloadedAt
        : DateTime.now().millisecondsSinceEpoch;
    return switch (record.kind) {
      DownloadKind.photo =>
        'IMG_$stamp${extension.isEmpty ? '.jpg' : extension}',
      DownloadKind.video =>
        'VID_$stamp${extension.isEmpty ? '.mp4' : extension}',
      DownloadKind.gif => 'GIF_$stamp${extension.isEmpty ? '.gif' : extension}',
      DownloadKind.audio =>
        'AUD_$stamp${extension.isEmpty ? '.ogg' : extension}',
      DownloadKind.file => p.basename(record.cacheName),
    };
  }

  Future<void> _settings() async {
    final l10n = AppLocalizations.of(context)!;
    final clear = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Center(
                child: SheetGrabber(margin: EdgeInsets.only(bottom: 12)),
              ),
              ListTile(
                leading: const Icon(
                  Symbols.delete_sweep,
                  color: Color(0xFFE53935),
                  size: 24,
                ),
                title: Text(
                  l10n.downloadsClearHistory,
                  style: const TextStyle(
                    color: Color(0xFFE53935),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.pop(sheetContext, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (clear != true || !mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.downloadsClearTitle,
      message: l10n.downloadsClearBody,
      confirmLabel: l10n.downloadsClearConfirm,
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await DownloadHistory.clear();
    if (mounted) showCustomNotification(context, l10n.downloadsHistoryCleared);
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF1A1A1A);
    const borderColor = Color(0xFFE2E5EB);
    const accentColor = Color(0xFF1E88E5);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back, color: textColor, size: 24),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          l10n.downloadsTitle,
          style: const TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('downloads-settings'),
            onPressed: _settings,
            style: TextButton.styleFrom(
              foregroundColor: accentColor,
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(l10n.downloadsSettings),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(
              child: SmallSpinner(size: 28, color: Color(0xFF2C3E50)),
            )
          : ValueListenableBuilder<List<DownloadRecord>>(
              valueListenable: DownloadHistory.records,
              builder: (context, records, _) {
                if (records.isEmpty) {
                  return _DownloadsEmpty(label: l10n.downloadsEmpty);
                }
                return ListView.separated(
                  key: const ValueKey('downloads-list'),
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: records.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 86,
                    color: borderColor.withValues(alpha: 0.7),
                  ),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return _DownloadTile(
                      record: record,
                      onTap: () => _open(record),
                      onSaveAs: () => _saveAs(record),
                      onGoToMessage: record.chatId != null &&
                              record.messageId?.isNotEmpty == true
                          ? () => _goToMessage(record)
                          : null,
                    );
                  },
                );
              },
            ),
    );
  }
}

class _DownloadsEmpty extends StatelessWidget {
  final String label;

  const _DownloadsEmpty({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Symbols.download,
                size: 40,
                color: Color(0xFF9E9E9E),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF757575),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadRecord record;
  final VoidCallback onTap;
  final VoidCallback onSaveAs;
  final VoidCallback? onGoToMessage;

  const _DownloadTile({
    required this.record,
    required this.onTap,
    required this.onSaveAs,
    required this.onGoToMessage,
  });

  void _openMenu(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final l10n = AppLocalizations.of(context)!;
    showChatMenu(
      context: context,
      anchorRect: box.localToGlobal(Offset.zero) & box.size,
      items: [
        if (onGoToMessage != null)
          ChatMenuItem(
            icon: Symbols.visibility,
            label: l10n.sharedGoToMessage,
            onTap: onGoToMessage,
          ),
        ChatMenuItem(
          icon: Symbols.download,
          label: l10n.photoViewerSaveAs,
          onTap: onSaveAs,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);
    final l10n = AppLocalizations.of(context)!;
    final source = record.sourceName.trim().isEmpty
        ? l10n.downloadsUnknownSource
        : record.sourceName.trim();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            _DownloadPreview(record: record),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title(l10n),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatBytes(record.size)} · $source',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: subtitleColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Builder(
              builder: (buttonContext) => IconButton(
                key: ValueKey('download-more-${record.cacheName}'),
                tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                icon: const Icon(Symbols.more_vert, color: subtitleColor, size: 20),
                onPressed: () => _openMenu(buttonContext),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _title(AppLocalizations l10n) {
    if (record.name.trim().isNotEmpty) return record.name.trim();
    return switch (record.kind) {
      DownloadKind.photo => l10n.downloadsPhoto,
      DownloadKind.video => l10n.downloadsVideo,
      DownloadKind.gif => l10n.downloadsGif,
      DownloadKind.audio => l10n.downloadsAudio,
      DownloadKind.file => l10n.downloadsFile,
    };
  }
}

class _DownloadPreview extends StatefulWidget {
  final DownloadRecord record;

  const _DownloadPreview({required this.record});

  @override
  State<_DownloadPreview> createState() => _DownloadPreviewState();
}

class _DownloadPreviewState extends State<_DownloadPreview> {
  late Future<File?> _file = DownloadHistory.fileFor(
    widget.record,
    touch: false,
  );

  @override
  void didUpdateWidget(_DownloadPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.cacheName != widget.record.cacheName) {
      _file = DownloadHistory.fileFor(widget.record, touch: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.record.thumbnailUrl;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E5EB),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: preview != null && preview.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: preview,
              fit: BoxFit.cover,
              memCacheWidth: 160,
              errorWidget: (_, _, _) => _fallback(),
            )
          : FutureBuilder<File?>(
              future: _file,
              builder: (context, snapshot) {
                final file = snapshot.data;
                if (file != null &&
                    (widget.record.kind == DownloadKind.photo ||
                        widget.record.kind == DownloadKind.gif)) {
                  return Image.file(
                    file,
                    fit: BoxFit.cover,
                    cacheWidth: 160,
                    errorBuilder: (_, _, _) => _fallback(),
                  );
                }
                return _fallback();
              },
            ),
    );
  }

  Widget _fallback() {
    final extension = p
        .extension(widget.record.name)
        .replaceFirst('.', '')
        .toUpperCase();
    final (color, icon) = switch (widget.record.kind) {
      DownloadKind.photo => (const Color(0xFF3CA95E), Symbols.image),
      DownloadKind.video => (const Color(0xFF4A8FE7), Symbols.movie),
      DownloadKind.gif => (const Color(0xFFE684AE), Symbols.gif_box),
      DownloadKind.audio => (const Color(0xFF8C68D8), Symbols.audio_file),
      DownloadKind.file => (const Color(0xFFF2B735), Symbols.description),
    };
    return ColoredBox(
      color: color,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          if (extension.isNotEmpty && widget.record.kind == DownloadKind.file)
            Positioned(
              bottom: 4,
              child: Text(
                extension.length > 5 ? extension.substring(0, 5) : extension,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
