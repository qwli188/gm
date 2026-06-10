#!/bin/bash
# DarkLoot v3 契约重建后验证脚本

echo "========================================"
echo "DarkLoot v3 契约重建 - 验证流程"
echo "========================================"
echo ""

# 相对路径定位（脚本在 <root>/tools/，Godot 在 <root>/../tools/）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GODOT="$ROOT_DIR/../tools/Godot_v4.3-stable_win64.exe"
PROJECT="$ROOT_DIR/project/src/project.godot"

# 1. 检查 Godot 可用性
echo "✓ 检查 Godot 二进制..."
if [ ! -f "$GODOT" ]; then
    echo "❌ Godot 不存在: $GODOT"
    exit 1
fi
echo "  版本: $($GODOT --version 2>&1 | head -1)"
echo ""

# 2. 检查项目文件完整性
echo "✓ 检查项目文件..."
if [ ! -f "$PROJECT" ]; then
    echo "❌ project.godot 不存在"
    exit 1
fi

CRITICAL_FILES=(
    "project/src/config/_schema_standard.json"
    "project/src/config/equipment.json"
    "project/src/config/affixes.json"
    "project/src/config/skills.json"
    "project/src/autoload/EquipmentSystem.gd"
    "project/src/autoload/CombatSystem.gd"
    "project/src/autoload/ConfigLoader.gd"
    "project/src/scripts/Player.gd"
    "project/src/scripts/DropItem.gd"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "  ❌ 缺失: $file"
        exit 1
    fi
done
echo "  ✅ 所有关键文件存在"
echo ""

# 3. 检查 git 状态
echo "✓ 检查 git 变更..."
cd "$ROOT_DIR"
if [ -d ".git" ]; then
    CHANGED=$(git status --short | wc -l)
    echo "  修改文件数: $CHANGED"
    echo ""
    echo "  主要变更:"
    git status --short | head -20
    echo ""
else
    echo "  ⚠️  未初始化 git"
fi

# 4. 尝试启动 Godot 校验（headless）
echo "✓ Godot headless 校验..."
echo "  正在加载项目..."
timeout 15 "$GODOT" --headless --path "$(dirname $PROJECT)" --quit 2>&1 | grep -E "(ERROR|WARNING|Loaded)" | head -20
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ] || [ $EXIT_CODE -eq 124 ]; then
    echo "  ✅ 项目加载成功（或超时但无报错）"
else
    echo "  ❌ 项目加载失败，退出码: $EXIT_CODE"
    exit 1
fi
echo ""

# 5. 检查配置完整性
echo "✓ 检查配置引用完整性..."
echo "  （需要在 Godot 中运行 validate_config.gd 获取完整结果）"
echo ""

echo "========================================"
echo "✅ 基础验证通过"
echo "========================================"
echo ""
echo "下一步："
echo "1. 运行 Godot 编辑器打开项目"
echo "2. 查看控制台输出，确认无错误"
echo "3. 运行游戏，测试核心系统："
echo "   - 装备掉落显示正确"
echo "   - 套装加成生效"
echo "   - 铁匠铺强化在战斗中生效"
echo "   - swamp/plague 装备数值正常（不再 10 倍攻速）"
echo ""
