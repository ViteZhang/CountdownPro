#!/usr/bin/env bash
# 设计决策 D-10：首次启动引导中不得出现任何登录入口。
#
# 这条约束靠人眼 review 守不住 —— 有人加一行 import 就破了，而且看起来很合理。
# 所以把它变成一次 grep：引导流程的源文件不得引用任何 Auth 符号。
#
# 用法：Scripts/check-onboarding-isolation.sh
set -uo pipefail
cd "$(dirname "$0")/.."

ONBOARDING_FILES="CountdownPro/Onboarding"
FORBIDDEN='AuthFlowView|AuthPromptSheet|AuthService|LoginMethod|AuthPromptTrigger|AccountView|BindType|Strings\.Auth'

if [ ! -d "$ONBOARDING_FILES" ]; then
  echo "找不到引导目录：$ONBOARDING_FILES"
  exit 1
fi

hits=$(grep -REn "$FORBIDDEN" "$ONBOARDING_FILES" || true)

if [ -n "$hits" ]; then
  echo "✗ D-10 被破坏：引导流程引用了账号 / 登录符号"
  echo ""
  echo "$hits"
  echo ""
  echo "账号是保险箱，不是入场券。登录只能在价值时刻引导（见 5.14.1）。"
  exit 1
fi

echo "✓ D-10：引导流程未引用任何账号 / 登录符号"
