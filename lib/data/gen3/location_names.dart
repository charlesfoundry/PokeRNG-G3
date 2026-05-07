import 'dart:convert';

import 'package:flutter/services.dart';

import '../../app/profile.dart';

class Gen3LocationNames {
  const Gen3LocationNames._(
    this._names,
    this._englishToLocalizedNames,
    this._staticLocationNames,
  );

  final Map<String, String> _names;
  final Map<String, String> _englishToLocalizedNames;
  final Map<String, String> _staticLocationNames;

  static Future<Gen3LocationNames> load(String localeName) async {
    final assetLocale = switch (localeName) {
      'zh' || 'zh_CN' || 'zh_Hans' || 'zh_Hans_CN' => 'zh_Hans',
      'ja' || 'ja_JP' => 'ja',
      _ => 'en',
    };
    final raw = await rootBundle.loadString(
      'assets/i18n/gen3/locations_$assetLocale.json',
    );
    final englishRaw = await rootBundle.loadString(
      'assets/i18n/gen3/locations_en.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final englishJson = jsonDecode(englishRaw) as Map<String, dynamic>;
    final locations = (json['locations'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as String),
    );
    final englishLocations = (englishJson['locations'] as Map<String, dynamic>)
        .map((key, value) => MapEntry(key, value as String));
    return Gen3LocationNames._(
      locations,
      _buildEnglishToLocalizedNames(
        englishLocations: englishLocations,
        localizedLocations: locations,
      ),
      _staticLocationNamesFor(assetLocale),
    );
  }

  String name({
    required GameVersion game,
    required int locationId,
    required String fallback,
  }) {
    return _names['${game.jsonName}:$locationId'] ?? fallback;
  }

  String staticLocationName(String englishName) {
    return _staticLocationNames[englishName] ??
        _englishToLocalizedNames[englishName] ??
        _localizedBaseLocationName(englishName) ??
        englishName;
  }

  String? _localizedBaseLocationName(String englishName) {
    for (final entry in _englishToLocalizedNames.entries) {
      if (entry.key.startsWith('$englishName ')) {
        return _stripFloorSuffix(entry.value);
      }
    }
    return null;
  }
}

Map<String, String> _buildEnglishToLocalizedNames({
  required Map<String, String> englishLocations,
  required Map<String, String> localizedLocations,
}) {
  final result = <String, String>{};
  for (final entry in englishLocations.entries) {
    final localized = localizedLocations[entry.key];
    if (localized != null) {
      result[entry.value] = localized;
      result[_stripFloorSuffix(entry.value)] = _stripFloorSuffix(localized);
    }
  }
  return result;
}

String _stripFloorSuffix(String value) {
  return value.replaceFirst(
    RegExp(r'\s?(?:[1-9]F|B[1-9]F|Basement|Exterior)$'),
    '',
  );
}

Map<String, String> _staticLocationNamesFor(String locale) {
  return switch (locale) {
    'zh_Hans' => const {
      'Battle Frontier': '对战开拓区',
      'Berry Forest': '果实森林',
      'Birth Islands': '诞生之岛',
      'Cave of Origin': '觉醒神殿',
      'Desert Ruins': '沙漠遗迹',
      'Faraway Island': '边境的小岛',
      'Magma/Aqua Hideout': '熔岩队/海洋队基地',
      'Marine Cave': '海之窟',
      'Mt. Ember': '灯火山',
      'Navel Rock': '肚脐岩',
      'New Mauville': '新紫堇',
      'Rustboro City': '卡那兹市',
      'Silph Co.': '西尔佛公司',
      'Southern Island': '南方孤岛',
      'Terra Cave': '陆之窟',
      'Weather Institute': '天气研究所',
    },
    'ja' => const {
      'Battle Frontier': 'バトルフロンティア',
      'Berry Forest': 'きのみのもり',
      'Birth Islands': 'たんじょうのしま',
      'Cave of Origin': 'めざめのほこら',
      'Desert Ruins': 'さばくいせき',
      'Faraway Island': 'さいはてのことう',
      'Magma/Aqua Hideout': 'マグマだん/アクアだんアジト',
      'Marine Cave': 'うみのどうくつ',
      'Mt. Ember': 'ともしびやま',
      'Navel Rock': 'へそのいわ',
      'New Mauville': 'ニューキンセツ',
      'Power Plant': 'むじんはつでんしょ',
      'Rustboro City': 'カナズミシティ',
      'Seafoam Islands': 'ふたごじま',
      'Silph Co.': 'シルフカンパニー',
      'Sky Pillar': 'そらのはしら',
      'Southern Island': 'みなみのことう',
      'Terra Cave': 'りくのどうくつ',
      'Weather Institute': 'てんきけんきゅうじょ',
    },
    _ => const {},
  };
}
