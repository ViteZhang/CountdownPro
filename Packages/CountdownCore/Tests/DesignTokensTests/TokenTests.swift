import XCTest
@testable import DesignTokens

/// 设计代币不是"样式建议"，是产品决策的载体。这些断言守的是决策，不是数值。
final class PaletteTests: XCTestCase {

    /// 四套皮肤 × 深浅两态 = 八套色板。**每条规则都对八套逐一断言。**
    ///
    /// 只验默认那一套是这类测试最常见的漏法：新皮肤上线时没人会想起来
    /// "那条对比度测试只覆盖了深空"，于是第三套皮肤的次文字悄悄掉到 3:1。
    private static let allPalettes: [(String, Palette)] = [
        ("深空·深", .deepSpaceDark),   ("深空·浅", .deepSpaceLight),
        ("晨雾·深", .morningMistDark), ("晨雾·浅", .morningMistLight),
        ("夜潮·深", .nightTideDark),   ("夜潮·浅", .nightTideLight),
        ("旧纸·深", .oldPaperDark),    ("旧纸·浅", .oldPaperLight),
    ]

    private static let darkPalettes: [(String, Palette)] = [
        ("深空·深", .deepSpaceDark),   ("晨雾·深", .morningMistDark),
        ("夜潮·深", .nightTideDark),   ("旧纸·深", .oldPaperDark),
    ]

    private static let lightPalettes: [(String, Palette)] = [
        ("深空·浅", .deepSpaceLight),  ("晨雾·浅", .morningMistLight),
        ("夜潮·浅", .nightTideLight),  ("旧纸·浅", .oldPaperLight),
    ]

    /// 设计决策 D-07：基底不用纯黑，文字不用纯白。
    /// 纯黑在 OLED 上滚动拖影；21:1 对比度下中文笔画会产生光晕；
    /// 且纯黑没有"更深"的余地，层级只能往亮里走，界面会一层层浮起来。
    func testNoPureBlackOrPureWhiteInAnySkin() {
        for (name, p) in Self.allPalettes {
            XCTAssertNotEqual(p.background.hex, 0x000000, name)
            XCTAssertNotEqual(p.background.hex, 0xFFFFFF, name)
            XCTAssertNotEqual(p.textPrimary.hex, 0xFFFFFF, name)
            XCTAssertNotEqual(p.textPrimary.hex, 0x000000, name)
        }
        // 深空这一套的具体值来自设计系统 1.1，钉死。
        XCTAssertEqual(Palette.deepSpaceDark.background.hexString, "#101114")
        XCTAssertEqual(Palette.deepSpaceDark.textPrimary.hexString, "#F2F4F7")
        XCTAssertEqual(Palette.deepSpaceLight.background.hexString, "#FAFAF8")
    }

    /// 主文字对比度：《V1 剩余页面》4.2 规定 ≥ 7:1（WCAG AAA），
    /// 同时 D-07 要求不得逼近纯黑白的 21:1。
    func testPrimaryTextContrastIsAAAButNotHarsh() {
        for (name, p) in Self.allPalettes {
            let ratio = p.textPrimary.contrastRatio(against: p.background)
            XCTAssertGreaterThanOrEqual(ratio, 7.0, "\(name) 主文字需达 AAA")
            XCTAssertLessThan(ratio, 19.0, "\(name) 不该逼近纯黑白的 21:1")
        }
    }

    /// 次文字 ≥ 4.5:1（《V1 剩余页面》4.2）。
    func testSecondaryTextMeetsAA() {
        for (name, p) in Self.allPalettes {
            XCTAssertGreaterThanOrEqual(
                p.textSecondary.contrastRatio(against: p.background), 4.5, name)
        }
    }

    /// 弱文字只承载可有可无的信息，按 UI 组件线的 3:1 要求。
    func testTertiaryTextClearsTheComponentThreshold() {
        for (name, p) in Self.allPalettes {
            XCTAssertGreaterThan(
                p.textTertiary.contrastRatio(against: p.background), 2.4, name)
        }
    }

    /// 设计系统 1.1：两套模式是同一个性格的一日两态，不是两套设计。
    func testDarkAndLightAreInverted() {
        for (name, p) in Self.darkPalettes {
            XCTAssertLessThan(p.background.relativeLuminance,
                              p.textPrimary.relativeLuminance, name)
        }
        for (name, p) in Self.lightPalettes {
            XCTAssertGreaterThan(p.background.relativeLuminance,
                                 p.textPrimary.relativeLuminance, name)
        }
    }

    /// 设计决策 D-06：全界面灰阶，唯一的彩色留给树。
    ///
    /// 判据是**相对的**，不是一个绝对阈值。皮肤的定义就是"换基底色温"，
    /// 晨雾的灰偏暖、夜潮的灰偏蓝，它们的彩度本来就比深空高 ——
    /// 拿深空那条绝对线去卡，等于禁止皮肤存在。
    ///
    /// 真正要守的是：**树在它自己那套色板里必须是最彩的那个，且甩开一截。**
    func testTreeIsTheMostSaturatedColorInEverySkin() {
        for (name, p) in Self.allPalettes {
            let neutrals = [p.background, p.surface, p.surfaceRaised, p.line,
                            p.textPrimary, p.textSecondary, p.textTertiary]
            let mostSaturatedNeutral = neutrals.max { $0.chroma < $1.chroma }!
            XCTAssertGreaterThan(
                p.tree.chroma, mostSaturatedNeutral.chroma * 1.4,
                "\(name)：树必须明显比最彩的灰阶色更彩（灰阶最高 \(mostSaturatedNeutral.hexString)）")
        }
    }

    /// 色温倾向可以有，但不能倾向到变成第二个彩色。
    func testNeutralsStayNeutralEvenWhenTinted() {
        for (name, p) in Self.allPalettes {
            for n in [p.background, p.surface, p.surfaceRaised, p.line,
                      p.textPrimary, p.textSecondary, p.textTertiary] {
                XCTAssertLessThan(n.chroma, 0.12,
                                  "\(name)：\(n.hexString) 已经不像灰了")
            }
        }
    }

    /// 树在四套里都不能变成枯色。
    ///
    /// 「把这一套皮肤的树改成褐色，视觉更协调」是评审里最容易通过的一条意见，
    /// 而枯褐色会被读作"树枯了" —— 那正是 D-05 禁止的：
    /// 树只与时间有关，不因用户表现枯萎。
    ///
    /// 上界 200° 同样是硬的：再冷就读作蓝色，树也就不是树了。
    func testTreeNeverGoesWitheredOrBlue() {
        for (name, p) in Self.allPalettes {
            guard let hue = p.tree.hueDegrees else {
                return XCTFail("\(name)：树不能是灰的")
            }
            XCTAssertGreaterThanOrEqual(hue, 70, "\(name)：树偏黄褐了（\(p.tree.hexString)）")
            XCTAssertLessThanOrEqual(hue, 200, "\(name)：树偏蓝了（\(p.tree.hexString)）")
        }
    }

    /// 警示色四套共用。
    /// 信号色跟着皮肤变，等于让用户每换一次皮肤重新学一遍红色代表什么。
    func testSignalColorsDoNotVaryBySkin() {
        for (name, p) in Self.darkPalettes {
            XCTAssertEqual(p.warning, Palette.deepSpaceDark.warning, name)
            XCTAssertEqual(p.danger, Palette.deepSpaceDark.danger, name)
        }
        for (name, p) in Self.lightPalettes {
            XCTAssertEqual(p.warning, Palette.deepSpaceLight.warning, name)
            XCTAssertEqual(p.danger, Palette.deepSpaceLight.danger, name)
        }
    }

    /// 八套色板两两不同 —— 否则"解锁了新皮肤但看不出区别"。
    func testEveryPaletteIsDistinct() {
        for i in Self.allPalettes.indices {
            for j in Self.allPalettes.indices where i < j {
                XCTAssertNotEqual(Self.allPalettes[i].1, Self.allPalettes[j].1,
                                  "\(Self.allPalettes[i].0) 与 \(Self.allPalettes[j].0) 完全一样")
            }
        }
    }

    /// 每个皮肤都必须真的映射到自己的色板。
    /// 曾经这里是"未定义就回落到默认" —— 那个回落一旦留着，
    /// 补了配色却忘了改映射的话，新皮肤会静默地长得和深空一样。
    func testEverySkinMapsToItsOwnPalette() {
        XCTAssertEqual(Skin.default.palette(.dark), .deepSpaceDark)
        XCTAssertEqual(Skin.second.palette(.dark), .morningMistDark)
        XCTAssertEqual(Skin.third.palette(.dark), .nightTideDark)
        XCTAssertEqual(Skin.fourth.palette(.dark), .oldPaperDark)
        XCTAssertEqual(Skin.default.palette(.light), .deepSpaceLight)
        XCTAssertEqual(Skin.second.palette(.light), .morningMistLight)
        XCTAssertEqual(Skin.third.palette(.light), .nightTideLight)
        XCTAssertEqual(Skin.fourth.palette(.light), .oldPaperLight)
    }
}

final class FontTokenTests: XCTestCase {

    /// 设计系统 1.2 的硬规则：字重按尺寸分档。
    func testWeightBySize() {
        XCTAssertEqual(DSFontWeight.weight(forPointSize: 11), 500)  // ≤12：中文笔画密，细体会糊
        XCTAssertEqual(DSFontWeight.weight(forPointSize: 12), 500)
        XCTAssertEqual(DSFontWeight.weight(forPointSize: 15), 400)  // 14–20
        XCTAssertEqual(DSFontWeight.weight(forPointSize: 20), 400)
        XCTAssertEqual(DSFontWeight.weight(forPointSize: 68), 200)  // ≥32：大数字用细体才有呼吸感
    }

    /// 字重不由调用方指定 —— 同一个字号在任何调用点都得到同一个字重。
    func testWeightIsDerivedNotSupplied() {
        XCTAssertEqual(DSFont.body(15).weight, DSFont.caption(15).weight)
        XCTAssertEqual(DSFont.display(68).weight, DSFont.title(68).weight)
    }

    /// 大数字统一负字距，且落在设计系统给的 [-4, -2] 区间内。
    func testBigNumberTracking() {
        XCTAssertEqual(DSFont.display(11).tracking, 0)
        XCTAssertEqual(DSFont.display(20).tracking, 0)
        for size in [32.0, 40, 56, 68, 82, 96] {
            let t = DSFont.display(size).tracking
            XCTAssertLessThanOrEqual(t, -2)
            XCTAssertGreaterThanOrEqual(t, -4)
        }
    }

    /// 大数字必须设动态字体上限，否则进度环中心数字在 AX5 下会撑爆环。
    func testBigNumbersCapDynamicType() {
        XCTAssertFalse(DSFont.display(68).allowsUnboundedScaling)
        XCTAssertTrue(DSFont.body(15).allowsUnboundedScaling)
        XCTAssertTrue(DSFont.caption(11).allowsUnboundedScaling)
    }

    /// 设计系统 1.2：产品说话用无衬线，用户说话用衬线。
    func testSerifIsReservedForUserWrittenContent() {
        XCTAssertEqual(DSFont.userWritten(15).family, .userWritten)
        for spec in [DSFont.body(15), DSFont.title(22), DSFont.caption(11), DSFont.display(68)] {
            XCTAssertEqual(spec.family, .ui)
        }
    }
}

final class SkinTests: XCTestCase {

    /// 需求文档 5.9：按累计打卡天数解锁，全部免费。
    func testUnlockThresholds() {
        XCTAssertEqual(Skin.default.unlockAtCheckInDays, 0)
        XCTAssertEqual(Skin.second.unlockAtCheckInDays, 30)
        XCTAssertEqual(Skin.third.unlockAtCheckInDays, 100)
        XCTAssertEqual(Skin.fourth.unlockAtCheckInDays, 200)
    }

    func testIsUnlocked() {
        XCTAssertTrue(Skin.default.isUnlocked(totalCheckIns: 0))
        XCTAssertFalse(Skin.second.isUnlocked(totalCheckIns: 29))
        XCTAssertTrue(Skin.second.isUnlocked(totalCheckIns: 30))
        XCTAssertTrue(Skin.fourth.isUnlocked(totalCheckIns: 500))
    }

    /// 解锁按**累计**打卡数，不是连续 —— D-03。
    func testNewlyUnlockedFiresExactlyOnceAtThreshold() {
        XCTAssertNil(Skin.newlyUnlocked(totalCheckIns: 29))
        XCTAssertEqual(Skin.newlyUnlocked(totalCheckIns: 30), .second)
        XCTAssertNil(Skin.newlyUnlocked(totalCheckIns: 31))
        XCTAssertEqual(Skin.newlyUnlocked(totalCheckIns: 100), .third)
        XCTAssertEqual(Skin.newlyUnlocked(totalCheckIns: 200), .fourth)
        XCTAssertNil(Skin.newlyUnlocked(totalCheckIns: 0))
    }

    /// 四套皮肤都有名字，且都不是占位符。
    func testEverySkinHasAName() {
        XCTAssertEqual(Skin.default.displayName, "深空")
        XCTAssertEqual(Skin.second.displayName, "晨雾")
        XCTAssertEqual(Skin.third.displayName, "夜潮")
        XCTAssertEqual(Skin.fourth.displayName, "旧纸")
        for skin in Skin.allCases {
            XCTAssertFalse(skin.displayName.contains("待补文案"), skin.displayName)
        }
    }

    /// 未解锁的皮肤要显示"还差几天" —— 看得到才有动力。
    func testDaysUntilUnlock() {
        XCTAssertEqual(Skin.third.daysUntilUnlock(totalCheckIns: 63), 37)
        XCTAssertEqual(Skin.third.daysUntilUnlock(totalCheckIns: 100), 0)
        XCTAssertEqual(Skin.third.daysUntilUnlock(totalCheckIns: 300), 0)
        XCTAssertEqual(Skin.default.daysUntilUnlock(totalCheckIns: 0), 0)
    }
}

final class MotionTokenTests: XCTestCase {

    /// 设计系统 1.4 的时长表
    func testDurations() {
        XCTAssertEqual(DSMotion.ringFill.seconds, 1.1, accuracy: 1e-9)
        XCTAssertEqual(DSMotion.sheetSlide.seconds, 0.34, accuracy: 1e-9)
        XCTAssertEqual(DSMotion.Onboarding.counterRoll.seconds, 1.4, accuracy: 1e-9)
        XCTAssertEqual(DSMotion.Onboarding.total.seconds, 2.5, accuracy: 1e-9)
    }

    /// 引导第 4 屏的时序（ONBOARD-04）。
    func testOnboardingSequenceTiming() {
        let o = DSMotion.Onboarding.self
        XCTAssertEqual(o.barDelay.seconds, 0.26, accuracy: 1e-9)
        XCTAssertEqual(o.barFill.seconds, 1.5, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(o.counterRoll.seconds, o.total.seconds)
        XCTAssertLessThanOrEqual(o.barDelay.seconds + o.barFill.seconds, o.total.seconds)
    }

    /// **设计决策 D-14：先说「已经走过」，再说「还剩」。顺序即立场。**
    ///
    /// 「已经走过」是数字滚动，从 `0ms` 就在场；「还剩」要等到 `1200ms` 才淡入。
    /// 这条断言锁的是两者的**先后出场**关系 —— 颠倒过来，产品在用户心里就被归类为
    /// "又一个倒计时"，全部差异化随之失效。
    ///
    /// 注意两者有意重叠约 200ms（滚动到 1400ms 结束，「还剩」1200ms 开始淡入）：
    /// 完全串行会让这场 2.5 秒的演出显得一顿一顿的。重叠不违反 D-14，
    /// 因为"谁先出现"没有变。
    func testPassedIsRevealedBeforeRemaining() {
        let o = DSMotion.Onboarding.self
        XCTAssertGreaterThan(o.restFadeAt.seconds, 0, "「还剩」不得与「已走过」同时出现")
        XCTAssertGreaterThanOrEqual(
            o.restFadeAt.seconds, o.counterRoll.seconds * 0.8,
            "「还剩」要等「已走过」基本滚完才出现，重叠不得超过滚动时长的 20%"
        )
    }

    /// 树与按钮排在「还剩」之后，且全部收在总时长附近。
    func testFadeInOrder() {
        let o = DSMotion.Onboarding.self
        XCTAssertLessThan(o.restFadeAt.seconds, o.treeFadeAt.seconds)
        XCTAssertLessThan(o.treeFadeAt.seconds, o.footFadeAt.seconds)
        XCTAssertLessThanOrEqual(o.footFadeAt.seconds, o.total.seconds)
    }
}
