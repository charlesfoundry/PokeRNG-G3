import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PokeRNG G3'**
  String get appTitle;

  /// No description provided for @hunt.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get hunt;

  /// No description provided for @calibrate.
  ///
  /// In en, this message translates to:
  /// **'Calibrate'**
  String get calibrate;

  /// No description provided for @breeding.
  ///
  /// In en, this message translates to:
  /// **'Eggs'**
  String get breeding;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// No description provided for @encounter.
  ///
  /// In en, this message translates to:
  /// **'Encounter'**
  String get encounter;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get searching;

  /// No description provided for @cancelSearch.
  ///
  /// In en, this message translates to:
  /// **'Cancel search'**
  String get cancelSearch;

  /// No description provided for @resetDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset defaults'**
  String get resetDefaults;

  /// No description provided for @attempt.
  ///
  /// In en, this message translates to:
  /// **'Attempt'**
  String get attempt;

  /// No description provided for @pokemon.
  ///
  /// In en, this message translates to:
  /// **'Pokemon'**
  String get pokemon;

  /// No description provided for @pokemonSearchLimitHint.
  ///
  /// In en, this message translates to:
  /// **'Type a Pokemon number to browse from that number, or enter a name keyword. Up to 50 suggestions are shown.'**
  String get pokemonSearchLimitHint;

  /// No description provided for @shiny.
  ///
  /// In en, this message translates to:
  /// **'Shiny'**
  String get shiny;

  /// No description provided for @nature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get nature;

  /// No description provided for @minimumIv.
  ///
  /// In en, this message translates to:
  /// **'Minimum IV'**
  String get minimumIv;

  /// No description provided for @seed.
  ///
  /// In en, this message translates to:
  /// **'Seed'**
  String get seed;

  /// No description provided for @initialAdvance.
  ///
  /// In en, this message translates to:
  /// **'Initial'**
  String get initialAdvance;

  /// No description provided for @maxAdvance.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get maxAdvance;

  /// No description provided for @delay.
  ///
  /// In en, this message translates to:
  /// **'Delay'**
  String get delay;

  /// No description provided for @results.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get results;

  /// No description provided for @selectAResult.
  ///
  /// In en, this message translates to:
  /// **'Select a result'**
  String get selectAResult;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageChineseSimplified.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChineseSimplified;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageJapanese.
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get languageJapanese;

  /// No description provided for @gameVersion.
  ///
  /// In en, this message translates to:
  /// **'Game version'**
  String get gameVersion;

  /// No description provided for @defaultSeed.
  ///
  /// In en, this message translates to:
  /// **'Default seed'**
  String get defaultSeed;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @observedNature.
  ///
  /// In en, this message translates to:
  /// **'Observed nature'**
  String get observedNature;

  /// No description provided for @observedIvs.
  ///
  /// In en, this message translates to:
  /// **'Observed IVs'**
  String get observedIvs;

  /// No description provided for @locationEgg.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationEgg;

  /// No description provided for @breedingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Egg RNG is not implemented yet.'**
  String get breedingUnavailable;

  /// No description provided for @eggHeldStage.
  ///
  /// In en, this message translates to:
  /// **'Held egg'**
  String get eggHeldStage;

  /// No description provided for @eggPickupStage.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get eggPickupStage;

  /// No description provided for @eggHeldStageHelpEmerald.
  ///
  /// In en, this message translates to:
  /// **'Stage where the daycare man has an egg; determines PID, nature, gender, and shininess.'**
  String get eggHeldStageHelpEmerald;

  /// No description provided for @eggPickupStageHelpEmerald.
  ///
  /// In en, this message translates to:
  /// **'Stage where you press A to receive the egg; determines IVs and inheritance.'**
  String get eggPickupStageHelpEmerald;

  /// No description provided for @eggHeldStageHelpFrlg.
  ///
  /// In en, this message translates to:
  /// **'Stage where the daycare man has an egg; determines the low 16 bits of PID.'**
  String get eggHeldStageHelpFrlg;

  /// No description provided for @eggPickupStageHelpFrlg.
  ///
  /// In en, this message translates to:
  /// **'Stage where you press A to receive the egg; determines the high 16 bits of PID, IVs, and inheritance.'**
  String get eggPickupStageHelpFrlg;

  /// No description provided for @parentA.
  ///
  /// In en, this message translates to:
  /// **'Parent 1'**
  String get parentA;

  /// No description provided for @parentB.
  ///
  /// In en, this message translates to:
  /// **'Parent 2'**
  String get parentB;

  /// No description provided for @parentAShort.
  ///
  /// In en, this message translates to:
  /// **'P1'**
  String get parentAShort;

  /// No description provided for @parentBShort.
  ///
  /// In en, this message translates to:
  /// **'P2'**
  String get parentBShort;

  /// No description provided for @parentGender.
  ///
  /// In en, this message translates to:
  /// **'Parent gender'**
  String get parentGender;

  /// No description provided for @parentItem.
  ///
  /// In en, this message translates to:
  /// **'Held item'**
  String get parentItem;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @everstone.
  ///
  /// In en, this message translates to:
  /// **'Everstone'**
  String get everstone;

  /// No description provided for @ditto.
  ///
  /// In en, this message translates to:
  /// **'Ditto'**
  String get ditto;

  /// No description provided for @compatibility.
  ///
  /// In en, this message translates to:
  /// **'Compatibility'**
  String get compatibility;

  /// No description provided for @calibration.
  ///
  /// In en, this message translates to:
  /// **'Calibration'**
  String get calibration;

  /// No description provided for @minRedraws.
  ///
  /// In en, this message translates to:
  /// **'Min redraws'**
  String get minRedraws;

  /// No description provided for @maxRedraws.
  ///
  /// In en, this message translates to:
  /// **'Max redraws'**
  String get maxRedraws;

  /// No description provided for @redraws.
  ///
  /// In en, this message translates to:
  /// **'Redraws'**
  String get redraws;

  /// No description provided for @eggRedrawHelp.
  ///
  /// In en, this message translates to:
  /// **'Pokedex redraws advance the Emerald egg PID.'**
  String get eggRedrawHelp;

  /// No description provided for @eggSearchRangeNote.
  ///
  /// In en, this message translates to:
  /// **'Max - Initial <= {maxAdvanceDelta} for each stage · results <= {maxResults} · both stage ranges are combined'**
  String eggSearchRangeNote(Object maxAdvanceDelta, Object maxResults);

  /// No description provided for @eggSearchCostEstimate.
  ///
  /// In en, this message translates to:
  /// **'Current maximum combinations: {count} (held × pickup × redraws)'**
  String eggSearchCostEstimate(Object count);

  /// No description provided for @eggSearchCostEstimateFrlg.
  ///
  /// In en, this message translates to:
  /// **'Current maximum combinations: {count} (held × pickup)'**
  String eggSearchCostEstimateFrlg(Object count);

  /// No description provided for @eggLargeSearchWarning.
  ///
  /// In en, this message translates to:
  /// **'Large combination count. Shiny or strict filters can take longer; narrow the range first to verify.'**
  String get eggLargeSearchWarning;

  /// No description provided for @inheritance.
  ///
  /// In en, this message translates to:
  /// **'Inheritance'**
  String get inheritance;

  /// No description provided for @inheritRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get inheritRandom;

  /// No description provided for @eggInputError.
  ///
  /// In en, this message translates to:
  /// **'Check Pokemon, seed, both advance ranges, calibration, redraws, and parent IVs. Max - Initial must be <= {maxAdvanceDelta} for each stage.'**
  String eggInputError(Object maxAdvanceDelta);

  /// No description provided for @method.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get method;

  /// No description provided for @wildMethod1.
  ///
  /// In en, this message translates to:
  /// **'Wild 1'**
  String get wildMethod1;

  /// No description provided for @wildMethod2.
  ///
  /// In en, this message translates to:
  /// **'Wild 2'**
  String get wildMethod2;

  /// No description provided for @wildMethod4.
  ///
  /// In en, this message translates to:
  /// **'Wild 4'**
  String get wildMethod4;

  /// No description provided for @staticMethod1.
  ///
  /// In en, this message translates to:
  /// **'Method 1'**
  String get staticMethod1;

  /// No description provided for @staticMethod2.
  ///
  /// In en, this message translates to:
  /// **'Method 2'**
  String get staticMethod2;

  /// No description provided for @staticMethod4.
  ///
  /// In en, this message translates to:
  /// **'Method 4'**
  String get staticMethod4;

  /// No description provided for @wildMethodHintEmerald.
  ///
  /// In en, this message translates to:
  /// **'Emerald wild encounters usually use Wild 2; calibration reverse search checks Wild 1/2/4.'**
  String get wildMethodHintEmerald;

  /// No description provided for @wildMethodHintFrlg.
  ///
  /// In en, this message translates to:
  /// **'FireRed/LeafGreen wild encounters usually use Wild 1; other methods are rarer.'**
  String get wildMethodHintFrlg;

  /// No description provided for @staticMethodHint.
  ///
  /// In en, this message translates to:
  /// **'Stationary, gift, and other fixed Pokemon usually use Method 1.'**
  String get staticMethodHint;

  /// No description provided for @leadHintEmerald.
  ///
  /// In en, this message translates to:
  /// **'Emerald wild encounters support Synchronize, Pressure, Static, Magnet Pull, and Cute Charm lead effects when applicable.'**
  String get leadHintEmerald;

  /// No description provided for @leadHintFrlg.
  ///
  /// In en, this message translates to:
  /// **'FireRed/LeafGreen have no lead overworld effects; these Abilities do not change encounter results.'**
  String get leadHintFrlg;

  /// No description provided for @leadHintStatic.
  ///
  /// In en, this message translates to:
  /// **'Lead overworld effects only apply to wild encounters; stationary and gift Pokemon are not affected.'**
  String get leadHintStatic;

  /// No description provided for @ability.
  ///
  /// In en, this message translates to:
  /// **'Ability'**
  String get ability;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @any.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get any;

  /// No description provided for @slot.
  ///
  /// In en, this message translates to:
  /// **'Slot'**
  String get slot;

  /// No description provided for @lead.
  ///
  /// In en, this message translates to:
  /// **'Lead'**
  String get lead;

  /// No description provided for @leadNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get leadNone;

  /// No description provided for @leadPressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get leadPressure;

  /// No description provided for @leadSynchronize.
  ///
  /// In en, this message translates to:
  /// **'Synchronize'**
  String get leadSynchronize;

  /// No description provided for @leadStatic.
  ///
  /// In en, this message translates to:
  /// **'Static'**
  String get leadStatic;

  /// No description provided for @leadMagnetPull.
  ///
  /// In en, this message translates to:
  /// **'Magnet Pull'**
  String get leadMagnetPull;

  /// No description provided for @leadCuteCharmFemale.
  ///
  /// In en, this message translates to:
  /// **'Cute Charm ♀'**
  String get leadCuteCharmFemale;

  /// No description provided for @leadCuteCharmMale.
  ///
  /// In en, this message translates to:
  /// **'Cute Charm ♂'**
  String get leadCuteCharmMale;

  /// No description provided for @syncNature.
  ///
  /// In en, this message translates to:
  /// **'Sync nature'**
  String get syncNature;

  /// No description provided for @feebasTile.
  ///
  /// In en, this message translates to:
  /// **'Feebas tile'**
  String get feebasTile;

  /// No description provided for @ivAnyNote.
  ///
  /// In en, this message translates to:
  /// **'Empty or -1 = Any IV'**
  String get ivAnyNote;

  /// No description provided for @searchRangeNote.
  ///
  /// In en, this message translates to:
  /// **'Max - Initial <= {maxAdvanceDelta} advances · results <= {maxResults}'**
  String searchRangeNote(Object maxAdvanceDelta, Object maxResults);

  /// No description provided for @resultLimitNote.
  ///
  /// In en, this message translates to:
  /// **'Showing first {maxResults} matches. Narrow filters or lower range to inspect later matches.'**
  String resultLimitNote(Object maxResults);

  /// No description provided for @selectPokemonEncounterLocationError.
  ///
  /// In en, this message translates to:
  /// **'Select a Pokemon, encounter method, and location.'**
  String get selectPokemonEncounterLocationError;

  /// No description provided for @huntInputError.
  ///
  /// In en, this message translates to:
  /// **'Check seed, advances, delay, and IV filter. Max - Initial must be <= {maxAdvanceDelta}.'**
  String huntInputError(Object maxAdvanceDelta);

  /// No description provided for @runHuntAndEnterObservedIvsError.
  ///
  /// In en, this message translates to:
  /// **'Run a hunt search and enter observed IVs.'**
  String get runHuntAndEnterObservedIvsError;

  /// No description provided for @noMatchingAdvanceError.
  ///
  /// In en, this message translates to:
  /// **'No matching advance in the current search range.'**
  String get noMatchingAdvanceError;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results. Loosen filters or increase Max Advance.'**
  String get noResults;

  /// No description provided for @searchCancelled.
  ///
  /// In en, this message translates to:
  /// **'Search cancelled.'**
  String get searchCancelled;

  /// No description provided for @settingsInputError.
  ///
  /// In en, this message translates to:
  /// **'Check TID, SID, and seed.'**
  String get settingsInputError;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @project.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get project;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @credits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get credits;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'A multi-platform RNG tool for Gen 3 FireRed, LeafGreen, and Emerald.'**
  String get aboutDescription;

  /// No description provided for @unofficialNotice.
  ///
  /// In en, this message translates to:
  /// **'Unofficial fan-made RNG utility.'**
  String get unofficialNotice;

  /// No description provided for @aboutCredits.
  ///
  /// In en, this message translates to:
  /// **'References PokeFinder, EonTimer, and PokemonRNG community research.'**
  String get aboutCredits;

  /// No description provided for @copyProjectUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy project URL'**
  String get copyProjectUrl;

  /// No description provided for @projectUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'Project URL copied'**
  String get projectUrlCopied;

  /// No description provided for @supportDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Support developer'**
  String get supportDeveloper;

  /// No description provided for @supportDescription.
  ///
  /// In en, this message translates to:
  /// **'Optional in-app purchases can support ongoing development.'**
  String get supportDescription;

  /// No description provided for @supportNoUnlock.
  ///
  /// In en, this message translates to:
  /// **'Purchases do not unlock extra features.'**
  String get supportNoUnlock;

  /// No description provided for @supportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Support purchases are unavailable.'**
  String get supportUnavailable;

  /// No description provided for @supportThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your support.'**
  String get supportThanks;

  /// No description provided for @supportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Purchase cancelled.'**
  String get supportCancelled;

  /// No description provided for @supportPending.
  ///
  /// In en, this message translates to:
  /// **'Purchase is pending approval.'**
  String get supportPending;

  /// No description provided for @supportFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed. Please try again later.'**
  String get supportFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @targetAdvance.
  ///
  /// In en, this message translates to:
  /// **'Target {advance}'**
  String targetAdvance(Object advance);

  /// No description provided for @hitAdvance.
  ///
  /// In en, this message translates to:
  /// **'Hit {advance}'**
  String hitAdvance(Object advance);

  /// No description provided for @deltaValue.
  ///
  /// In en, this message translates to:
  /// **'Delta {delta}'**
  String deltaValue(Object delta);

  /// No description provided for @delayValue.
  ///
  /// In en, this message translates to:
  /// **'Delay {delay}'**
  String delayValue(Object delay);

  /// No description provided for @encounterGrass.
  ///
  /// In en, this message translates to:
  /// **'Grass'**
  String get encounterGrass;

  /// No description provided for @encounterSurfing.
  ///
  /// In en, this message translates to:
  /// **'Surfing'**
  String get encounterSurfing;

  /// No description provided for @encounterRockSmash.
  ///
  /// In en, this message translates to:
  /// **'Rock Smash'**
  String get encounterRockSmash;

  /// No description provided for @encounterOldRod.
  ///
  /// In en, this message translates to:
  /// **'Old Rod'**
  String get encounterOldRod;

  /// No description provided for @encounterGoodRod.
  ///
  /// In en, this message translates to:
  /// **'Good Rod'**
  String get encounterGoodRod;

  /// No description provided for @encounterSuperRod.
  ///
  /// In en, this message translates to:
  /// **'Super Rod'**
  String get encounterSuperRod;

  /// No description provided for @staticStarter.
  ///
  /// In en, this message translates to:
  /// **'Starter'**
  String get staticStarter;

  /// No description provided for @staticFossil.
  ///
  /// In en, this message translates to:
  /// **'Fossil'**
  String get staticFossil;

  /// No description provided for @staticGift.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get staticGift;

  /// No description provided for @staticGameCorner.
  ///
  /// In en, this message translates to:
  /// **'Game Corner'**
  String get staticGameCorner;

  /// No description provided for @staticStationary.
  ///
  /// In en, this message translates to:
  /// **'Stationary'**
  String get staticStationary;

  /// No description provided for @staticLegend.
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get staticLegend;

  /// No description provided for @staticEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get staticEvent;

  /// No description provided for @staticRoamer.
  ///
  /// In en, this message translates to:
  /// **'Roamer'**
  String get staticRoamer;

  /// No description provided for @abilitySlot.
  ///
  /// In en, this message translates to:
  /// **'Ability {slot} - {name}'**
  String abilitySlot(Object slot, Object name);

  /// No description provided for @statAttack.
  ///
  /// In en, this message translates to:
  /// **'Atk'**
  String get statAttack;

  /// No description provided for @statDefense.
  ///
  /// In en, this message translates to:
  /// **'Def'**
  String get statDefense;

  /// No description provided for @statSpeed.
  ///
  /// In en, this message translates to:
  /// **'Spe'**
  String get statSpeed;

  /// No description provided for @statSpecialAttack.
  ///
  /// In en, this message translates to:
  /// **'SpA'**
  String get statSpecialAttack;

  /// No description provided for @statSpecialDefense.
  ///
  /// In en, this message translates to:
  /// **'SpD'**
  String get statSpecialDefense;

  /// No description provided for @natureNeutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get natureNeutral;

  /// No description provided for @failedLoadTargetData.
  ///
  /// In en, this message translates to:
  /// **'Failed to load target data: {error}'**
  String failedLoadTargetData(Object error);

  /// No description provided for @resultAdvance.
  ///
  /// In en, this message translates to:
  /// **'Adv'**
  String get resultAdvance;

  /// No description provided for @resultPress.
  ///
  /// In en, this message translates to:
  /// **'Press'**
  String get resultPress;

  /// No description provided for @levelShort.
  ///
  /// In en, this message translates to:
  /// **'Lv'**
  String get levelShort;

  /// No description provided for @hiddenPower.
  ///
  /// In en, this message translates to:
  /// **'HPower'**
  String get hiddenPower;

  /// No description provided for @ivs.
  ///
  /// In en, this message translates to:
  /// **'IVs'**
  String get ivs;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @statIvCalculator.
  ///
  /// In en, this message translates to:
  /// **'Stats / IV calculator'**
  String get statIvCalculator;

  /// No description provided for @calculateStats.
  ///
  /// In en, this message translates to:
  /// **'Calculate stats'**
  String get calculateStats;

  /// No description provided for @calculateIvs.
  ///
  /// In en, this message translates to:
  /// **'Calculate IVs'**
  String get calculateIvs;

  /// No description provided for @calculatorInputError.
  ///
  /// In en, this message translates to:
  /// **'Check Pokemon, level, nature, and input values.'**
  String get calculatorInputError;

  /// No description provided for @sendToCalibration.
  ///
  /// In en, this message translates to:
  /// **'Send to calibration'**
  String get sendToCalibration;

  /// No description provided for @saveTarget.
  ///
  /// In en, this message translates to:
  /// **'Save target'**
  String get saveTarget;

  /// No description provided for @targetSaved.
  ///
  /// In en, this message translates to:
  /// **'Target saved'**
  String get targetSaved;

  /// No description provided for @targetAlreadySaved.
  ///
  /// In en, this message translates to:
  /// **'This target is already saved'**
  String get targetAlreadySaved;

  /// No description provided for @savedTargets.
  ///
  /// In en, this message translates to:
  /// **'Saved targets'**
  String get savedTargets;

  /// No description provided for @noSavedTargets.
  ///
  /// In en, this message translates to:
  /// **'Tap a wild result to save a target.'**
  String get noSavedTargets;

  /// No description provided for @deleteTarget.
  ///
  /// In en, this message translates to:
  /// **'Delete target'**
  String get deleteTarget;

  /// No description provided for @calibrationTarget.
  ///
  /// In en, this message translates to:
  /// **'Calibration target'**
  String get calibrationTarget;

  /// No description provided for @noCalibrationTarget.
  ///
  /// In en, this message translates to:
  /// **'Tap a wild result, then send it to calibration.'**
  String get noCalibrationTarget;

  /// No description provided for @currentTargetAdvance.
  ///
  /// In en, this message translates to:
  /// **'Current target Adv'**
  String get currentTargetAdvance;

  /// No description provided for @actualAdvance.
  ///
  /// In en, this message translates to:
  /// **'Actual Adv'**
  String get actualAdvance;

  /// No description provided for @calibrationOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get calibrationOutput;

  /// No description provided for @targetDelta.
  ///
  /// In en, this message translates to:
  /// **'Total deviation'**
  String get targetDelta;

  /// No description provided for @calculateNextPress.
  ///
  /// In en, this message translates to:
  /// **'Calculate next target Adv'**
  String get calculateNextPress;

  /// No description provided for @retailTimer.
  ///
  /// In en, this message translates to:
  /// **'Retail timer'**
  String get retailTimer;

  /// No description provided for @timerConsole.
  ///
  /// In en, this message translates to:
  /// **'Console'**
  String get timerConsole;

  /// No description provided for @timerConsoleGba.
  ///
  /// In en, this message translates to:
  /// **'GBA'**
  String get timerConsoleGba;

  /// No description provided for @timerConsoleNdsSlot2.
  ///
  /// In en, this message translates to:
  /// **'NDS Slot 2'**
  String get timerConsoleNdsSlot2;

  /// No description provided for @timerConsoleNdsFamily.
  ///
  /// In en, this message translates to:
  /// **'NDS/DSi/3DS'**
  String get timerConsoleNdsFamily;

  /// No description provided for @timerPreparation.
  ///
  /// In en, this message translates to:
  /// **'Preparation'**
  String get timerPreparation;

  /// No description provided for @timerTargetCountdown.
  ///
  /// In en, this message translates to:
  /// **'Target countdown'**
  String get timerTargetCountdown;

  /// No description provided for @timerReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get timerReady;

  /// No description provided for @timerFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get timerFinished;

  /// No description provided for @timerStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get timerStart;

  /// No description provided for @timerStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get timerStop;

  /// No description provided for @timerTargetFrame.
  ///
  /// In en, this message translates to:
  /// **'Timer target {advance}'**
  String timerTargetFrame(Object advance);

  /// No description provided for @timerTargetDuration.
  ///
  /// In en, this message translates to:
  /// **'Target countdown {duration}'**
  String timerTargetDuration(Object duration);

  /// No description provided for @timerPreparationNote.
  ///
  /// In en, this message translates to:
  /// **'Start gives a 5-second countdown; act on the 4th cue.'**
  String get timerPreparationNote;

  /// No description provided for @timerWebSoundUnsupported.
  ///
  /// In en, this message translates to:
  /// **'The web timer does not support countdown audio yet.'**
  String get timerWebSoundUnsupported;

  /// No description provided for @timerEmeraldOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Retail RNG is recommended for Emerald only: Emerald starts from seed 0.'**
  String get timerEmeraldOnlyNote;

  /// No description provided for @timerInputError.
  ///
  /// In en, this message translates to:
  /// **'Check current target Adv.'**
  String get timerInputError;

  /// No description provided for @observedPokemon.
  ///
  /// In en, this message translates to:
  /// **'Observed Pokemon'**
  String get observedPokemon;

  /// No description provided for @observedStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get observedStats;

  /// No description provided for @reverseHitAdvance.
  ///
  /// In en, this message translates to:
  /// **'Reverse hit frame'**
  String get reverseHitAdvance;

  /// No description provided for @reverseResults.
  ///
  /// In en, this message translates to:
  /// **'Reverse results'**
  String get reverseResults;

  /// No description provided for @calibrationFrameInputError.
  ///
  /// In en, this message translates to:
  /// **'Check target Adv and actual Adv.'**
  String get calibrationFrameInputError;

  /// No description provided for @runHuntAndEnterObservedStatsError.
  ///
  /// In en, this message translates to:
  /// **'Send a target from results and enter observed Pokemon, Lv, nature, and stats.'**
  String get runHuntAndEnterObservedStatsError;

  /// No description provided for @actualAdvanceOutput.
  ///
  /// In en, this message translates to:
  /// **'Actual Adv {advance}'**
  String actualAdvanceOutput(Object advance);

  /// No description provided for @actualAdvanceUpdated.
  ///
  /// In en, this message translates to:
  /// **'Actual Adv updated. Calculate above.'**
  String get actualAdvanceUpdated;

  /// No description provided for @nextTargetAdvanceOutput.
  ///
  /// In en, this message translates to:
  /// **'{advance} · Delta {delta}'**
  String nextTargetAdvanceOutput(Object advance, Object delta);

  /// No description provided for @targetDeltaOutput.
  ///
  /// In en, this message translates to:
  /// **'Delta {delta}'**
  String targetDeltaOutput(Object delta);

  /// No description provided for @typeFighting.
  ///
  /// In en, this message translates to:
  /// **'fighting'**
  String get typeFighting;

  /// No description provided for @typeFlying.
  ///
  /// In en, this message translates to:
  /// **'flying'**
  String get typeFlying;

  /// No description provided for @typePoison.
  ///
  /// In en, this message translates to:
  /// **'poison'**
  String get typePoison;

  /// No description provided for @typeGround.
  ///
  /// In en, this message translates to:
  /// **'ground'**
  String get typeGround;

  /// No description provided for @typeRock.
  ///
  /// In en, this message translates to:
  /// **'rock'**
  String get typeRock;

  /// No description provided for @typeBug.
  ///
  /// In en, this message translates to:
  /// **'bug'**
  String get typeBug;

  /// No description provided for @typeGhost.
  ///
  /// In en, this message translates to:
  /// **'ghost'**
  String get typeGhost;

  /// No description provided for @typeSteel.
  ///
  /// In en, this message translates to:
  /// **'steel'**
  String get typeSteel;

  /// No description provided for @typeFire.
  ///
  /// In en, this message translates to:
  /// **'fire'**
  String get typeFire;

  /// No description provided for @typeWater.
  ///
  /// In en, this message translates to:
  /// **'water'**
  String get typeWater;

  /// No description provided for @typeGrass.
  ///
  /// In en, this message translates to:
  /// **'grass'**
  String get typeGrass;

  /// No description provided for @typeElectric.
  ///
  /// In en, this message translates to:
  /// **'electric'**
  String get typeElectric;

  /// No description provided for @typePsychic.
  ///
  /// In en, this message translates to:
  /// **'psychic'**
  String get typePsychic;

  /// No description provided for @typeIce.
  ///
  /// In en, this message translates to:
  /// **'ice'**
  String get typeIce;

  /// No description provided for @typeDragon.
  ///
  /// In en, this message translates to:
  /// **'dragon'**
  String get typeDragon;

  /// No description provided for @typeDark.
  ///
  /// In en, this message translates to:
  /// **'dark'**
  String get typeDark;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
