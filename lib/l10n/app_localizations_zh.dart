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
  String get initialAdvance => '起始 Advance';

  @override
  String get maxAdvance => '最大 Advance';

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
  String get idSid => 'ID/SID';

  @override
  String get ivsToPid => 'IV 转 PID';

  @override
  String get battleVideo => '对战录像';

  @override
  String get painting => '画作';

  @override
  String get locationEgg => '地点 / 蛋';

  @override
  String get egg => '蛋';

  @override
  String get eggUnsupported => '蛋（之后支持）';

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
  String get noResults => '未找到结果。请放宽条件或提高最大 Advance。';

  @override
  String get searchCancelled => '搜索已取消。';

  @override
  String get settingsInputError => '请检查 TID、SID 和 Seed。';

  @override
  String targetAdvance(Object advance) {
    return '目标 $advance';
  }

  @override
  String hitAdvance(Object advance) {
    return '命中 $advance';
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
  String get resultAdvance => 'Adv';

  @override
  String get resultPress => '按下';

  @override
  String get levelShort => 'Lv';

  @override
  String get hiddenPower => '觉醒力量';

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
  String get initialAdvance => '起始 Advance';

  @override
  String get maxAdvance => '最大 Advance';

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
  String get idSid => 'ID/SID';

  @override
  String get ivsToPid => 'IV 转 PID';

  @override
  String get battleVideo => '对战录像';

  @override
  String get painting => '画作';

  @override
  String get locationEgg => '地点 / 蛋';

  @override
  String get egg => '蛋';

  @override
  String get eggUnsupported => '蛋（之后支持）';

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
  String get noResults => '未找到结果。请放宽条件或提高最大 Advance。';

  @override
  String get searchCancelled => '搜索已取消。';

  @override
  String get settingsInputError => '请检查 TID、SID 和 Seed。';

  @override
  String targetAdvance(Object advance) {
    return '目标 $advance';
  }

  @override
  String hitAdvance(Object advance) {
    return '命中 $advance';
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
  String get resultAdvance => 'Adv';

  @override
  String get resultPress => '按下';

  @override
  String get levelShort => 'Lv';

  @override
  String get hiddenPower => '觉醒力量';

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
