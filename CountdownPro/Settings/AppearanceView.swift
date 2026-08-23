import SwiftUI
import SwiftData
import CountdownKit
import CountdownStore
import CountdownUI
import DesignTokens

/// 外观页（《V1 剩余页面》第四节）。
///
/// # 未解锁的皮肤照常展示，而且能预览
/// **看得到才有动力。** 把没解锁的藏起来，解锁提示就成了一句没有指向的话；
/// 摆在那里灰着、点进去能看见长什么样，才构成一个目标。
///
/// # 但预览不等于应用
/// 选中未解锁的皮肤只换这一页的预览，不写库、不影响首页 ——
/// 否则"解锁"这个机制就自己废掉了。
///
/// # 四套皮肤的差异只在灰的冷暖和树的色相
/// 一旦某套引入第二个彩色，整套视觉体系就破了（D-06）。
/// 有一组测试盯着八套色板，见 `PaletteTests`。
struct AppearanceView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.theme) private var theme

    @Query private var checkIns: [CheckIn]

    @State private var selected: Skin = .default
    @State private var preview: Skin = .default
    @State private var preference: AppearancePreference = .followSystem
    @State private var toast: String?

    private let cal = DayCalendar.current
    private var flags: FlagStore { FlagStore(context: context, cal: cal) }

    /// 这一页自己的色板跟着**预览**走 —— 点一下就能看见整页变色，
    /// 这比在小色块上比对直观得多。
    private var palette: Palette {
        preview.palette(preference.resolvedIsDark(systemIsDark: systemColorScheme == .dark)
                        ? .dark : .light)
    }

    private var totalCheckIns: Int { checkIns.count }

    var body: some View {
        SettingsPage(title: Strings.Skins.title, palette: palette) {
            SettingsGroup(palette: palette) {
                SettingsToggleRow(
                    title: Strings.Settings.rowFollowSystemAppearance,
                    isOn: Binding(
                        get: { preference.followsSystem },
                        set: { setPreference($0 ? .followSystem : currentSystemAsExplicit()) }
                    ),
                    palette: palette
                )
                // 关掉「跟随系统」之后才出现二选一 —— 跟随系统时这两个选项没有意义，
                // 摆在那里只会让人以为自己选错了。
                if !preference.followsSystem {
                    Divider().overlay(palette.line.color)
                    schemePicker
                }
            }

            Text(Strings.Skins.sectionTitle)
                .dsFont(DSFont.caption(DSType.caption))
                .foregroundStyle(palette.textSecondary.color)
                .padding(.top, DSSpacing.sm)
                .padding(.leading, DSSpacing.xs)

            VStack(spacing: DSSpacing.cardGap) {
                ForEach(Skin.allCases) { skin in
                    skinRow(skin)
                }
            }
        }
        .dsToast($toast, palette: palette)
        .task { load() }
    }

    // MARK: - 深浅色

    private var schemePicker: some View {
        HStack(spacing: DSSpacing.sm) {
            schemeButton(Strings.Settings.alwaysDark, value: .alwaysDark)
            schemeButton(Strings.Settings.alwaysLight, value: .alwaysLight)
        }
        .padding(.horizontal, DSSpacing.md + 2)
        .padding(.vertical, DSSpacing.md - 2)
    }

    private func schemeButton(_ title: String, value: AppearancePreference) -> some View {
        Button {
            setPreference(value)
        } label: {
            Text(title)
                .dsFont(DSFont.body(DSType.body))
                .foregroundStyle(preference == value
                                 ? palette.textPrimary.color : palette.textSecondary.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSSpacing.sm + 1)
                .background {
                    RoundedRectangle(cornerRadius: DSRadius.segmentThumb, style: .continuous)
                        .fill(preference == value
                              ? palette.surfaceRaised.color : Color.clear)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 皮肤

    private func skinRow(_ skin: Skin) -> some View {
        let unlocked = skin.isUnlocked(totalCheckIns: totalCheckIns)
        return Button {
            // 点一下先预览。已解锁的才顺带应用。
            preview = skin
            if unlocked { apply(skin) }
        } label: {
            HStack(spacing: DSSpacing.md) {
                swatch(skin)
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(skin.displayName)
                        .dsFont(DSFont.body(DSType.bodyLarge))
                        .foregroundStyle(palette.textPrimary.color)
                    if !unlocked {
                        Text(Strings.Skins.lockedCaption(
                            unlockAt: skin.unlockAtCheckInDays,
                            remaining: skin.daysUntilUnlock(totalCheckIns: totalCheckIns)))
                            .dsFont(DSFont.caption(DSType.captionSmall))
                            .foregroundStyle(palette.textSecondary.color)
                    }
                }
                Spacer(minLength: DSSpacing.sm)
                if selected == skin {
                    Text("✓")
                        .dsFont(DSFont.body(DSType.bodyLarge))
                        .foregroundStyle(palette.textPrimary.color)
                }
            }
            .padding(.horizontal, DSSpacing.md + 2)
            .padding(.vertical, DSSpacing.md - 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface.color,
                        in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                    .dsHairline(preview == skin ? palette.textTertiary : palette.line)
            }
            // 未解锁只降透明度，不加锁图标 —— 锁是"你不配"，灰是"还没到"。
            .opacity(unlocked ? 1 : 0.72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 色块：基底 + 卡片 + 树。三块就够说明这套皮肤的性格。
    private func swatch(_ skin: Skin) -> some View {
        let p = skin.palette(preference.resolvedIsDark(systemIsDark: systemColorScheme == .dark)
                             ? .dark : .light)
        return ZStack {
            RoundedRectangle(cornerRadius: DSRadius.segmentThumb, style: .continuous)
                .fill(p.background.color)
            RoundedRectangle(cornerRadius: DSRadius.segmentThumb, style: .continuous)
                .dsHairline(p.line)
            TreeView(stage: .lush, color: p.tree)
                .padding(DSSpacing.sm)
        }
        .frame(width: DSSwatch.size, height: DSSwatch.size)
    }

    // MARK: -

    private func load() {
        selected = Skin(rawValue: flags.intValue(AppFlagKey.selectedSkin)) ?? .default
        preview = selected
        preference = AppearancePreference(
            rawValue: flags.intValue(AppFlagKey.appearancePreference)) ?? .followSystem
    }

    private func apply(_ skin: Skin) {
        selected = skin
        flags.set(AppFlagKey.selectedSkin, value: skin.rawValue)
    }

    private func setPreference(_ value: AppearancePreference) {
        preference = value
        flags.set(AppFlagKey.appearancePreference, value: value.rawValue)
    }

    /// 从「跟随系统」切走时，落在系统此刻的模式上 ——
    /// 关掉开关的那一瞬间界面不该跳变，那会让人以为自己点错了。
    private func currentSystemAsExplicit() -> AppearancePreference {
        systemColorScheme == .dark ? .alwaysDark : .alwaysLight
    }
}

/// 皮肤色块尺寸。视图层不写字面量尺寸。
private enum DSSwatch {
    static let size: Double = 44
}
