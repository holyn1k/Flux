import 'package:flutter/material.dart';
import 'package:m3e_collection/m3e_collection.dart'
    show ExpressiveRefreshIndicator;
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../backend/modules/digital_id.dart';
import '../../../core/utils/webview_support.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart' show digitalIdModule;
import '../../../models/digital_id.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/error_view.dart';
import '../../widgets/reload_on_reconnect.dart';
import '../../widgets/small_spinner.dart';

String _documentLabel(AppLocalizations l10n, String type) {
  return switch (type) {
    'passport' => l10n.digitalIdDocPassport,
    'oms' => l10n.digitalIdDocOms,
    'inn' => l10n.digitalIdInnLabel,
    'driver_license' => l10n.digitalIdDocDriverLicense,
    'vehicle_sts' => l10n.digitalIdDocVehicleSts,
    'snils' => l10n.digitalIdSnilsLabel,
    'child_birth_cert' => l10n.digitalIdDocChildBirthCert,
    'pension_cert' => l10n.digitalIdDocPensionCert,
    'disabled_cert' => l10n.digitalIdDocDisabledCert,
    'large_family_cert' => l10n.digitalIdDocLargeFamilyCert,
    'student_ticket' => l10n.digitalIdDocStudentTicket,
    'child_inn' => l10n.digitalIdDocChildInn,
    'child_oms' => l10n.digitalIdDocChildOms,
    _ => type,
  };
}

class DigitalIdScreen extends StatefulWidget {
  const DigitalIdScreen({super.key});

  @override
  State<DigitalIdScreen> createState() => _DigitalIdScreenState();
}

class _DigitalIdScreenState extends State<DigitalIdScreen>
    with ReloadOnReconnect {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _needsGosuslugi = false;
  DigitalIdUserDocs? _docs;
  DigitalIdBiometryStatus? _biometry;
  List<DigitalIdAcmsCard> _cards = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void reloadAfterReconnect() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _needsGosuslugi = false;
    });
    try {
      final biometry = await digitalIdModule.biometryStatus();
      DigitalIdUserDocs? docs;
      try {
        docs = await digitalIdModule.loadDocuments();
      } on DigitalIdException catch (e) {
        if (e.isNoGosuslugiLink) {
          if (mounted) setState(() => _needsGosuslugi = true);
        } else {
          rethrow;
        }
      }
      List<DigitalIdAcmsCard> cards;
      try {
        cards = await digitalIdModule.getCardsList(passStatus: 'active');
      } catch (_) {
        cards = const [];
      }
      if (!mounted) return;
      setState(() {
        _biometry = biometry;
        _docs = docs;
        _cards = cards;
        _loading = false;
      });
    } on DigitalIdException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _linkGosuslugi() async {
    if (_busy) return;
    if (!webViewSupported) {
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.digitalIdGosuslugiLinkUnavailable,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final link = await digitalIdModule.createEsiaLink();
      if (!mounted) return;
      if (link.url.isEmpty) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.digitalIdGosuslugiLinkFailed,
        );
        return;
      }
      // Госуслуги (ЕСИА) открываем во ВНЕШНЕМ браузере — их антифрод режет
      // встроенный webview. Возврат придёт диплинком max.ru?externalCallback=1
      // (deep_link_service -> опкод 105), после чего экран перезагрузится.
      final uri = Uri.tryParse(link.url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } on DigitalIdException catch (e) {
      if (mounted) showCustomNotification(context, e.message);
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.devicesGenericError(e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadDocsExplicit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final docs = await digitalIdModule.loadDocuments(createIfMissing: true);
      if (!mounted) return;
      if (docs != null) {
        setState(() => _docs = docs);
      } else {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.digitalIdDocsUnavailable,
        );
      }
    } on DigitalIdException catch (e) {
      if (!mounted) return;
      if (e.isNoGosuslugiLink) setState(() => _needsGosuslugi = true);
      showCustomNotification(context, e.message);
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.devicesGenericError(e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF1A1A1A);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: const ConnectionSpinner(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          l10n.digitalIdTitle,
          style: const TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.refresh, color: textColor),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: SmallSpinner(size: 36));
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_docs == null) {
      return _buildOnboarding();
    }
    return ExpressiveRefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ..._buildProfile(_docs!),
          if (_cards.isNotEmpty) ..._buildCards(),
          const SizedBox(height: 16),
          _buildBiometryInfo(),
        ],
      ),
    );
  }

  Widget _buildOnboarding() {
    final l10n = AppLocalizations.of(context)!;
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);
    const primaryColor = Color(0xFF2C3E50);
    const accentColor = Color(0xFF1E88E5);
    const borderColor = Color(0xFFD6D9E0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F7FA),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFDDE6ED),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Symbols.badge,
                          size: 52,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.digitalIdNotConfiguredTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _needsGosuslugi
                            ? l10n.digitalIdLinkGosuslugiHint
                            : l10n.digitalIdLinkOrRefreshHint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: borderColor, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _busy ? null : _loadDocsExplicit,
                      icon: const Icon(Symbols.sync, size: 18, color: textColor),
                      label: Text(
                        l10n.digitalIdLoadDocuments,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        disabledBackgroundColor: const Color(0xFFE2E5EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _busy ? null : _linkGosuslugi,
                      icon: _busy
                          ? const SmallSpinner(size: 18, color: Colors.white)
                          : const Icon(Symbols.link, size: 18, color: Colors.white),
                      label: Text(
                        l10n.digitalIdLinkGosuslugiButton,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBiometryInfo(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProfile(DigitalIdUserDocs docs) {
    final l10n = AppLocalizations.of(context)!;
    final profile = docs.profile;
    const primaryColor = Color(0xFF2C3E50);
    const borderColor = Color(0xFFE2E5EB);

    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Symbols.verified_user,
              size: 36,
              color: primaryColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.fullName.isEmpty
                        ? l10n.digitalIdGosuslugiProfileFallback
                        : profile.fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (profile.birthDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        l10n.digitalIdBirthDate(profile.birthDate!),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF757575),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _buildInfoSection(l10n.digitalIdPersonalDataTitle, [
        if (profile.snils != null) (l10n.digitalIdSnilsLabel, profile.snils!),
        if (profile.inn != null) (l10n.digitalIdInnLabel, profile.inn!),
        if (profile.gender != null)
          (l10n.contactProfileInfoGender, profile.gender!),
        if (profile.birthPlace != null)
          (l10n.digitalIdBirthPlaceLabel, profile.birthPlace!),
        if (profile.registrationAddress != null)
          (
            l10n.digitalIdRegistrationAddressLabel,
            profile.registrationAddress!.formatted,
          ),
      ]),
      if (profile.documents.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(
          l10n.digitalIdDocumentsTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 10),
        ...profile.documents.map(_buildDocumentTile),
      ],
    ];
  }

  Widget _buildInfoSection(
    String title,
    List<(String, String)> rows,
  ) {
    if (rows.isEmpty) return const SizedBox.shrink();
    const borderColor = Color(0xFFE2E5EB);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF757575),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      row.$1,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF757575),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTile(DigitalIdDocument doc) {
    final l10n = AppLocalizations.of(context)!;
    final label = _documentLabel(l10n, doc.type);
    final subtitleParts = <String>[
      if (doc.series != null) l10n.digitalIdDocSeries(doc.series!),
      if (doc.number != null) l10n.digitalIdDocNumber(doc.number!),
    ];
    const primaryColor = Color(0xFF2C3E50);
    const borderColor = Color(0xFFE2E5EB);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Symbols.description, color: primaryColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (subtitleParts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitleParts.join(', '),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCards() {
    final l10n = AppLocalizations.of(context)!;
    const primaryColor = Color(0xFF2C3E50);
    const borderColor = Color(0xFFE2E5EB);

    return [
      const SizedBox(height: 20),
      Text(
        l10n.digitalIdPassesTitle,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
        ),
      ),
      const SizedBox(height: 10),
      ..._cards.map(
        (card) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Symbols.badge, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.companyName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        l10n.digitalIdCardInn(card.inn),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF757575),
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
    ];
  }

  Widget _buildBiometryInfo() {
    final biometry = _biometry;
    if (biometry == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Icon(
          biometry.hasBiometryToken ? Symbols.check_circle : Symbols.info,
          size: 18,
          color: const Color(0xFF757575),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            biometry.hasBiometryToken
                ? l10n.digitalIdBiometryConfigured
                : l10n.digitalIdBiometryNotConfigured,
            style: const TextStyle(fontSize: 13, color: Color(0xFF757575)),
          ),
        ),
      ],
    );
  }
}
