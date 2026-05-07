// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'PokeRNG G3';

  @override
  String get hunt => '狩猎';

  @override
  String get calibrate => '校准';

  @override
  String get breeding => '孵蛋';

  @override
  String get tools => '工具';

  @override
  String get settings => '设置';

  @override
  String get target => '目标';

  @override
  String get encounter => '遇敌';

  @override
  String get search => '搜索';

  @override
  String get searching => '搜索中...';

  @override
  String get cancelSearch => '取消搜索';

  @override
  String get attempt => '尝试';

  @override
  String get pokemon => '宝可梦';

  @override
  String get pokemonSearchLimitHint =>
      '请输入宝可梦编号从该编号开始浏览，或者输入名字关键字。最多显示 50 个候选。';

  @override
  String get shiny => '闪光';

  @override
  String get nature => '性格';

  @override
  String get minimumIv => '最低 IV';

  @override
  String get seed => 'Seed';

  @override
  String get initialAdvance => '起始帧';

  @override
  String get maxAdvance => '最大帧';

  @override
  String get delay => '延迟';

  @override
  String get results => '结果';

  @override
  String get selectAResult => '选择一个结果';

  @override
  String get gameVersion => '游戏版本';

  @override
  String get defaultSeed => '默认 Seed';

  @override
  String get save => '保存';

  @override
  String get observedNature => '观测性格';

  @override
  String get observedIvs => '观测 IV';

  @override
  String get locationEgg => '地点';

  @override
  String get breedingUnavailable => '孵蛋乱数暂未实现。';

  @override
  String get eggHeldStage => '蛋生成帧';

  @override
  String get eggPickupStage => '蛋领取帧';

  @override
  String get parentA => '父母 1';

  @override
  String get parentB => '父母 2';

  @override
  String get parentGender => '父母性别';

  @override
  String get parentItem => '携带道具';

  @override
  String get none => '无';

  @override
  String get everstone => '不变之石';

  @override
  String get ditto => '百变怪';

  @override
  String get compatibility => '相性';

  @override
  String get calibration => '校准';

  @override
  String get minRedraws => '最小查看图鉴';

  @override
  String get maxRedraws => '最大查看图鉴';

  @override
  String get redraws => '查看图鉴';

  @override
  String eggInputError(Object maxAdvanceDelta) {
    return '请检查宝可梦、Seed、两段帧范围、校准、查看图鉴次数和父母 IV。每段最大 - 起始必须 <= $maxAdvanceDelta。';
  }

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
  String get gender => '性别';

  @override
  String get any => '任意';

  @override
  String get slot => 'Slot';

  @override
  String get lead => '队首特性';

  @override
  String get leadNone => '无';

  @override
  String get leadPressure => '压迫感';

  @override
  String get leadSynchronize => '同步';

  @override
  String get leadStatic => '静电';

  @override
  String get leadMagnetPull => '磁力';

  @override
  String get leadCuteCharmFemale => '迷人之躯 ♀';

  @override
  String get leadCuteCharmMale => '迷人之躯 ♂';

  @override
  String get syncNature => '同步性格';

  @override
  String get feebasTile => '丑丑鱼水格';

  @override
  String get ivAnyNote => '-1 = 任意 IV';

  @override
  String searchRangeNote(Object maxAdvanceDelta, Object maxResults) {
    return '最大 - 起始 <= $maxAdvanceDelta 帧 · 结果 <= $maxResults';
  }

  @override
  String resultLimitNote(Object maxResults) {
    return '只显示前 $maxResults 个结果。请缩小筛选条件或降低范围来查看后续结果。';
  }

  @override
  String get selectPokemonEncounterLocationError => '请选择宝可梦、遇敌方式和地点。';

  @override
  String huntInputError(Object maxAdvanceDelta) {
    return '请检查 Seed、帧范围、延迟和 IV 筛选。最大 - 起始必须 <= $maxAdvanceDelta。';
  }

  @override
  String get runHuntAndEnterObservedIvsError => '请先运行狩猎搜索，并输入观测 IV。';

  @override
  String get noMatchingAdvanceError => '当前搜索范围内没有匹配的帧。';

  @override
  String get noResults => '未找到结果。请放宽条件或提高最大帧。';

  @override
  String get searchCancelled => '搜索已取消。';

  @override
  String get settingsInputError => '请检查 TID、SID 和 Seed。';

  @override
  String targetAdvance(Object advance) {
    return '目标帧 $advance';
  }

  @override
  String hitAdvance(Object advance) {
    return '命中帧 $advance';
  }

  @override
  String deltaValue(Object delta) {
    return '偏差 $delta';
  }

  @override
  String delayValue(Object delay) {
    return '延迟 $delay';
  }

  @override
  String get encounterGrass => '草丛';

  @override
  String get encounterSurfing => '冲浪';

  @override
  String get encounterRockSmash => '碎岩';

  @override
  String get encounterOldRod => '破旧钓竿';

  @override
  String get encounterGoodRod => '好钓竿';

  @override
  String get encounterSuperRod => '厉害钓竿';

  @override
  String get staticStarter => '初始宝可梦';

  @override
  String get staticFossil => '化石';

  @override
  String get staticGift => '礼物';

  @override
  String get staticGameCorner => '游戏厅';

  @override
  String get staticStationary => '固定';

  @override
  String get staticLegend => '传说';

  @override
  String get staticEvent => '事件';

  @override
  String get staticRoamer => '徘徊';

  @override
  String abilitySlot(Object slot, Object name) {
    return '特性$slot - $name';
  }

  @override
  String get statAttack => '攻击';

  @override
  String get statDefense => '防御';

  @override
  String get statSpeed => '速度';

  @override
  String get statSpecialAttack => '特攻';

  @override
  String get statSpecialDefense => '特防';

  @override
  String get natureNeutral => '平衡';

  @override
  String failedLoadTargetData(Object error) {
    return '目标数据加载失败：$error';
  }

  @override
  String get resultAdvance => '帧';

  @override
  String get resultPress => '按下';

  @override
  String get levelShort => 'Lv';

  @override
  String get hiddenPower => '觉醒力量';

  @override
  String get ivs => 'IV';

  @override
  String get stats => '能力值';

  @override
  String get statIvCalculator => '能力值 / IV 计算器';

  @override
  String get calculateStats => '计算能力值';

  @override
  String get calculateIvs => '计算 IV';

  @override
  String get calculatorInputError => '请检查宝可梦、等级、性格和输入数值。';

  @override
  String get sendToCalibration => '发送到校准';

  @override
  String get saveTarget => '保存目标';

  @override
  String get targetSaved => '目标已保存';

  @override
  String get targetAlreadySaved => '这个目标已经保存过';

  @override
  String get savedTargets => '目标记录';

  @override
  String get noSavedTargets => '在结果页长按或右键某个野生结果，可以保存目标。';

  @override
  String get deleteTarget => '删除目标';

  @override
  String get calibrationTarget => '校准目标';

  @override
  String get noCalibrationTarget => '在结果页长按或右键某个野生结果，然后发送到校准。';

  @override
  String get currentTargetAdvance => '本次目标帧';

  @override
  String get actualAdvance => '实际帧';

  @override
  String get calibrationOutput => '输出';

  @override
  String get targetDelta => '总偏差值';

  @override
  String get calculateNextPress => '计算下一次目标帧';

  @override
  String get observedPokemon => '实际宝可梦';

  @override
  String get observedStats => '能力值';

  @override
  String get reverseHitAdvance => '反查实际帧';

  @override
  String get reverseResults => '反查结果';

  @override
  String get calibrationFrameInputError => '请检查此次目标帧和实际帧。';

  @override
  String get runHuntAndEnterObservedStatsError => '请先从结果页发送目标，并输入实际能力值。';

  @override
  String actualAdvanceOutput(Object advance) {
    return '实际帧 $advance';
  }

  @override
  String nextTargetAdvanceOutput(Object advance, Object delta) {
    return '$advance · 偏差 $delta';
  }

  @override
  String targetDeltaOutput(Object delta) {
    return '偏差 $delta';
  }

  @override
  String get typeFighting => '格斗';

  @override
  String get typeFlying => '飞行';

  @override
  String get typePoison => '毒';

  @override
  String get typeGround => '地面';

  @override
  String get typeRock => '岩石';

  @override
  String get typeBug => '虫';

  @override
  String get typeGhost => '幽灵';

  @override
  String get typeSteel => '钢';

  @override
  String get typeFire => '火';

  @override
  String get typeWater => '水';

  @override
  String get typeGrass => '草';

  @override
  String get typeElectric => '电';

  @override
  String get typePsychic => '超能力';

  @override
  String get typeIce => '冰';

  @override
  String get typeDragon => '龙';

  @override
  String get typeDark => '恶';
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get appTitle => 'PokeRNG G3';

  @override
  String get hunt => '狩猎';

  @override
  String get calibrate => '校准';

  @override
  String get breeding => '孵蛋';

  @override
  String get tools => '工具';

  @override
  String get settings => '设置';

  @override
  String get target => '目标';

  @override
  String get encounter => '遇敌';

  @override
  String get search => '搜索';

  @override
  String get searching => '搜索中...';

  @override
  String get cancelSearch => '取消搜索';

  @override
  String get attempt => '尝试';

  @override
  String get pokemon => '宝可梦';

  @override
  String get pokemonSearchLimitHint =>
      '请输入宝可梦编号从该编号开始浏览，或者输入名字关键字。最多显示 50 个候选。';

  @override
  String get shiny => '闪光';

  @override
  String get nature => '性格';

  @override
  String get minimumIv => '最低 IV';

  @override
  String get seed => 'Seed';

  @override
  String get initialAdvance => '起始帧';

  @override
  String get maxAdvance => '最大帧';

  @override
  String get delay => '延迟';

  @override
  String get results => '结果';

  @override
  String get selectAResult => '选择一个结果';

  @override
  String get gameVersion => '游戏版本';

  @override
  String get defaultSeed => '默认 Seed';

  @override
  String get save => '保存';

  @override
  String get observedNature => '观测性格';

  @override
  String get observedIvs => '观测 IV';

  @override
  String get locationEgg => '地点';

  @override
  String get breedingUnavailable => '孵蛋乱数暂未实现。';

  @override
  String get eggHeldStage => '蛋生成帧';

  @override
  String get eggPickupStage => '蛋领取帧';

  @override
  String get parentA => '父母 1';

  @override
  String get parentB => '父母 2';

  @override
  String get parentGender => '父母性别';

  @override
  String get parentItem => '携带道具';

  @override
  String get none => '无';

  @override
  String get everstone => '不变之石';

  @override
  String get ditto => '百变怪';

  @override
  String get compatibility => '相性';

  @override
  String get calibration => '校准';

  @override
  String get minRedraws => '最小查看图鉴';

  @override
  String get maxRedraws => '最大查看图鉴';

  @override
  String get redraws => '查看图鉴';

  @override
  String eggInputError(Object maxAdvanceDelta) {
    return '请检查宝可梦、Seed、两段帧范围、校准、查看图鉴次数和父母 IV。每段最大 - 起始必须 <= $maxAdvanceDelta。';
  }

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
  String get gender => '性别';

  @override
  String get any => '任意';

  @override
  String get slot => 'Slot';

  @override
  String get lead => '队首特性';

  @override
  String get leadNone => '无';

  @override
  String get leadPressure => '压迫感';

  @override
  String get leadSynchronize => '同步';

  @override
  String get leadStatic => '静电';

  @override
  String get leadMagnetPull => '磁力';

  @override
  String get leadCuteCharmFemale => '迷人之躯 ♀';

  @override
  String get leadCuteCharmMale => '迷人之躯 ♂';

  @override
  String get syncNature => '同步性格';

  @override
  String get feebasTile => '丑丑鱼水格';

  @override
  String get ivAnyNote => '-1 = 任意 IV';

  @override
  String searchRangeNote(Object maxAdvanceDelta, Object maxResults) {
    return '最大 - 起始 <= $maxAdvanceDelta 帧 · 结果 <= $maxResults';
  }

  @override
  String resultLimitNote(Object maxResults) {
    return '只显示前 $maxResults 个结果。请缩小筛选条件或降低范围来查看后续结果。';
  }

  @override
  String get selectPokemonEncounterLocationError => '请选择宝可梦、遇敌方式和地点。';

  @override
  String huntInputError(Object maxAdvanceDelta) {
    return '请检查 Seed、帧范围、延迟和 IV 筛选。最大 - 起始必须 <= $maxAdvanceDelta。';
  }

  @override
  String get runHuntAndEnterObservedIvsError => '请先运行狩猎搜索，并输入观测 IV。';

  @override
  String get noMatchingAdvanceError => '当前搜索范围内没有匹配的帧。';

  @override
  String get noResults => '未找到结果。请放宽条件或提高最大帧。';

  @override
  String get searchCancelled => '搜索已取消。';

  @override
  String get settingsInputError => '请检查 TID、SID 和 Seed。';

  @override
  String targetAdvance(Object advance) {
    return '目标帧 $advance';
  }

  @override
  String hitAdvance(Object advance) {
    return '命中帧 $advance';
  }

  @override
  String deltaValue(Object delta) {
    return '偏差 $delta';
  }

  @override
  String delayValue(Object delay) {
    return '延迟 $delay';
  }

  @override
  String get encounterGrass => '草丛';

  @override
  String get encounterSurfing => '冲浪';

  @override
  String get encounterRockSmash => '碎岩';

  @override
  String get encounterOldRod => '破旧钓竿';

  @override
  String get encounterGoodRod => '好钓竿';

  @override
  String get encounterSuperRod => '厉害钓竿';

  @override
  String get staticStarter => '初始宝可梦';

  @override
  String get staticFossil => '化石';

  @override
  String get staticGift => '礼物';

  @override
  String get staticGameCorner => '游戏厅';

  @override
  String get staticStationary => '固定';

  @override
  String get staticLegend => '传说';

  @override
  String get staticEvent => '事件';

  @override
  String get staticRoamer => '徘徊';

  @override
  String abilitySlot(Object slot, Object name) {
    return '特性$slot - $name';
  }

  @override
  String get statAttack => '攻击';

  @override
  String get statDefense => '防御';

  @override
  String get statSpeed => '速度';

  @override
  String get statSpecialAttack => '特攻';

  @override
  String get statSpecialDefense => '特防';

  @override
  String get natureNeutral => '平衡';

  @override
  String failedLoadTargetData(Object error) {
    return '目标数据加载失败：$error';
  }

  @override
  String get resultAdvance => '帧';

  @override
  String get resultPress => '按下';

  @override
  String get levelShort => 'Lv';

  @override
  String get hiddenPower => '觉醒力量';

  @override
  String get ivs => 'IV';

  @override
  String get stats => '能力值';

  @override
  String get statIvCalculator => '能力值 / IV 计算器';

  @override
  String get calculateStats => '计算能力值';

  @override
  String get calculateIvs => '计算 IV';

  @override
  String get calculatorInputError => '请检查宝可梦、等级、性格和输入数值。';

  @override
  String get sendToCalibration => '发送到校准';

  @override
  String get saveTarget => '保存目标';

  @override
  String get targetSaved => '目标已保存';

  @override
  String get targetAlreadySaved => '这个目标已经保存过';

  @override
  String get savedTargets => '目标记录';

  @override
  String get noSavedTargets => '在结果页长按或右键某个野生结果，可以保存目标。';

  @override
  String get deleteTarget => '删除目标';

  @override
  String get calibrationTarget => '校准目标';

  @override
  String get noCalibrationTarget => '在结果页长按或右键某个野生结果，然后发送到校准。';

  @override
  String get currentTargetAdvance => '本次目标帧';

  @override
  String get actualAdvance => '实际帧';

  @override
  String get calibrationOutput => '输出';

  @override
  String get targetDelta => '总偏差值';

  @override
  String get calculateNextPress => '计算下一次目标帧';

  @override
  String get observedPokemon => '实际宝可梦';

  @override
  String get observedStats => '能力值';

  @override
  String get reverseHitAdvance => '反查实际帧';

  @override
  String get reverseResults => '反查结果';

  @override
  String get calibrationFrameInputError => '请检查此次目标帧和实际帧。';

  @override
  String get runHuntAndEnterObservedStatsError => '请先从结果页发送目标，并输入实际能力值。';

  @override
  String actualAdvanceOutput(Object advance) {
    return '实际帧 $advance';
  }

  @override
  String nextTargetAdvanceOutput(Object advance, Object delta) {
    return '$advance · 偏差 $delta';
  }

  @override
  String targetDeltaOutput(Object delta) {
    return '偏差 $delta';
  }

  @override
  String get typeFighting => '格斗';

  @override
  String get typeFlying => '飞行';

  @override
  String get typePoison => '毒';

  @override
  String get typeGround => '地面';

  @override
  String get typeRock => '岩石';

  @override
  String get typeBug => '虫';

  @override
  String get typeGhost => '幽灵';

  @override
  String get typeSteel => '钢';

  @override
  String get typeFire => '火';

  @override
  String get typeWater => '水';

  @override
  String get typeGrass => '草';

  @override
  String get typeElectric => '电';

  @override
  String get typePsychic => '超能力';

  @override
  String get typeIce => '冰';

  @override
  String get typeDragon => '龙';

  @override
  String get typeDark => '恶';
}
