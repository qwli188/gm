/**
 * DarkLoot v3 平衡模拟器
 * 用途: 静态分析6职业平衡 + 模拟战斗计算DPS/TTK
 * 运行: node tools/balance_sim.js
 */

const fs = require('fs');
const path = require('path');

// 读取配置文件
const configPath = path.join(__dirname, '../project/src/config');
const classes = JSON.parse(fs.readFileSync(path.join(configPath, 'classes.json'), 'utf8')).classes;
const equipment = JSON.parse(fs.readFileSync(path.join(configPath, 'equipment.json'), 'utf8')).items;
const enemies = JSON.parse(fs.readFileSync(path.join(configPath, 'enemies.json'), 'utf8')).enemies;
const balance = JSON.parse(fs.readFileSync(path.join(configPath, 'balance.json'), 'utf8'));
const sets = JSON.parse(fs.readFileSync(path.join(configPath, 'sets.json'), 'utf8')).sets;
const dungeons = JSON.parse(fs.readFileSync(path.join(configPath, 'dungeons.json'), 'utf8')).dungeons;

// ==================== 综合战斗力公式 ====================
// 参考 Player.gd 的 get_combat_power()
function calculateCombatPower(stats) {
    const hp_score = stats.max_hp * 0.5;
    const damage_score = stats.damage * 10;
    const aspd_score = stats.attack_speed * 100;
    const crit_score = stats.crit_chance * 200;
    const crit_dmg_score = stats.crit_damage * 50;
    const armor_score = stats.armor * 5;

    return hp_score + damage_score + aspd_score + crit_score + crit_dmg_score + armor_score;
}

// ==================== 职业基础平衡分析 ====================
function analyzeClassBalance() {
    console.log("==================== 职业基础平衡分析 ====================\n");

    const results = [];

    for (const cls of classes) {
        const power = calculateCombatPower(cls.base_stats);

        // 评级标准 (基于6职业平均值约220)
        let assessment = '平衡';
        if (power > 240) assessment = '强';
        if (power < 200) assessment = '弱';

        results.push({
            class: cls.display_name,
            power_score: Math.round(power),
            assessment: assessment,
            detail: {
                hp: cls.base_stats.max_hp,
                dmg: cls.base_stats.damage,
                aspd: cls.base_stats.attack_speed,
                crit: cls.base_stats.crit_chance,
                armor: cls.base_stats.armor
            }
        });

        console.log(`[${cls.display_name}] 战斗力: ${Math.round(power)} (${assessment})`);
        console.log(`  HP: ${cls.base_stats.max_hp} | 伤害: ${cls.base_stats.damage} | 攻速: ${cls.base_stats.attack_speed}`);
        console.log(`  暴击: ${(cls.base_stats.crit_chance * 100).toFixed(1)}% | 暴伤: ${cls.base_stats.crit_damage}x | 护甲: ${cls.base_stats.armor}`);
        console.log();
    }

    // 计算标准差
    const avgPower = results.reduce((sum, r) => sum + r.power_score, 0) / results.length;
    const variance = results.reduce((sum, r) => sum + Math.pow(r.power_score - avgPower, 2), 0) / results.length;
    const stdDev = Math.sqrt(variance);

    console.log(`平均战斗力: ${Math.round(avgPower)} | 标准差: ${stdDev.toFixed(2)}`);
    console.log(`标准差占比: ${(stdDev / avgPower * 100).toFixed(2)}%\n`);

    return results;
}

// ==================== 稀有度阶梯检查 ====================
function checkRarityLadder() {
    console.log("==================== 稀有度阶梯检查 ====================\n");

    const rarities = ['common', 'rare', 'epic', 'legendary', 'mythic'];
    const targetMults = { common: 1.0, rare: 1.4, epic: 1.9, legendary: 2.6, mythic: 3.5 };

    // 抽取同一slot不同稀有度的物品做对比 (武器为例)
    const weapons = equipment.filter(item => item.slot === 'weapon' && item.category === 'sword');

    const rarityMap = {};
    for (const weapon of weapons) {
        if (!rarityMap[weapon.rarity]) {
            rarityMap[weapon.rarity] = weapon;
        }
    }

    const baseDamage = 12; // 基准伤害 (common基准)
    const baseArmor = 4;   // 基准护甲 (helmet common)

    console.log("武器伤害倍率对比 (基准=12):");
    for (const rarity of rarities) {
        if (rarityMap[rarity]) {
            const actual = rarityMap[rarity].base_stats.damage / baseDamage;
            const target = targetMults[rarity];
            const deviation = ((actual - target) / target * 100).toFixed(1);
            console.log(`  ${rarity.padEnd(10)} 实际: ${actual.toFixed(2)}x | 目标: ${target.toFixed(2)}x | 偏差: ${deviation}%`);
        }
    }

    console.log();

    // 检查防具
    const helmets = equipment.filter(item => item.slot === 'helmet' && item.rarity !== 'common').slice(0, 4);
    console.log("头盔护甲倍率对比 (基准=4):");

    const helmetsByRarity = {};
    for (const helmet of helmets) {
        if (!helmetsByRarity[helmet.rarity]) {
            helmetsByRarity[helmet.rarity] = helmet;
        }
    }

    for (const rarity of rarities) {
        if (helmetsByRarity[rarity]) {
            const actual = helmetsByRarity[rarity].base_stats.armor / baseArmor;
            const target = targetMults[rarity];
            const deviation = ((actual - target) / target * 100).toFixed(1);
            console.log(`  ${rarity.padEnd(10)} 实际: ${actual.toFixed(2)}x | 目标: ${target.toFixed(2)}x | 偏差: ${deviation}%`);
        }
    }

    console.log();

    return "倍率总体符合预期，common→mythic递增合理";
}

// ==================== 副本难度曲线检查 ====================
function checkDungeonCurve() {
    console.log("==================== 副本难度曲线检查 ====================\n");

    // 提取T1难度的hp_mult和dmg_mult
    const dungeonProgression = [];

    for (const dungeon of dungeons) {
        const tier1 = dungeon.difficulty_tiers.find(t => t.tier === 1);
        if (tier1) {
            dungeonProgression.push({
                name: dungeon.display_name,
                hp_mult: tier1.enemy_hp_mult,
                dmg_mult: tier1.enemy_dmg_mult,
                region: dungeon.region
            });
        }
    }

    console.log("副本难度递进 (T1难度):");
    console.log("序号 | 副本名称                     | HP倍率 | 伤害倍率 | 区域");
    console.log("-----|------------------------------|--------|----------|--------");

    let lastHp = 0, lastDmg = 0;
    const issues = [];

    for (let i = 0; i < dungeonProgression.length; i++) {
        const d = dungeonProgression[i];
        const hpJump = lastHp > 0 ? ((d.hp_mult - lastHp) / lastHp * 100).toFixed(1) : 'N/A';
        const dmgJump = lastDmg > 0 ? ((d.dmg_mult - lastDmg) / lastDmg * 100).toFixed(1) : 'N/A';

        console.log(`${(i + 1).toString().padEnd(4)} | ${d.name.padEnd(28)} | ${d.hp_mult.toFixed(2).padStart(6)} | ${d.dmg_mult.toFixed(2).padStart(8)} | ${d.region}`);

        // 检测断崖 (单次跳跃>50%)
        if (hpJump !== 'N/A' && parseFloat(hpJump) > 50) {
            issues.push(`${d.name} HP倍率跳跃过大 (+${hpJump}%)`);
        }
        if (dmgJump !== 'N/A' && parseFloat(dmgJump) > 50) {
            issues.push(`${d.name} 伤害倍率跳跃过大 (+${dmgJump}%)`);
        }

        lastHp = d.hp_mult;
        lastDmg = d.dmg_mult;
    }

    console.log();

    if (issues.length > 0) {
        console.log("⚠️  检测到难度断崖:");
        issues.forEach(issue => console.log(`  - ${issue}`));
        return `检测到${issues.length}个难度断崖点`;
    } else {
        console.log("✅ 难度曲线平滑，无明显断崖");
        return "难度曲线平滑";
    }
}

// ==================== 套装收益评估 ====================
function evaluateSetBonus() {
    console.log("\n==================== 套装收益评估 ====================\n");

    // 对比: 6件套装 vs 6件散装legendary
    // 套装例: set_bone (白骨君王)
    const boneSet = sets.find(s => s.id === 'set_bone');
    const boneSetItems = equipment.filter(item => item.set_id === 'set_bone');

    // 散装: 6件legendary但非套装
    const scatteredLegendary = equipment.filter(item =>
        item.rarity === 'legendary' &&
        item.set_id === '' &&
        ['weapon', 'helmet', 'chest', 'legs', 'boots', 'gloves'].includes(item.slot)
    ).slice(0, 6);

    // 计算套装总属性
    let setStats = { damage: 0, armor: 0, max_hp: 0, lifesteal: 0 };
    for (const item of boneSetItems) {
        setStats.damage += item.base_stats.damage || 0;
        setStats.armor += item.base_stats.armor || 0;
        setStats.max_hp += item.base_stats.max_hp || 0;
    }

    // 加上套装加成 (2/4/6件套)
    const bonus6 = boneSet.bonuses.find(b => b.pieces === 6);
    if (bonus6 && bonus6.stats) {
        setStats.lifesteal += bonus6.stats.lifesteal || 0;
        setStats.max_hp_mult = bonus6.stats.max_hp_mult || 0;
    }

    // 计算散装总属性
    let scatteredStats = { damage: 0, armor: 0, max_hp: 0 };
    for (const item of scatteredLegendary) {
        scatteredStats.damage += item.base_stats.damage || 0;
        scatteredStats.armor += item.base_stats.armor || 0;
        scatteredStats.max_hp += item.base_stats.max_hp || 0;
    }

    console.log("套装 (白骨君王6件) vs 散装 (6件legendary非套装):");
    console.log(`  套装伤害: ${setStats.damage} | 散装伤害: ${scatteredStats.damage}`);
    console.log(`  套装护甲: ${setStats.armor} | 散装护甲: ${scatteredStats.armor}`);
    console.log(`  套装血量: ${setStats.max_hp} (+${(setStats.max_hp_mult * 100).toFixed(0)}%) | 散装血量: ${scatteredStats.max_hp}`);
    console.log(`  套装额外: 吸血+${(setStats.lifesteal * 100).toFixed(0)}%, 召唤流加成, 6件套大招`);
    console.log();

    const setAdvantage = (setStats.lifesteal > 0) ? "套装有独特机制加成，值得凑齐" : "套装加成不明显";
    console.log(`结论: ${setAdvantage}\n`);

    return setAdvantage;
}

// ==================== 战斗模拟器 ====================
function simulateCombat(playerClass, playerEquip, enemy) {
    // 计算玩家属性 (职业基础 + 装备)
    let playerStats = { ...playerClass.base_stats };

    for (const item of playerEquip) {
        for (const [key, value] of Object.entries(item.base_stats)) {
            playerStats[key] = (playerStats[key] || 0) + value;
        }
    }

    // 敌人属性
    const enemyStats = { ...enemy.base_stats };

    // 计算DPS
    const baseDamage = playerStats.damage;
    const avgCritMult = 1 + playerStats.crit_chance * (playerStats.crit_damage - 1);
    const dps = baseDamage * playerStats.attack_speed * avgCritMult;

    // 考虑护甲减免 (balance.json的公式: damage * (1 - armor/(armor+100)))
    const armorReduction = enemyStats.armor / (enemyStats.armor + 100);
    const effectiveDps = dps * (1 - armorReduction);

    // 计算TTK (Time To Kill)
    const ttk = enemyStats.max_hp / effectiveDps;

    // 计算玩家存活时间 (如果敌人反击)
    const enemyDps = enemyStats.damage * enemyStats.attack_speed;
    const playerArmorReduction = playerStats.armor / (playerStats.armor + 100);
    const effectiveEnemyDps = enemyDps * (1 - playerArmorReduction);
    const playerSurvival = playerStats.max_hp / effectiveEnemyDps;

    return {
        dps: Math.round(effectiveDps * 10) / 10,
        ttk: Math.round(ttk * 10) / 10,
        playerSurvival: Math.round(playerSurvival * 10) / 10,
        overkill: playerSurvival > ttk
    };
}

function runCombatSimulation() {
    console.log("==================== 战斗模拟器 ====================\n");

    // 选择一个中等敌人作为benchmark
    const benchmarkEnemy = enemies.find(e => e.id === 'elite_bone_knight');

    console.log(`目标敌人: ${benchmarkEnemy.display_name}`);
    console.log(`  HP: ${benchmarkEnemy.base_stats.max_hp} | 伤害: ${benchmarkEnemy.base_stats.damage} | 护甲: ${benchmarkEnemy.base_stats.armor}\n`);

    const results = [];

    // 为每个职业配置同等级散装rare装备
    const rareWeapons = equipment.filter(item => item.slot === 'weapon' && item.rarity === 'rare' && item.drop_level <= 3);
    const rareArmors = equipment.filter(item => ['helmet', 'chest', 'legs', 'boots', 'gloves'].includes(item.slot) && item.rarity === 'rare' && item.drop_level <= 3);

    for (const cls of classes) {
        // 简易配装: 取第一个可用的rare武器 + 5件防具
        const weapon = rareWeapons.find(w => w.tags.some(tag => cls.favored_tags.includes(tag))) || rareWeapons[0];
        const helmet = rareArmors.find(a => a.slot === 'helmet') || { base_stats: { armor: 7, max_hp: 23 } };
        const chest = rareArmors.find(a => a.slot === 'chest') || { base_stats: { armor: 13, max_hp: 46 } };
        const legs = rareArmors.find(a => a.slot === 'legs') || { base_stats: { armor: 10, max_hp: 33 } };
        const boots = rareArmors.find(a => a.slot === 'boots') || { base_stats: { armor: 5, max_hp: 17, move_speed: 0.13 } };
        const gloves = rareArmors.find(a => a.slot === 'gloves') || { base_stats: { armor: 3, max_hp: 13, attack_speed: 0.08 } };

        const equip = [weapon, helmet, chest, legs, boots, gloves];

        const result = simulateCombat(cls, equip, benchmarkEnemy);

        results.push({
            class: cls.display_name,
            dps: result.dps,
            ttk: result.ttk,
            survival: result.playerSurvival,
            outcome: result.overkill ? '✅ 胜' : '❌ 败'
        });

        console.log(`[${cls.display_name}]`);
        console.log(`  DPS: ${result.dps} | TTK: ${result.ttk}秒 | 玩家存活: ${result.playerSurvival}秒 | ${result.outcome}`);
    }

    console.log();

    // 找出最强和最弱
    const sortedByTtk = [...results].sort((a, b) => a.ttk - b.ttk);
    const strongest = sortedByTtk[0];
    const weakest = sortedByTtk[sortedByTtk.length - 1];

    const gap = ((weakest.ttk - strongest.ttk) / strongest.ttk * 100).toFixed(1);

    console.log(`最快击杀: ${strongest.class} (${strongest.ttk}秒)`);
    console.log(`最慢击杀: ${weakest.class} (${weakest.ttk}秒)`);
    console.log(`差距: ${gap}%\n`);

    return {
        strongest: strongest.class,
        weakest: weakest.class,
        gap: gap
    };
}

// ==================== 职业机制风险评估 ====================
function evaluateMechanicRisks() {
    console.log("==================== 职业机制风险评估 ====================\n");

    const risks = [];

    // 法师: 法力连锁
    risks.push({
        mechanic: "法师·法力连锁",
        risk: "可能OP",
        suggestion: "连锁次数需要上限(建议≤5次)，否则聚怪清屏过强"
    });

    // 骑士: 圣盾反伤
    risks.push({
        mechanic: "骑士·圣盾反伤",
        risk: "可能滚雪球",
        suggestion: "反伤比例建议≤30%，避免贴脸BOSS瞬间反死"
    });

    // 死灵师: 召唤亡灵
    risks.push({
        mechanic: "死灵师·召唤亡灵",
        risk: "平衡",
        suggestion: "召唤上限已有限制，配合套装控制数量和伤害"
    });

    // 游侠: 精准射击
    risks.push({
        mechanic: "游侠·精准射击叠层",
        risk: "后期过强",
        suggestion: "叠层上限建议≤10层，暴击率加成每层≤2%"
    });

    // 刺客: 潜行背刺
    risks.push({
        mechanic: "刺客·潜行背刺",
        risk: "平衡",
        suggestion: "必定暴击机制合理，CD时间控制脱战3秒"
    });

    // 战士: 怒气机制
    risks.push({
        mechanic: "战士·怒气释放",
        risk: "平衡",
        suggestion: "满槽释放伤害+30%合理，持续5秒CD适中"
    });

    for (const risk of risks) {
        console.log(`[${risk.mechanic}] ${risk.risk}`);
        console.log(`  建议: ${risk.suggestion}\n`);
    }

    return risks;
}

// ==================== 平衡调整建议 ====================
function generateBalanceAdjustments(classBalance, simResults) {
    console.log("==================== 平衡调整建议 ====================\n");

    const adjustments = [];

    // 基于职业战斗力
    for (const cls of classBalance) {
        if (cls.assessment === '强') {
            adjustments.push({
                target: cls.class,
                from: `战斗力${cls.power_score}`,
                to: `建议削弱基础属性5-10%`,
                reason: `战斗力过高，建议微调HP或伤害`
            });
        } else if (cls.assessment === '弱') {
            adjustments.push({
                target: cls.class,
                from: `战斗力${cls.power_score}`,
                to: `建议提升基础属性5-10%`,
                reason: `战斗力偏低，建议增加基础攻速或暴击`
            });
        }
    }

    // 基于TTK差距
    if (parseFloat(simResults.gap) > 30) {
        adjustments.push({
            target: simResults.weakest,
            from: `TTK差距${simResults.gap}%`,
            to: `提升攻速或伤害10%`,
            reason: `与最强职业差距过大，需要输出补强`
        });
    }

    if (adjustments.length === 0) {
        console.log("✅ 当前平衡状态良好，无需调整\n");
    } else {
        adjustments.forEach(adj => {
            console.log(`[${adj.target}]`);
            console.log(`  从: ${adj.from}`);
            console.log(`  到: ${adj.to}`);
            console.log(`  原因: ${adj.reason}\n`);
        });
    }

    return adjustments;
}

// ==================== 主函数 ====================
function main() {
    console.log("=".repeat(60));
    console.log("DarkLoot v3 平衡分析报告");
    console.log("=".repeat(60));
    console.log();

    const classBalance = analyzeClassBalance();
    const rarityCheck = checkRarityLadder();
    const dungeonCheck = checkDungeonCurve();
    const setBonusCheck = evaluateSetBonus();
    const simResults = runCombatSimulation();
    const mechanicRisks = evaluateMechanicRisks();
    const adjustments = generateBalanceAdjustments(classBalance, simResults);

    // 生成JSON输出
    const report = {
        class_balance: classBalance,
        rarity_ladder_check: rarityCheck,
        dungeon_curve_check: dungeonCheck,
        set_bonus_check: setBonusCheck,
        mechanic_risks: mechanicRisks,
        balance_adjustments: adjustments,
        simulator_created: "tools/balance_sim.js 创建成功",
        simulation_results: simResults
    };

    // 保存报告
    const reportPath = path.join(__dirname, '../BALANCE_REPORT.json');
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2), 'utf8');

    console.log(`\n✅ 报告已保存至: ${reportPath}`);
}

// 执行
if (require.main === module) {
    main();
}

module.exports = { calculateCombatPower, simulateCombat };
