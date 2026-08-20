import XCTest
@testable import DesignTokens

/// 设计代币不是"样式建议"，是产品决策的载体。这些断言守的是决策，不是数值。
final class PaletteTests: XCTestCase {

    /// 设计决策 D-07：基底不用纯黑，文字不用纯白。
    /// 纯黑在 OLED 上滚动拖影；21:1 对比度下中文笔画会产生光晕；
    /// 且纯黑没有"更深"的余地，层级只能往亮里走，界面会一层层浮起来。
    func testNoPureBlackOrPureWhiteInDarkScheme() {
        let p = Palette.defaultDark
        XCTAssertNotEqual(p.background.hex, 0x000000)
        XCTAssertNotEqual(p.textPrimary.hex, 0xFFFFFF)
        XCTAssertEqual(p.background.hexString, "#101114")
        XCTAssertEqual(p.textPrimary.hexString, "#F2F4F7")
    }

    /// 浅色基底是"纸白"，不是纯白。
    func testLightBackgroundIsPaperNotPureWhite() {
        XCTAssertNotEqual(Palette.defaultLight.background.hex, 0xFFFFFF)
        XCTAssertEqual(Palette.defaultLight.background.hexString, "#FAFAF8")
    }

    /// D-07 的量化后果：主文字/基底的对比度必须远低于纯黑白的 21:1，
    /// 同时仍要满足 WCAG AA 正文（4.5:1）。
    func testPrimaryTextContrastIsComfortableNotHarsh() {
        for p in [Palette.defaultDark, Palette.defaultLight] {
            let ratio = p.textPrimary.contrastRatio(against: p.background)
            XCTAssertGreaterThan(ratio, 4.5, "主文字对比度需达 WCAG AA")
            XCTAssertLessThan(ratio, 19.0, "不该逼近纯黑白的 21:1")
        }
    }

    /// 次文字仍需可读（AA large / UI 组件线 3:1）。
    func testSecondaryTextRemainsReadable() {
        for p in [Palette.defaultDark, Palette.defaultLight] {
            XCTAssertGreaterThan(p.textSecondary.contrastRatio(against: p.background), 3.0)
        }
    }

    /// 设计系统 1.1：两套模式是同一个性格的一日两态。
    /// 结构上已由 `Palette` 的必填字段保证，这里再验一次深浅方向确实相反。
    func testDarkAndLightAreInverted() {
        XCTAssertLessThan(Palette.defaultDark.background.relativeLuminance,
                          Palette.defaultDark.textPrimary.relativeLuminance)
        XCTAssertGreaterThan(Palette.defaultLight.background.relativeLuminance,
                             Palette.defaultLight.textPrimary.relativeLuminance)
    }

    /// 设计决策 D-06：全界面灰阶，唯一的彩色留给树。
    /// 灰阶 = R/G/B 三通道彼此接近；树必须明显不是灰阶。
    func testTreeIsTheOnlySaturatedColor() {
        func chroma(_ c: DSColor) -> Double {
            max(c.red, c.green, c.blue) - min(c.red, c.green, c.blue)
        }
        for p in [Palette.defaultDark, Palette.defaultLight] {
            for neutral in [p.background, p.surface, p.surfaceRaised, p.line,
                            p.textPrimary, p.textSecondary, p.textTertiary] {
                XCTAssertLessThan(chroma(neutral), 0.09, "灰阶色不得有明显彩度：\(neutral.hexString)")
            }
            XCTAssertGreaterThan(chroma(p.tree), 0.10, "树是全界面唯一彩色")
        }
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

    /// 第 2/3/4 套配色尚未定义：解锁逻辑完整，但不会展示。
    func testOnlyDefinedSkinsAreAvailable() {
        XCTAssertEqual(Skin.available, [.default])
        XCTAssertTrue(Skin.default.hasDefinedPalette)
        XCTAssertFalse(Skin.second.hasDefinedPalette)
    }

    /// 未定义配色的皮肤回落到默认皮肤，绝不返回半套色板。
    func testUndefinedSkinFallsBackToDefaultPalette() {
        XCTAssertEqual(Skin.second.palette(.dark), Palette.defaultDark)
        XCTAssertEqual(Skin.fourth.palette(.light), Palette.defaultLight)
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
