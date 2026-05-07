import 'dart:convert';

import 'package:flutter/services.dart';

class Gen3PersonalData {
  const Gen3PersonalData._(this._species);

  final Map<int, Gen3PersonalInfo> _species;

  static Future<Gen3PersonalData> load() async {
    final raw = await rootBundle.loadString(
      'assets/data/gen3/personal_rsefrlg.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return Gen3PersonalData.fromJson(json);
  }

  factory Gen3PersonalData.fromJson(Map<String, dynamic> json) {
    final species = (json['species'] as Map<String, dynamic>).map((key, value) {
      return MapEntry(
        int.parse(key),
        Gen3PersonalInfo.fromJson(value as Map<String, dynamic>),
      );
    });
    return Gen3PersonalData._(species);
  }

  Gen3PersonalInfo? operator [](int speciesId) => _species[speciesId];
}

class Gen3PersonalInfo {
  const Gen3PersonalInfo({
    required this.typeIds,
    required this.abilityIds,
    required this.genderRatio,
  });

  factory Gen3PersonalInfo.fromJson(Map<String, dynamic> json) {
    return Gen3PersonalInfo(
      typeIds: (json['typeIds'] as List<dynamic>).cast<int>(),
      abilityIds: (json['abilityIds'] as List<dynamic>).cast<int>(),
      genderRatio: json['genderRatio'] as int,
    );
  }

  final List<int> typeIds;
  final List<int> abilityIds;
  final int genderRatio;

  List<int> get distinctAbilityIds {
    return abilityIds.toSet().toList(growable: false);
  }
}
