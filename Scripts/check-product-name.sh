#!/usr/bin/env bash
# 产品名在四个地方出现，其中两处在 Swift 里、两处在构建配置里。
# 配置那两处编译器管不到 —— 改名时只改 Swift，桌面图标下面还是旧名字，
# 而且要装到真机上才看得见。所以用一次 grep 把四处钉在一起。
#
# 用法：Scripts/check-product-name.sh
set -uo pipefail
cd "$(dirname "$0")/.."

STRINGS="Packages/CountdownCore/Sources/CountdownKit/Strings/Strings.swift"
name=$(grep -oE 'public static let productName = "[^"]+"' "$STRINGS" | sed 's/.*= "//; s/"//')

if [ -z "$name" ]; then
  echo "✗ 没能从 $STRINGS 解析出 Strings.productName"
  exit 1
fi

fail=0
count=$(grep -cE "CFBundleDisplayName: \"$name\"" project.yml || true)
if [ "$count" -ne 2 ]; then
  echo "✗ project.yml 里与「$name」一致的 CFBundleDisplayName 有 $count 处，应为 2 处（App + 小组件）"
  fail=1
fi

if grep -q '待补文案：产品名' project.yml Packages/CountdownCore/Sources/CountdownKit/Strings/Strings.swift; then
  echo "✗ 还有地方留着产品名的占位符"
  fail=1
fi

[ "$fail" -ne 0 ] && exit 1
echo "✓ 产品名「$name」在 Swift 与 project.yml 四处一致"
