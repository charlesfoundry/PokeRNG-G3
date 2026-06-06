import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/gen3/gen3.dart';

class Gen3NamedResources {
  const Gen3NamedResources._({
    required this.species,
    required this.englishSpecies,
    required this.abilities,
    required this.natures,
  });

  final Map<int, String> species;
  final Map<int, String> englishSpecies;
  final Map<int, String> abilities;
  final Map<int, String> natures;

  static Future<Gen3NamedResources> load(String localeName) async {
    final locale = _assetLocale(localeName);
    final species = await _loadNames('species', locale);
    final englishSpecies = locale == 'en'
        ? species
        : await _loadNames('species', 'en');
    return Gen3NamedResources._(
      species: species,
      englishSpecies: englishSpecies,
      abilities: await _loadNames('abilities', locale),
      natures: await _loadNames('natures', locale),
    );
  }

  static Future<Gen3NamedResources> loadAssetLocale(String locale) async {
    final species = await _loadNames('species', locale);
    final englishSpecies = locale == 'en'
        ? species
        : await _loadNames('species', 'en');
    return Gen3NamedResources._(
      species: species,
      englishSpecies: englishSpecies,
      abilities: await _loadNames('abilities', locale),
      natures: await _loadNames('natures', locale),
    );
  }

  String speciesName(int speciesId) {
    return species[speciesId] ?? englishSpecies[speciesId] ?? '#$speciesId';
  }

  String speciesSearchText(int speciesId) {
    return '${species[speciesId] ?? ''} ${englishSpecies[speciesId] ?? ''}'
        .toLowerCase();
  }

  String abilityName(int abilityId) {
    return abilities[abilityId] ?? 'Ability $abilityId';
  }

  String natureName(Nature nature) {
    return natures[nature.index] ?? nature.name;
  }
}

Future<Map<int, String>> _loadNames(String kind, String locale) async {
  final raw = await rootBundle.loadString(
    'assets/i18n/gen3/${kind}_$locale.json',
  );
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final names = json[kind] as Map<String, dynamic>;
  return names.map((key, value) => MapEntry(int.parse(key), value as String));
}

String _assetLocale(String localeName) {
  return switch (localeName) {
    'zh' || 'zh_CN' || 'zh_Hans' || 'zh_Hans_CN' => 'zh_Hans',
    'ja' || 'ja_JP' => 'ja',
    _ => 'en',
  };
}
