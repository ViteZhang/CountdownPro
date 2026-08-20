# 备考倒计时 · V1

SwiftUI + SwiftData，iOS 原生。小组件必须原生实现，所以不走跨平台方案。

## 这份文件的作用

不是描述产品长什么样（那是需求文档和原型的事），而是记录**为什么长成这样**。

交接时最容易丢的就是"为什么"。一旦丢了，后续迭代会把这个产品一步步改回一个普通倒计时
——每一步看起来都很合理。

## 目录结构

```
Packages/CountdownCore/          本地 SPM 包，App 与 Widget 共用
  Sources/
    CountdownKit/                纯 Foundation。可在任意平台跑测试
      Domain/                    ExamType / GrowthStage / Milestone / AppFlagKey / LetterVault
      DateEngine/                DayCalendar / Countdown / DefaultDates
      Format/                    CensusFormatter / DateDisplay / PhoneMask
      Strings/                   全部面向用户的文案
      Sync/                      ExportSnapshot / MergeRules
      Widget/                    WidgetTimeline（预生成 7 天的纯逻辑）
    DesignTokens/                颜色、字号字重、圆角间距、动效时长
    CountdownUI/                 App 与 Widget 共用的视图：环 / 进度条 / 树
    CountdownStore/              SwiftData 模型 + App Group 配置 + Keychain 加密
  Tests/                         104 个测试，`swift test`
CountdownPro/                    App target
CountdownWidgets/                Widget Extension（四种）
project.yml                      XcodeGen 工程描述
```

## 硬约束（改动前请先读完对应的决策条目）

### 本地优先
所有数据先写本地，账号只是同步凭证，不是使用前提。未登录状态下全部功能可用，包括离线。
唯一需要网络的是同考人数（以及用户主动进入的账号流程）。

> 注：需求文档第 6 章写「网络请求：仅一个」，那一章写于加入 5.14 账号章节之前。
> 实现口径是：**未登录时确实只有同考人数一个请求**；登录相关请求仅在用户主动进入账号流程后发生。

### 有账号但没有注册墙（D-10）
**首次启动引导中不得出现任何登录入口。** 引导流程的代码不引用任何 Auth 符号，物理隔离。
这条靠人眼 review 守不住（加一行 import 就破了，而且看起来很合理），所以有一个 grep 守着：

```bash
Scripts/check-onboarding-isolation.sh
```
登录只在价值时刻引导（写完第一封信 / 累计 7 天 / 主动导出 / 考后接力），且都可关闭，
每个触发点一生只弹一次（`AppFlagKey.AuthPrompt`）。

账号是保险箱，不是入场券。

### 同步失败不得阻塞任何功能
静默重试，不弹错误。同步层全部在后台任务里跑，失败不冒泡到 UI。

### 同考人数保持匿名（D-09）
纯计数上报，不携带设备标识、不关联 uid。低于 1 万整块隐藏。
`CensusFormatter.display` 对「不足 1 万」和「拉不到」**返回同一个 nil**，
让调用方无法区分，也就无从为失败单独做错误态或骨架屏。

绝不允许编造、放大、或用"累计人次"冒充"今日人数"。这个产品除了信任没有别的护城河。

### 不存储任何可推导的值
累计天数、进度、成长阶段都实时计算（`CountdownEngine.countdown`）。
导出的 JSON 同样只含事实，不含结论（有测试守着）。

## 决策记录速查

| | 决策 | 代码里的落点 |
|---|---|---|
| D-01 | 环填充=已走过，中心=剩余 | `Countdown.progress`、`DSRing.fillIsPassedRatio` |
| D-02 | 「今天也在」不叫「打卡」 | `Strings.Home.checkIn`，有测试锁住 |
| D-03 | 只做累计，不做连续 | 数据层**根本不提供** streak 查询；同步取并集保证只增不减 |
| D-04 | 补签 14 天 | `CountdownEngine.backfillWindowDays` |
| D-05 | 树只与时间有关 | `GrowthStage.stage(progress:isExamDay:)` 的签名里**没有打卡数** |
| D-06 | 唯一彩色留给树 | `Palette`，有彩度测试守着 |
| D-07 | 不用纯黑纯白 | `Palette.defaultDark/Light`，有对比度测试守着 |
| D-08 | 封存的信不可查看 | `LetterVault.reveal` 要求交出 `LetterAccess` 凭证，`.sealed` 必然携带开启日 |
| D-09 | <1 万整块隐藏 | `CensusFormatter` |
| D-10 | 做账号不做注册墙 | 引导流程不 import Auth |
| D-11 | 分享卡不放二维码 | `ShareCardContent.passedProgress` 非可选，有测试守着 |
| D-12 | 备考期零广告 | — |
| D-13 | 不做社区/排名/成绩对比 | — |
| D-14 | 先说"已经走过"，再说"还剩" | `Strings.Onboarding.resultLabel` |

## 最容易在评审中被"优化"掉的七处

每一条都合理，每一条都会让产品变成它试图区别于的那个东西。

1. 加「连续打卡」——因为几乎所有同类产品都有。见 D-03。
2. 树能浇水互动——因为"提升活跃"。见 D-05。
3. 分享卡加二维码——因为"方便下载"。见 D-11。
4. 加班级榜 / 好友对比——因为"社交裂变"。见 D-13。
5. 同考人数取整放大——因为"冷启动不好看"。见 D-09。
6. 备考期加激励视频广告——因为"提前变现"。见 D-12。
7. 把登录提到首启第一屏——因为"提升注册率"。注册率会涨，留存会崩。见 D-10。

## 登录方式由策略函数决定，不由视图列举

`LoginMethodPolicy.methods(platform:entity:)` 是唯一的真相源。
**iOS 端无条件带 Sign in with Apple** —— 审核指南 4.8 要求「有第三方登录就必须有 Apple」，
需求文档 5.14.2 又规定个人主体也要做「手机号 + Apple」，合起来就是无条件。
视图只渲染这个函数返回的列表，所以不存在"某个入口忘了加 Apple"导致拒审的可能。

当前主体：**企业**，四种方式全开（微信 → QQ → 手机号 → Apple，微信为主按钮）。

## 同步失败不得阻塞任何功能

`SyncCoordinator` 的公开方法**一个都不抛错** —— 调用方拿不到失败，
也就无法把失败暴露到 UI 上。这不是偷懒，是把约束写进类型里。

## 开屏最多弹一个全屏提示

5.8.2 让节点日弹分享卡，信件文案表 5.1 让到期日弹拆信提示 —— 同一天可能都命中。
`AppOpenPromptResolver` 是唯一的裁决者：**信件优先**（信不可重建，卡片随时能手动生成），
且最多返回一个。各弹各的会让用户连吃两个全屏。

「待会儿」记的是**最后推迟的日期**而非布尔值 —— 规则是当天不再弹、次日再触发，
直到被拆开。

## 分享卡的三类差异

5.8.3 要求三类卡"明显不同"，但 D-06 规定全界面灰阶、唯一彩色留给树。
所以差异只能来自**版式**（大数字主导 / 引文主导 / 终局）与**底色层级**
（基底 / 卡片 / 升起卡片），不能靠加彩色。若评审认为区分度不够，
解法仍在 `DesignTokens`，不在卡片视图里。

## 未来信件的三条硬规则

1. **封存不可逆。** 草稿可查看可修改，`isDraft` 一旦置 false 就回不去。
   同步合并时一端已封存、另一端还是草稿 → 结果必然是已封存，且**不看 `updatedAt`**。
   否则同步会把一封已经托付出去的信变回可编辑。
2. **解密只有一个入口。** `LetterVault.reveal` 要求调用方交出 `LetterAccess`，
   而 `.sealed` 这个 case 必须携带开启日 —— 不存在"传个假日期绕过去"的写法。
   唯一构造它的地方是 `Letter.access`，直接读 `letter.openAt`。
3. **遮盖不能泄露信息。** 封存中的信用实心方块，不用模糊或马赛克
   （模糊暗示"看得到但看不清"，会诱发用户去试）。方块数只分 5 档，
   使其无法反推字数 —— 否则遮盖本身就漏了。

## 文案规则

所有面向用户的文字**逐字**使用资料给定的版本，不要"优化"。
按钮是「今天也在」不是「打卡」，这是刻意的。

信件相关文案见《未来信件 · 完整文案表》，已全部接入，并有一条测试把该文档第 9 节的
禁区清单钉成断言（亲爱的自己 / 时光胶囊 / 见证你的成长 / 相信努力会有回报 / 恭喜 /
保存成功 / 抱歉 / 加油）。它拦的不是拼写，是语气。

资料没给的文案一律走 `Strings.missing(_:)`，渲染成 `⟪待补文案：xxx⟫`。
**禁止用自拟文案填充它。** 待补清单见 `DOCS/待补文案清单.md`。

心理支持资源的热线信息必须来源权威，绝不自拟。

兜底校验法：把任何一句文案放进「一个刚查完分、没考好的学生正看着屏幕」的场景里读一遍。
读着刺耳，就重写。

## 视图层规则

视图层**只能引用 token**，禁止字面量颜色值和 magic number 尺寸。
视觉后续会用 Claude Design 精修，改动必须只发生在 `DesignTokens` 这一层。

## 打开工程

Xcode 工程由 XcodeGen 生成，`.xcodeproj` **不入库**（避免 `.pbxproj` 的合并冲突）：

```bash
brew install xcodegen
xcodegen generate
open CountdownPro.xcodeproj
```

App 与 Widget 两个 target 必须使用**同一个 App Group**，否则小组件读不到数据
（表现为永远的占位态）。三处要一致：两个 `.entitlements` 与 `StoreConfiguration.shared`。

## 跑测试

```bash
cd Packages/CountdownCore && swift test
```

`CountdownKit` 与 `DesignTokens` 是纯 Foundation，Linux / macOS 都能跑。
`CountdownStore` 与 `CountdownUI` 依赖 SwiftData / SwiftUI，只在 Apple 平台编译，
**Linux 上这两个 target 会被条件编译整体跳过** —— 在 Linux 上 build 通过不代表它们没问题，
必须在 Xcode 里验一次。

## 小组件的两条硬规则

1. **完全离线。** Timeline 预生成未来 7 天的 entry（`WidgetTimelineBuilder`），
   数据全部来自 App Group 内的本地存储，小组件从不发起网络请求、也从不解密信件。
2. **同考人数只出现在"今天"那一条 entry 上。** 缓存里的数字是今天的人数，
   铺到未来 6 天，小组件就会在明天用昨天的数据说「今天有 41.2 万人和你一起」——
   那正是 D-09 禁止的事。未来的 entry 一律隐藏该模块。缓存本身也带日期戳，隔夜不采用。

锁屏组件会被系统去色，所以 `CircularWidgetView` / `RectangularWidgetView`
**刻意不引用 Palette**，全部走 `.primary` / `.tertiary` 交给系统染色管线 ——
引用了 palette 反而会在去色后糊成一团。
