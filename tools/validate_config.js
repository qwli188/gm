#!/usr/bin/env node
/**
 * DarkLoot v3 配置校验器（纯 Node.js，零依赖）
 * 用法：node tools/validate_config.js
 * 退出码：0=通过，1=有错误
 */

const fs = require('fs');
const path = require('path');

const CONFIG_ROOT = path.join(__dirname, '../project/src/config');

// 加载配置
function loadJSON(filename) {
  const filepath = path.join(CONFIG_ROOT, filename);
  if (!fs.existsSync(filepath)) {
    console.error(`❌ 配置文件不存在: ${filename}`);
    process.exit(1);
  }
  return JSON.parse(fs.readFileSync(filepath, 'utf-8'));
}

const schema = loadJSON('_schema_standard.json');
const equipment = loadJSON('equipment.json');
const affixes = loadJSON('affixes.json');
const skills = loadJSON('skills.json');
const enemies = loadJSON('enemies.json');
const classes = loadJSON('classes.json');
const dungeons = loadJSON('dungeons.json');
const waves = loadJSON('waves.json');
const sets = loadJSON('sets.json');

let errors = [];
let warnings = [];

// 1. 引用完整性检查
function checkReferences() {
  const affixIds = new Set(affixes.affixes.map(a => a.id));
  const setIds = new Set(sets.sets.map(s => s.id));
  const classIds = new Set(classes.classes.map(c => c.id));
  const enemyIds = new Set(enemies.enemies.map(e => e.id));
  const waveIds = new Set(waves.wave_sets.map(w => w.id));
  const skillIds = new Set(skills.skills.map(s => s.id));
  const eqIds = new Set(equipment.items.map(e => e.id));

  // 装备 → 词缀/套装
  for (const item of equipment.items) {
    for (const affixId of (item.fixed_affixes || [])) {
      if (!affixIds.has(affixId)) {
        errors.push(`装备 ${item.id} 引用不存在词缀 ${affixId}`);
      }
    }
    if (item.set_id && !setIds.has(item.set_id)) {
      errors.push(`装备 ${item.id} 引用不存在套装 ${item.set_id}`);
    }
  }

  // 职业 → 起手武器
  for (const cls of classes.classes) {
    if (cls.starting_weapon && !eqIds.has(cls.starting_weapon)) {
      errors.push(`职业 ${cls.id} 起手武器不存在 ${cls.starting_weapon}`);
    }
  }

  // 技能 → class
  for (const skill of skills.skills) {
    const cls = skill.class;
    if (cls && cls !== 'all' && !classIds.has(cls)) {
      errors.push(`技能 ${skill.id} class=${cls} 不存在`);
    }
  }

  // 副本 → wave_set
  for (const dungeon of dungeons.dungeons) {
    if (dungeon.wave_set && !waveIds.has(dungeon.wave_set)) {
      errors.push(`副本 ${dungeon.id} wave_set 不存在 ${dungeon.wave_set}`);
    }
  }

  // 波次 → 敌人（递归遍历 waves 结构）
  function collectEnemyRefs(obj, waveSetId) {
    if (Array.isArray(obj)) {
      obj.forEach(item => collectEnemyRefs(item, waveSetId));
    } else if (obj && typeof obj === 'object') {
      for (const [key, val] of Object.entries(obj)) {
        if (key === 'enemy_id' && typeof val === 'string' && val.startsWith('enemy_')) {
          if (!enemyIds.has(val)) {
            errors.push(`波次 ${waveSetId} 引用不存在敌人 ${val}`);
          }
        } else {
          collectEnemyRefs(val, waveSetId);
        }
      }
    }
  }
  for (const waveSet of waves.wave_sets) {
    collectEnemyRefs(waveSet, waveSet.id);
  }
}

// 2. ID 唯一性检查
function checkUniqueIds() {
  const allIds = {};

  function collect(items, source) {
    for (const item of items) {
      const id = item.id;
      if (id) {
        if (!allIds[id]) allIds[id] = [];
        allIds[id].push(source);
      }
    }
  }

  collect(equipment.items, 'equipment');
  collect(affixes.affixes, 'affixes');
  collect(skills.skills, 'skills');
  collect(enemies.enemies, 'enemies');
  collect(classes.classes, 'classes');
  collect(dungeons.dungeons, 'dungeons');
  collect(sets.sets, 'sets');
  collect(waves.wave_sets, 'wave_sets');

  for (const [id, sources] of Object.entries(allIds)) {
    if (sources.length > 1) {
      errors.push(`重复 ID: ${id} 出现在 ${sources.join(', ')}`);
    }
  }
}

// 3. 必填字段检查
function checkRequiredFields() {
  const required = schema.config_required_fields;
  const requiredAll = required.all || [];

  function check(items, type, specificRequired) {
    const fields = [...requiredAll, ...(specificRequired || [])];
    for (const item of items) {
      for (const field of fields) {
        if (!(field in item)) {
          errors.push(`${type}[${item.id || '?'}] 缺少必填字段: ${field}`);
        }
      }
    }
  }

  check(equipment.items, 'equipment', required.equipment);
  check(affixes.affixes, 'affixes', required.affixes);
  check(skills.skills, 'skills', required.skills);
  check(enemies.enemies, 'enemies', required.enemies);
  check(dungeons.dungeons, 'dungeons', required.dungeons);
  check(sets.sets, 'sets', required.sets);
}

// 执行所有检查
checkReferences();
checkUniqueIds();
checkRequiredFields();

// 输出结果
if (errors.length === 0 && warnings.length === 0) {
  console.log('✅ All checks passed');
  console.log(`   ${equipment.items.length} 装备, ${affixes.affixes.length} 词缀, ${skills.skills.length} 技能, ${enemies.enemies.length} 敌人, ${dungeons.dungeons.length} 副本, ${sets.sets.length} 套装`);
  process.exit(0);
} else {
  if (errors.length > 0) {
    console.log(`❌ 发现 ${errors.length} 个错误：`);
    errors.forEach(e => console.log(`  - ${e}`));
  }
  if (warnings.length > 0) {
    console.log(`⚠️  发现 ${warnings.length} 个警告：`);
    warnings.forEach(w => console.log(`  - ${w}`));
  }
  process.exit(1);
}
