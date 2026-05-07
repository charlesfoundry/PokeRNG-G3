// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PokeRNG G3';

  @override
  String get hunt => 'Hunt';

  @override
  String get calibrate => 'Calibrate';

  @override
  String get tools => 'Tools';

  @override
  String get settings => 'Settings';

  @override
  String get target => 'Target';

  @override
  String get encounter => 'Encounter';

  @override
  String get search => 'Search';

  @override
  String get searching => 'Searching...';

  @override
  String get cancelSearch => 'Cancel search';

  @override
  String get attempt => 'Attempt';

  @override
  String get pokemon => 'Pokemon';

  @override
  String get pokemonSearchLimitHint =>
      'Type a Pokemon number to browse from that number, or enter a name keyword. Up to 50 suggestions are shown.';

  @override
  String get shiny => 'Shiny';

  @override
  String get nature => 'Nature';

  @override
  String get minimumIv => 'Minimum IV';

  @override
  String get seed => 'Seed';

  @override
  String get initialAdvance => 'Initial';

  @override
  String get maxAdvance => 'Max';

  @override
  String get delay => 'Delay';

  @override
  String get results => 'Results';

  @override
  String get selectAResult => 'Select a result';

  @override
  String get gameVersion => 'Game version';

  @override
  String get defaultSeed => 'Default seed';

  @override
  String get save => 'Save';

  @override
  String get observedNature => 'Observed nature';

  @override
  String get observedIvs => 'Observed IVs';

  @override
  String get idSid => 'ID/SID';

  @override
  String get ivsToPid => 'IVs to PID';

  @override
  String get battleVideo => 'Battle Video';

  @override
  String get painting => 'Painting';

  @override
  String get locationEgg => 'Location / Egg';

  @override
  String get egg => 'Egg';

  @override
  String get eggUnsupported => 'Egg (later)';

  @override
  String get method => 'Method';

  @override
  String get wildMethod1 => 'Wild 1';

  @override
  String get wildMethod2 => 'Wild 2';

  @override
  String get wildMethod4 => 'Wild 4';

  @override
  String get staticMethod1 => 'Method 1';

  @override
  String get staticMethod2 => 'Method 2';

  @override
  String get staticMethod4 => 'Method 4';

  @override
  String get ability => 'Ability';

  @override
  String get gender => 'Gender';

  @override
  String get any => 'Any';

  @override
  String get slot => 'Slot';

  @override
  String get lead => 'Lead';

  @override
  String get leadNone => 'None';

  @override
  String get leadPressure => 'Pressure';

  @override
  String get leadSynchronize => 'Synchronize';

  @override
  String get leadStatic => 'Static';

  @override
  String get leadMagnetPull => 'Magnet Pull';

  @override
  String get leadCuteCharmFemale => 'Cute Charm ♀';

  @override
  String get leadCuteCharmMale => 'Cute Charm ♂';

  @override
  String get syncNature => 'Sync nature';

  @override
  String get feebasTile => 'Feebas tile';

  @override
  String get ivAnyNote => '-1 = Any IV';

  @override
  String searchRangeNote(Object maxAdvanceDelta, Object maxResults) {
    return 'Max - Initial <= $maxAdvanceDelta advances · results <= $maxResults';
  }

  @override
  String resultLimitNote(Object maxResults) {
    return 'Showing first $maxResults matches. Narrow filters or lower range to inspect later matches.';
  }

  @override
  String get selectPokemonEncounterLocationError =>
      'Select a Pokemon, encounter method, and location.';

  @override
  String huntInputError(Object maxAdvanceDelta) {
    return 'Check seed, advances, delay, and IV filter. Max - Initial must be <= $maxAdvanceDelta.';
  }

  @override
  String get runHuntAndEnterObservedIvsError =>
      'Run a hunt search and enter observed IVs.';

  @override
  String get noMatchingAdvanceError =>
      'No matching advance in the current search range.';

  @override
  String get noResults => 'No results. Loosen filters or increase Max Advance.';

  @override
  String get searchCancelled => 'Search cancelled.';

  @override
  String get settingsInputError => 'Check TID, SID, and seed.';

  @override
  String targetAdvance(Object advance) {
    return 'Target $advance';
  }

  @override
  String hitAdvance(Object advance) {
    return 'Hit $advance';
  }

  @override
  String deltaValue(Object delta) {
    return 'Delta $delta';
  }

  @override
  String delayValue(Object delay) {
    return 'Delay $delay';
  }

  @override
  String get encounterGrass => 'Grass';

  @override
  String get encounterSurfing => 'Surfing';

  @override
  String get encounterRockSmash => 'Rock Smash';

  @override
  String get encounterOldRod => 'Old Rod';

  @override
  String get encounterGoodRod => 'Good Rod';

  @override
  String get encounterSuperRod => 'Super Rod';

  @override
  String get staticStarter => 'Starter';

  @override
  String get staticFossil => 'Fossil';

  @override
  String get staticGift => 'Gift';

  @override
  String get staticGameCorner => 'Game Corner';

  @override
  String get staticStationary => 'Stationary';

  @override
  String get staticLegend => 'Legend';

  @override
  String get staticEvent => 'Event';

  @override
  String get staticRoamer => 'Roamer';

  @override
  String abilitySlot(Object slot, Object name) {
    return 'Ability $slot - $name';
  }

  @override
  String get statAttack => 'Atk';

  @override
  String get statDefense => 'Def';

  @override
  String get statSpeed => 'Spe';

  @override
  String get statSpecialAttack => 'SpA';

  @override
  String get statSpecialDefense => 'SpD';

  @override
  String get natureNeutral => 'Neutral';

  @override
  String failedLoadTargetData(Object error) {
    return 'Failed to load target data: $error';
  }

  @override
  String get resultAdvance => 'Adv';

  @override
  String get resultPress => 'Press';

  @override
  String get levelShort => 'Lv';

  @override
  String get hiddenPower => 'HPower';

  @override
  String get sendToCalibration => 'Send to calibration';

  @override
  String get saveTarget => 'Save target';

  @override
  String get targetSaved => 'Target saved';

  @override
  String get savedTargets => 'Saved targets';

  @override
  String get noSavedTargets =>
      'Long-press or right-click a wild result to save a target.';

  @override
  String get deleteTarget => 'Delete target';

  @override
  String get calibrationTarget => 'Calibration target';

  @override
  String get noCalibrationTarget =>
      'Long-press or right-click a wild result, then send it to calibration.';

  @override
  String get currentTargetAdvance => 'Current target Adv';

  @override
  String get actualAdvance => 'Actual Adv';

  @override
  String get calibrationOutput => 'Output';

  @override
  String get targetDelta => 'Total deviation';

  @override
  String get calculateNextPress => 'Calculate next target Adv';

  @override
  String get observedPokemon => 'Observed Pokemon';

  @override
  String get observedStats => 'Stats';

  @override
  String get reverseHitAdvance => 'Reverse hit frame';

  @override
  String get reverseResults => 'Reverse results';

  @override
  String get calibrationFrameInputError => 'Check target Adv and actual Adv.';

  @override
  String get runHuntAndEnterObservedStatsError =>
      'Send a target from results and enter observed stats.';

  @override
  String actualAdvanceOutput(Object advance) {
    return 'Actual Adv $advance';
  }

  @override
  String nextTargetAdvanceOutput(Object advance, Object delta) {
    return '$advance · Delta $delta';
  }

  @override
  String targetDeltaOutput(Object delta) {
    return 'Delta $delta';
  }

  @override
  String get typeFighting => 'fighting';

  @override
  String get typeFlying => 'flying';

  @override
  String get typePoison => 'poison';

  @override
  String get typeGround => 'ground';

  @override
  String get typeRock => 'rock';

  @override
  String get typeBug => 'bug';

  @override
  String get typeGhost => 'ghost';

  @override
  String get typeSteel => 'steel';

  @override
  String get typeFire => 'fire';

  @override
  String get typeWater => 'water';

  @override
  String get typeGrass => 'grass';

  @override
  String get typeElectric => 'electric';

  @override
  String get typePsychic => 'psychic';

  @override
  String get typeIce => 'ice';

  @override
  String get typeDragon => 'dragon';

  @override
  String get typeDark => 'dark';
}
