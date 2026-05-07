// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'PokeRNG G3';

  @override
  String get hunt => '検索';

  @override
  String get calibrate => '調整';

  @override
  String get breeding => 'タマゴ';

  @override
  String get tools => 'ツール';

  @override
  String get settings => '設定';

  @override
  String get target => '目標';

  @override
  String get encounter => '遭遇';

  @override
  String get search => '検索';

  @override
  String get searching => '検索中...';

  @override
  String get cancelSearch => '検索をキャンセル';

  @override
  String get attempt => '試行';

  @override
  String get pokemon => 'ポケモン';

  @override
  String get pokemonSearchLimitHint =>
      'ポケモンの番号を入力するとその番号から表示します。名前のキーワードでも検索できます。候補は最大 50 件です。';

  @override
  String get shiny => '色違い';

  @override
  String get nature => '性格';

  @override
  String get minimumIv => '最低 IV';

  @override
  String get seed => 'Seed';

  @override
  String get initialAdvance => '開始 Advance';

  @override
  String get maxAdvance => '最大 Advance';

  @override
  String get delay => '遅延';

  @override
  String get results => '結果';

  @override
  String get selectAResult => '結果を選択';

  @override
  String get gameVersion => 'ゲーム';

  @override
  String get defaultSeed => '既定 Seed';

  @override
  String get save => '保存';

  @override
  String get observedNature => '観測した性格';

  @override
  String get observedIvs => '観測 IV';

  @override
  String get locationEgg => '場所';

  @override
  String get breedingUnavailable => 'タマゴ乱数は未実装です。';

  @override
  String get method => '生成方式';

  @override
  String get wildMethod1 => '野生 1';

  @override
  String get wildMethod2 => '野生 2';

  @override
  String get wildMethod4 => '野生 4';

  @override
  String get staticMethod1 => 'Method 1';

  @override
  String get staticMethod2 => 'Method 2';

  @override
  String get staticMethod4 => 'Method 4';

  @override
  String get ability => '特性';

  @override
  String get gender => '性別';

  @override
  String get any => '任意';

  @override
  String get slot => 'Slot';

  @override
  String get lead => '先頭特性';

  @override
  String get leadNone => 'なし';

  @override
  String get leadPressure => 'プレッシャー';

  @override
  String get leadSynchronize => 'シンクロ';

  @override
  String get leadStatic => 'せいでんき';

  @override
  String get leadMagnetPull => 'じりょく';

  @override
  String get leadCuteCharmFemale => 'メロメロボディ ♀';

  @override
  String get leadCuteCharmMale => 'メロメロボディ ♂';

  @override
  String get syncNature => 'シンクロ性格';

  @override
  String get feebasTile => 'ヒンバスのマス';

  @override
  String get ivAnyNote => '-1 = 任意 IV';

  @override
  String searchRangeNote(Object maxAdvanceDelta, Object maxResults) {
    return '最大 - 開始 <= $maxAdvanceDelta フレーム · 結果 <= $maxResults';
  }

  @override
  String resultLimitNote(Object maxResults) {
    return '最初の $maxResults 件だけを表示しています。条件を絞るか範囲を下げると後続を確認できます。';
  }

  @override
  String get selectPokemonEncounterLocationError => 'ポケモン、遭遇方式、場所を選択してください。';

  @override
  String huntInputError(Object maxAdvanceDelta) {
    return 'Seed、フレーム範囲、遅延、IV条件を確認してください。最大 - 開始は $maxAdvanceDelta 以下です。';
  }

  @override
  String get runHuntAndEnterObservedIvsError => '先に検索を実行し、観測 IV を入力してください。';

  @override
  String get noMatchingAdvanceError => '現在の検索範囲に一致するフレームがありません。';

  @override
  String get noResults => '結果がありません。条件を緩めるか最大 Advance を上げてください。';

  @override
  String get searchCancelled => '検索をキャンセルしました。';

  @override
  String get settingsInputError => 'TID、SID、Seed を確認してください。';

  @override
  String targetAdvance(Object advance) {
    return '目標 $advance';
  }

  @override
  String hitAdvance(Object advance) {
    return '命中 $advance';
  }

  @override
  String deltaValue(Object delta) {
    return '差分 $delta';
  }

  @override
  String delayValue(Object delay) {
    return '遅延 $delay';
  }

  @override
  String get encounterGrass => 'くさむら';

  @override
  String get encounterSurfing => 'なみのり';

  @override
  String get encounterRockSmash => 'いわくだき';

  @override
  String get encounterOldRod => 'ボロのつりざお';

  @override
  String get encounterGoodRod => 'いいつりざお';

  @override
  String get encounterSuperRod => 'すごいつりざお';

  @override
  String get staticStarter => '御三家';

  @override
  String get staticFossil => '化石';

  @override
  String get staticGift => 'もらう';

  @override
  String get staticGameCorner => 'ゲームコーナー';

  @override
  String get staticStationary => '固定';

  @override
  String get staticLegend => '伝説';

  @override
  String get staticEvent => 'イベント';

  @override
  String get staticRoamer => '徘徊';

  @override
  String abilitySlot(Object slot, Object name) {
    return '特性$slot - $name';
  }

  @override
  String get statAttack => 'こうげき';

  @override
  String get statDefense => 'ぼうぎょ';

  @override
  String get statSpeed => 'すばやさ';

  @override
  String get statSpecialAttack => 'とくこう';

  @override
  String get statSpecialDefense => 'とくぼう';

  @override
  String get natureNeutral => '補正なし';

  @override
  String failedLoadTargetData(Object error) {
    return '目標データの読み込みに失敗しました: $error';
  }

  @override
  String get resultAdvance => 'Adv';

  @override
  String get resultPress => '押下';

  @override
  String get levelShort => 'Lv';

  @override
  String get hiddenPower => 'めざパ';

  @override
  String get ivs => 'IV';

  @override
  String get stats => '能力値';

  @override
  String get statIvCalculator => '能力値 / IV 計算';

  @override
  String get calculateStats => '能力値を計算';

  @override
  String get calculateIvs => 'IV を計算';

  @override
  String get calculatorInputError => 'ポケモン、レベル、性格、入力値を確認してください。';

  @override
  String get sendToCalibration => '調整へ送る';

  @override
  String get saveTarget => '目標を保存';

  @override
  String get targetSaved => '目標を保存しました';

  @override
  String get targetAlreadySaved => 'この目標は保存済みです';

  @override
  String get savedTargets => '保存した目標';

  @override
  String get noSavedTargets => '野生結果を長押し、または右クリックして目標を保存できます。';

  @override
  String get deleteTarget => '目標を削除';

  @override
  String get calibrationTarget => '調整目標';

  @override
  String get noCalibrationTarget => '野生結果を長押し、または右クリックして調整へ送ってください。';

  @override
  String get currentTargetAdvance => '今回の目標 Adv';

  @override
  String get actualAdvance => '実際の Adv';

  @override
  String get calibrationOutput => '出力';

  @override
  String get targetDelta => '合計ずれ';

  @override
  String get calculateNextPress => '次の目標 Adv を計算';

  @override
  String get observedPokemon => '実際のポケモン';

  @override
  String get observedStats => '能力値';

  @override
  String get reverseHitAdvance => '実際のフレームを逆算';

  @override
  String get reverseResults => '逆算結果';

  @override
  String get calibrationFrameInputError => '今回の目標 Adv と実際の Adv を確認してください。';

  @override
  String get runHuntAndEnterObservedStatsError => '結果から目標を送り、実際の能力値を入力してください。';

  @override
  String actualAdvanceOutput(Object advance) {
    return '実際 Adv $advance';
  }

  @override
  String nextTargetAdvanceOutput(Object advance, Object delta) {
    return '$advance · ずれ $delta';
  }

  @override
  String targetDeltaOutput(Object delta) {
    return 'ずれ $delta';
  }

  @override
  String get typeFighting => 'かくとう';

  @override
  String get typeFlying => 'ひこう';

  @override
  String get typePoison => 'どく';

  @override
  String get typeGround => 'じめん';

  @override
  String get typeRock => 'いわ';

  @override
  String get typeBug => 'むし';

  @override
  String get typeGhost => 'ゴースト';

  @override
  String get typeSteel => 'はがね';

  @override
  String get typeFire => 'ほのお';

  @override
  String get typeWater => 'みず';

  @override
  String get typeGrass => 'くさ';

  @override
  String get typeElectric => 'でんき';

  @override
  String get typePsychic => 'エスパー';

  @override
  String get typeIce => 'こおり';

  @override
  String get typeDragon => 'ドラゴン';

  @override
  String get typeDark => 'あく';
}
