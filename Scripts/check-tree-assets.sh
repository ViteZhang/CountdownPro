#!/usr/bin/env bash
# 树的七张图必须真的在包里，且文件名与 `GrowthStage.assetName` 对得上。
#
# 为什么要一个脚本：图读不出来时 SwiftUI 不报错、不崩、不打日志，界面上只是少一棵树。
# 这个失败模式已经跑掉过一次 —— 美术改个文件名、或者 Package.swift 的资源规则被动过，
# 都不会有任何东西提醒你。所以把"文件在不在"变成一次可执行的核对。
#
# 用法：Scripts/check-tree-assets.sh
set -uo pipefail
cd "$(dirname "$0")/.."

TREE_DIR="Packages/CountdownCore/Sources/CountdownUI/Resources/Tree"
TREE_VIEW="Packages/CountdownCore/Sources/CountdownUI/TreeView.swift"
PACKAGE="Packages/CountdownCore/Package.swift"
fail=0

# 1. 资源规则必须保住 Tree/ 这一层目录。读取端按 subdirectory 取，压平了就取不到。
if ! grep -q '\.copy("Resources/Tree")' "$PACKAGE"; then
  echo "✗ Package.swift 里 CountdownUI 的资源规则不是 .copy(\"Resources/Tree\")"
  echo "  TreeView 按 subdirectory: \"Tree\" 读文件，换成 .process 后目录是否被压平不确定。"
  fail=1
fi

# 2. assetName 里列的每一个名字都必须有对应文件。
names=$(grep -oE 'return "[a-z]+"' "$TREE_VIEW" | sed 's/return "//; s/"//' | sort -u)
if [ -z "$names" ]; then
  echo "✗ 没能从 $TREE_VIEW 里解析出 assetName 的映射"
  exit 1
fi

count=0
for name in $names; do
  count=$((count + 1))
  if [ ! -f "$TREE_DIR/$name.png" ]; then
    echo "✗ GrowthStage.assetName 里有 \"$name\"，但 $TREE_DIR/$name.png 不存在"
    fail=1
  fi
done

if [ "$count" -ne 7 ]; then
  echo "✗ assetName 解析出 $count 个名字，应为 7 个（七个成长阶段）"
  fail=1
fi

# 3. 反过来：目录里不该有对不上任何阶段的多余文件 —— 那通常意味着交付重命名了，
#    而映射没跟着改，于是旧图还在、新图没人读。
for f in "$TREE_DIR"/*.png; do
  [ -e "$f" ] || continue
  base=$(basename "$f" .png)
  if ! echo "$names" | grep -qx "$base"; then
    echo "✗ $f 没有任何成长阶段引用它（映射写在 GrowthStage.assetName）"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "✓ 树的七张图齐全，文件名与 GrowthStage.assetName 一致"
