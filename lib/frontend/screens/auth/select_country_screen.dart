import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flux/core/config/countries.dart';
import 'package:flux/l10n/app_localizations.dart';

class SelectCountryScreen extends StatefulWidget {
  final CountryName selectedCountry;
  final List<CountryName> countries;

  SelectCountryScreen({
    super.key,
    required this.selectedCountry,
    List<CountryName>? countries,
  }) : countries = countries ?? allCountries;

  @override
  State<SelectCountryScreen> createState() => _SelectCountryScreenState();
}

class _CountrySearchEntry {
  final CountryName country;
  final String ruLower;
  final String enLower;

  const _CountrySearchEntry(this.country, this.ruLower, this.enLower);
}

class _SelectCountryScreenState extends State<SelectCountryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<CountryName> _sortedCountries = const [];
  List<CountryName> _filteredCountries = const [];
  List<_CountrySearchEntry> _searchEntries = const [];
  String _lang = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == _lang) return;
    _lang = lang;
    _sortedCountries = sortedByDisplayName(widget.countries, lang);
    _searchEntries = _sortedCountries
        .map(
          (c) => _CountrySearchEntry(c, c.ru.toLowerCase(), c.en.toLowerCase()),
        )
        .toList();
    _filteredCountries = _applyFilter(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CountryName> _applyFilter(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _sortedCountries;
    final matches = _searchEntries
        .where(
          (e) =>
              e.ruLower.contains(q) ||
              e.enLower.contains(q) ||
              e.country.phoneCode.contains(q),
        )
        .map((e) => e.country)
        .toList();
    if (_looksLikePhoneCode(q)) {
      matches.sort((a, b) {
        final byPrimary =
            (isPrimaryForPhoneCode(b) ? 1 : 0) -
            (isPrimaryForPhoneCode(a) ? 1 : 0);
        if (byPrimary != 0) return byPrimary;
        return a
            .displayName(_lang)
            .toLowerCase()
            .compareTo(b.displayName(_lang).toLowerCase());
      });
    }
    return matches;
  }

  static bool _looksLikePhoneCode(String query) =>
      RegExp(r'^\+?\d+$').hasMatch(query);

  void _filterCountries(String query) {
    setState(() => _filteredCountries = _applyFilter(query));
  }

  String _countryFlag(String countryCode) {
    return countryCode.toUpperCase().runes.map((rune) {
      return String.fromCharCode(rune + 127397);
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF1A1A1A);
    const subtitleColor = Color(0xFF757575);
    const primaryColor = Color(0xFF2C3E50);
    const accentColor = Color(0xFF1E88E5);
    const borderColor = Color(0xFFD6D9E0);

    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Symbols.arrow_back, color: textColor),
        ),
        title: const Text(
          'flux',
          style: TextStyle(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Text(
                'ВЫБОР СТРАНЫ',
                style: const TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                itemCount: _filteredCountries.length,
                separatorBuilder: (_, __) => Divider(
                  color: borderColor.withValues(alpha: 0.4),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final country = _filteredCountries[index];
                  final isSelected = country.code == widget.selectedCountry.code;

                  return InkWell(
                    onTap: () => Navigator.pop(context, country),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      child: Row(
                        children: [
                          Text(
                            _countryFlag(country.code),
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              country.displayName(lang),
                              style: TextStyle(
                                color: isSelected ? accentColor : textColor,
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          Text(
                            country.phoneCode,
                            style: TextStyle(
                              color: isSelected ? accentColor : subtitleColor,
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Symbols.check,
                              color: accentColor,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: borderColor, width: 1.4),
                  color: const Color(0xFFF7F8FA),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Symbols.search, color: subtitleColor, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterCountries,
                        style: const TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'ПОИСК ПО СТРАНЕ',
                          hintStyle: TextStyle(
                            color: subtitleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          _filterCountries('');
                        },
                        child: const Icon(
                          Symbols.close,
                          color: subtitleColor,
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
