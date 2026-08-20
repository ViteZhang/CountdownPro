import Foundation

/// 全部面向用户的文字。
///
/// # 规则
/// 1. 本文件里的每一句都**逐字**来自需求文档 / 设计系统 / 两份 HTML 原型。
///    不允许"优化"、不允许同义改写、不允许补标点。按钮是「今天也在」不是「打卡」，这是刻意的。
/// 2. 资料里**没有给**的文案一律走 `Strings.missing(_:)`，它会渲染成刺眼的占位符
///    `⟪待补文案：xxx⟫`，跑一遍 App 就能全部看见，不可能被误当成成品发出去。
///    见文件末尾 `Strings.Missing` 的清单。
/// 3. 新增任何一句之前，先过需求文档第 7 章的校验，尤其是
///    「把它放进『一个刚查完分、没考好的学生正看着屏幕』的场景里读一遍」。
public enum Strings {

    /// 资料未提供的文案占位符。**禁止用真实文案填充这个函数的返回值。**
    public static func missing(_ key: String) -> String { "⟪待补文案：\(key)⟫" }

    // MARK: - 通用

    public enum Common {
        public static let day = "天"
        public static let skip = "跳过"
        public static let save = "保存"
        public static let close = "关闭"
        /// auth 原型明确：用「以后再说」，不用「跳过」——后者暗示这是流程的一步。
        public static let later = "以后再说"
    }

    // MARK: - Tab（信息架构第 3 章 / 原型）

    public enum Tab {
        public static let home = "倒计时"
        public static let log = "记录"
        public static let letters = "信箱"
    }

    // MARK: - 首次启动引导（需求文档 5.1 / countdown-app-onboarding.html）

    public enum Onboarding {
        // 第 1 屏
        public static let step1Title = "你在准备哪场考试？"
        public static let step1Subtitle = "之后可以随时修改，也可以再加别的。"

        public static func typeName(_ type: ExamType) -> String {
            switch type {
            case .gaokao:   return "高考"
            case .zhongkao: return "中考"
            case .kaoyan:   return "考研"
            case .kaogong:  return "考公"
            case .custom:   return "其他考试"
            }
        }

        public static func typeHint(_ type: ExamType) -> String {
            switch type {
            case .gaokao:   return "每年 6 月 7 日"
            case .zhongkao: return "各省不同，通常 6 月中旬"
            case .kaoyan:   return "每年 12 月下旬"
            case .kaogong:  return "国考 11 月，省考 3 月"
            case .custom:   return "自己设定日期"
            }
        }

        // 第 2 屏
        public static let step2Title = "考试是哪天？"
        public static let step2Subtitle = "已经帮你填好了，不对的话可以改。"
        /// 原型只给了高考的提示条文案，其余类型未给。
        public static func step2Tip(_ type: ExamType) -> String {
            switch type {
            case .gaokao:
                return "全国统考首日通常是 6 月 7 日。如果你所在的省份有单独安排，改成实际日期就好。"
            case .zhongkao: return missing("引导第2屏提示条·中考")
            case .kaoyan:   return missing("引导第2屏提示条·考研")
            case .kaogong:  return missing("引导第2屏提示条·考公")
            case .custom:   return missing("引导第2屏提示条·其他考试")
            }
        }
        public static let step2Continue = "继续"
        public static func targetInPast(nextYear: Int) -> String {
            "这个日期已经过去了。要改成 \(nextYear) 年吗？"
        }
        public static func rollToYear(_ year: Int) -> String { "改成 \(year) 年" }

        // 第 3 屏
        public static let step3Title = "从哪天开始算起？"
        public static let step3Subtitle = "这个日期决定了「你已经走过多少天」——这是这个 App 最重要的一个数字。"
        /// 同上：原型只给了高考版本。
        public static func step3Tip(_ type: ExamType) -> String {
            switch type {
            case .gaokao:
                return "大多数人会选高一开学那天。倒计时会告诉你还剩多少，但更重要的是它会记住你已经走了多远。"
            case .zhongkao: return missing("引导第3屏提示条·中考")
            case .kaoyan:   return missing("引导第3屏提示条·考研")
            case .kaogong:  return missing("引导第3屏提示条·考公")
            case .custom:   return missing("引导第3屏提示条·其他考试")
            }
        }
        public static let startNotBeforeTarget = "起始日期要早于考试日期。"
        public static let startInFuture = "起始日期还没到，「已走过」会是 0 天。确定吗？"
        public static let step3Done = "好了"

        // 第 4 屏
        public static let resultLabel = "你已经走过的天数"
        public static func resultRemaining(_ days: Int) -> String { "还剩 \(days) 天" }
        public static let treeCaption = "这棵树会在你考完那天开花"
        public static let resultStart = "开始"
        public static let resultFootnote = "不需要注册，数据只存在这台手机里"
    }

    // MARK: - 首页（需求文档 5.2 / countdown-app-prototype.html）

    public enum Home {
        /// 进度环中心，剩余天数大数字下方
        public static let ringSubtitle = "天后见分晓"
        /// 环内分割线之下。**必须存在**（5.2）。设计决策 D-01：同屏必须同时有加法。
        public static func passed(_ days: Int) -> String { "你已走过 \(days) 天" }
        /// 考试当天，环心不显示数字而显示这两个字（5.2 边界情况）
        public static let today = "今天"

        public static let treeCaption = "这棵树会在你考完那天开花"

        public static let statDaysLabel = "累计坚持"
        public static let statDaysUnit = "天"
        public static let statNotesLabel = "写下"
        public static let statNotesUnit = "句话"

        /// 主 CTA。设计决策 D-02：叫「今天也在」，不叫「打卡」。
        /// 打卡是任务，会制造"又欠了一天"的负债感；「今天也在」是陪伴的口吻。
        public static let checkIn = "今天也在"
        /// 已完成态沿用同一句，只加一个勾（5.3）。
        public static let checkInDone = "今天也在"
        public static let alreadyCheckedIn = "今天已经记下了"

        /// 同考人数（5.7）。`count` 已由 CensusFormatter 格式化为「41.2」这样的字符串。
        public static func together(_ wan: String) -> String { "今天有 \(wan) 万人和你一起" }

        /// 底部提示条：信件（需求文档 5.6 / 信件文案表第 8 节）。
        ///
        /// 三种条件同时满足时的优先级：**今天到期 > 草稿未完成 > 即将开启**。
        ///
        /// 注：原型首页的「100 天前写给自己的信，今天可以开启」已被文案表
        /// 第 8 节的「有一封信可以拆开了」取代 —— 后者是这一组的专用文案表，且更短。
        public static let letterHintDueToday = "有一封信可以拆开了"
        public static let letterHintDraft = "有一封信还没写完"
        public static func letterHintUpcoming(writtenDaysAgo: Int, inDays: Int) -> String {
            "\(writtenDaysAgo) 天前写给自己的信，\(inDays) 天后开启"
        }
    }

    // MARK: - 心里话弹层（需求文档 5.3）

    public enum NoteSheet {
        public static let title = "今天也在"
        public static let subtitle = "想说点什么吗？选填。"
        public static let placeholder = "今天数学错了七道，但我把七道都弄懂了。"
        public static let skip = "跳过"
        public static let save = "保存"
        public static let savedWithoutNote = "已记下今天"
        public static let maxLength = 200
    }

    // MARK: - 记录页（需求文档 5.5）

    public enum Log {
        public static let title = "记录"
        public static let segmentCalendar = "日历"
        public static let segmentNotes = "心里话"

        public static func summaryDays(_ n: Int) -> String { "累计坚持 \(n) 天" }
        public static func summaryNotes(_ n: Int) -> String { "写下 \(n) 句话" }
        public static func summaryPassed(_ n: Int) -> String { "已走过 \(n) 天" }

        public static let legendCheckedIn = "已打卡"
        public static let legendBackfill = "补签"
        public static let legendHasNote = "写了心里话"

        /// 设计决策 D-03 / D-04 在界面上的唯一一处直白表达。
        public static let backfillFootnote = "可补签过去 14 天内的任意一天。断更不会清零，累计只增不减。"

        public static func timelineMeta(date: String, remaining: Int) -> String {
            "\(date) · 还剩 \(remaining) 天"
        }
        public static let makeCard = "做成卡片"

        // 资料未提供：
        public static let backfillConfirm = missing("补签确认文案")
        public static let backfillDone = missing("补签成功提示")
        public static let backfillOutOfWindow = missing("超出14天补签窗口的提示")
        public static let editNote = missing("心里话编辑入口文案")
    }

    // MARK: - 信箱与未来信件（需求文档 5.6 / 《未来信件 · 完整文案表》）

    /// # 这一组文案的特殊性
    /// 这个功能的全部价值在于**情感重量**，任何一句被改成产品腔，重量就没了。
    /// 文案表第 9 节列了一份禁区清单（「亲爱的自己」「时光胶囊」「见证你的成长」
    /// 「相信努力会有回报」「恭喜你完成封存」「保存成功」…），有测试守着。
    public enum Letters {

        // MARK: 信箱页
        public static let title = "信箱"
        public static let subtitle = "写给未来的自己"
        public static let writeNew = "＋ 写一封新的信"

        // 空状态
        public static let emptyTitle = "还没有写过信"
        public static let emptySubtitle = "写一封给以后的自己。\n封起来，到了那天再拆。"
        public static let emptyAction = "写第一封"

        // MARK: 列表项
        public static let stateDraft = "草稿"
        public static func lastEdited(_ date: String) -> String { "最后修改 \(date)" }
        public static func sealedRemaining(_ n: Int) -> String { "封存中 · 还剩 \(n) 天" }
        public static let readyToOpen = "可以开启了"
        public static let tapToOpen = "点击开启 →"
        public static func writtenDaysAgo(_ n: Int) -> String { "写于 \(n) 天前" }
        public static func writtenOn(_ date: String) -> String { "写于 \(date)" }
        public static func openedOn(_ date: String) -> String { "已开启 · \(date)" }

        /// 封存后无法查看，也无法修改（原型底部说明）。
        public static let sealedFootnote = "封存后无法查看，也无法修改。这是它值得被等待的原因。"

        // MARK: 写信页
        public static let composeNavTitle = "写一封信"
        public static let composeTitle = "想对以后的自己说点什么？"
        /// 第二句是关键 —— 提前建立预期，封存的重量来自这里。
        public static let composeSubtitle = "只有你会看到。\n封存之后，你也看不到了。"
        /// **降低门槛，不制造表达压力。**
        public static let composePlaceholder = "不用写得好。\n以后的你只想知道，现在的你是什么样。"
        public static func lengthRemaining(_ n: Int) -> String { "还能写 \(n) 字" }
        /// 不用「已达上限」。
        public static let lengthFull = "写满了"
        /// 不用「下一步」，直接说要去哪。
        public static let composeNext = "选一个开启的日子"
        public static let maxLength = 1000

        // 返回时的草稿确认
        public static let draftPromptTitle = "先存着？"
        public static let draftPromptBody = "还没封存的信可以存成草稿，\n随时回来接着写。"
        public static let draftPromptSave = "存成草稿"
        /// 「不要了」直接丢弃，**不再二次确认** —— 用户已经明确表达了。
        public static let draftPromptDiscard = "不要了"

        // MARK: 选择开启时机
        public static let triggerNavTitle = "什么时候拆开"
        public static let triggerTitle = "选一个日子"
        public static let triggerSubtitle = "到了那天，它会自己出现。"

        public static func triggerLabel(_ trigger: LetterTrigger) -> String {
            switch trigger {
            case .d100:        return "还剩 100 天的那天"
            case .d50:         return "还剩 50 天的那天"
            case .nightBefore: return "考试前一晚"
            case .resultDay:   return "出分那天"
            case .custom:      return "我自己选一天"
            }
        }

        /// 预设节点的副文案是换算出来的实际日期，让用户知道到底是哪天。
        /// **「出分那天」例外** —— 它的副文案是一句刻意中性的话。
        ///
        /// 出分日会把用户分成截然不同的两群，提前用一句中性的话打个底，
        /// 比考完之后再想办法补救要好。
        /// 绝不能改成「查到好成绩的那一刻」这类预设结果的说法。
        public static let resultDayHint = "不管结果怎样，那天你可能会需要它"

        // 自定义日期
        public static let customDateTitle = "选一天"
        public static let customDateBody = "哪天都行，只要还没到。"
        public static let customDateInPast = "这天已经过去了。选一个以后的日子。"
        public static let customDateAfterExam = "这天在考试之后了。确定吗？"
        public static let customDateIsToday = "今天就拆的话，写下来直接看就行了。"

        /// 用户改了考试日期，预设节点信件的开启日跟着变。
        public static func triggersAdjusted(_ count: Int) -> String {
            "有 \(count) 封信的开启日期跟着调整了"
        }

        // MARK: 封存确认（最关键的一屏，必须全屏）
        public static let sealTitle = "封起来？"
        public static func sealBody(openDate: String) -> String {
            "封存之后，你就看不到它了。\n不能改，也不能提前拆。\n\n到了 \(openDate)，\n它会自己出现。"
        }
        /// 主按钮不加「确认」二字 —— 「封起来」本身就是动作。
        public static let sealConfirm = "封起来"
        /// 次按钮用「再看看」，不用「取消」。
        public static let sealCancel = "再看看"

        // 封存成功。**不做庆祝动效** —— 这不是成就，是一次托付。
        public static let sealedDoneTitle = "封好了"
        public static func sealedDoneSubtitle(days: Int) -> String { "\(days) 天后见" }
        public static let sealedDoneBack = "回信箱"

        // MARK: 开启
        public static let dueTitle = "有一封信到期了"
        public static func dueSubtitle(daysAgo: Int) -> String { "\(daysAgo) 天前的你写了点东西" }
        public static let dueOpen = "拆开"
        /// 「待会儿」当天不再弹，次日再触发，直到被拆开。
        public static let dueLater = "待会儿"

        public static func readHeader(_ date: String) -> String { "写于 \(date)" }
        public static func signature(daysAgo: Int) -> String { "—— \(daysAgo) 天前的你" }
        public static let signatureOverAYear = "—— 一年多以前的你"
        public static let readDone = "读完了"

        // MARK: 删除。**不做撤销** —— 撤销会削弱"删除是认真的"这件事，
        // 而这个功能的全部价值就建立在不可逆之上。
        public static let deleteDraftTitle = "删掉这份草稿？"
        public static let deleteDraftBody = "删了就没有了。"

        /// 最重的一次删除。
        public static let deleteSealedTitle = "删掉这封信？"
        public static let deleteSealedBody = "它还没被拆开，你也没法再看一眼。\n删了就是真的没有了，没有备份。"

        public static let deleteOpenedTitle = "删掉这封信？"
        public static let deleteOpenedBody = "删了之后就读不到了。"

        public static let deleteConfirm = "删掉"
        /// 「留着」是有立场的动词，比「取消」好。
        public static let deleteCancel = "留着"
        public static let deletedToast = "删掉了"

        // MARK: 通知
        public static let notificationTitle = "有一封信到期了"
        public static func notificationBody(daysAgo: Int) -> String {
            "\(daysAgo) 天前的你写了点东西给现在的你"
        }
        public static let notificationBodyNightBefore = "是你自己留在这一天的"
        /// 考前一晚那条推送定在 20:00，不要更晚 —— 不该在临睡前打扰。
        public static let nightBeforeNotificationHour = 20
    }

    // MARK: - 分享卡（需求文档 5.8）

    public enum ShareCard {
        public static let tabMilestone = "节点卡"
        public static let tabNote = "心里话卡"
        public static let tabZero = "归零卡"

        public static let saveImage = "保存图片"
        public static let savedToAlbum = "已保存到相册"
        public static let noQRCodeHint = "没有二维码，只有一行淡水印"
        /// 节点全屏卡的次要按钮（5.8.2）
        public static let decline = "不了"

        /// 设计决策 D-11：不放二维码。水印仅一行淡色产品名。
        /// 产品名待拍板（需求文档待决事项 1），原型占位为「倒计时」。
        public static let watermark = missing("产品名（分享卡水印 / App 展示名）")

        public static func distanceTo(_ examTitle: String) -> String { "距离\(examTitle)" }
        /// 设计决策 D-11：「已走过」进度条 + 这行字必须出现在**每一张**卡上，
        /// 无二维码的前提下这是全部的品牌识别。
        public static func passed(_ days: Int) -> String { "已经走过 \(days) 天" }
        public static func nthDay(_ n: Int) -> String { "第 \(n) 天" }
        public static func noteMeta(date: String, remaining: Int) -> String {
            "\(date) · 还剩 \(remaining) 天"
        }
        public static func togetherOnCard(_ wan: String) -> String { "今天有 \(wan) 万人和我一起" }

        /// 归零卡。文案规范正例：「807 天，走完了」——肯定过程，不肯定结果，不用「恭喜」。
        public static let walkedItAll = "天，走完了"
        public static func zeroStats(days: Int, notes: Int) -> String {
            "累计坚持 \(days) 天 · 写下 \(notes) 句话"
        }

        /// 节点全屏卡
        public static func milestonePassed(_ days: Int) -> String { "你已经走过 \(days) 天" }
    }

    // MARK: - 账号与登录（需求文档 5.14 / countdown-app-auth.html）

    public enum Auth {
        // 价值时刻浮层。**每个触发点一生只弹一次。**
        public enum Prompt {
            /// 最高优先级触发点：写完第一封未来信件后。
            /// 文案针对触发点定制 —— 说用户会失去什么，不说产品能提供什么。
            public static func firstLetterTitle(days: Int) -> String { "这封信要存 \(days) 天" }
            public static let firstLetterSubtitle = "绑定一下，换手机也不会丢。\n只要十几秒，不用填任何资料。"
            public static let bindNow = "现在绑定"
            public static let later = "以后再说"

            // 其余三个触发点的定制文案资料未提供：
            public static let sevenDaysTitle = missing("价值时刻文案·累计打卡满7天·标题")
            public static let sevenDaysSubtitle = missing("价值时刻文案·累计打卡满7天·副文案")
            public static let exportTitle = missing("价值时刻文案·主动导出数据·标题")
            public static let exportSubtitle = missing("价值时刻文案·主动导出数据·副文案")
            public static let postExamTitle = missing("价值时刻文案·考后接力开启·标题")
            public static let postExamSubtitle = missing("价值时刻文案·考后接力开启·副文案")
        }

        // 登录方式选择
        public static let methodTitle = "保存你的记录"
        public static let methodSubtitle = "绑定之后，换手机、重装 App 都不会丢。\n不需要填任何资料。"
        public static let wechat = "微信登录"
        public static let qq = "QQ 登录"
        public static let phone = "手机号登录"
        public static let apple = "通过 Apple 登录"
        public static let methodFootnote = "我们只用它来同步你的数据\n不会向任何人展示你的记录"
        public static func redirecting(_ platform: String) -> String { "正在跳转\(platform)…" }
        public static let verifying = "正在验证…"

        // 手机号
        public static let phoneTitle = "输入手机号"
        public static let countryCode = "+86"
        public static let phonePlaceholder = "手机号"
        /// 5.14.3：**必须独立勾选，不得默认勾选。** 未勾选时抖动 + 文字变警示色，不弹 Alert。
        public static let agreementPrefix = "我已阅读并同意 "
        public static let userAgreement = "用户协议"
        public static let agreementAnd = " 和 "
        public static let privacyPolicy = "隐私政策"
        public static let sendCode = "获取验证码"

        // 验证码
        public static let codeTitle = "输入验证码"
        public static func codeSentTo(_ masked: String) -> String { "已发送至 +86 \(masked)" }
        public static func resendIn(_ seconds: Int) -> String { "重新发送 \(seconds)s" }
        public static let resend = "重新发送"
        public static let codeFootnote = "收不到？检查是否被拦截，或换其他方式登录"
        public static let resendCooldownSeconds = 60
        // 异常态文案资料未提供（原型只描述了行为）：
        public static let codeWrong = missing("验证码错误提示")
        public static let codeLocked = missing("验证码连续5次失败·锁定15分钟提示")

        // 年龄确认。5.14.3 / 个人信息保护法第 31 条。
        // **只问是否年满 14 周岁，不问具体生日** —— 生日是可识别个人信息，我们只需要一个布尔值。
        public static let ageTitle = "最后一个问题"
        public static let ageSubtitle = "法规要求我们确认这一项。\n我们不会问你的具体生日。"
        public static let ageOver14 = "我已满 14 周岁"
        public static let ageUnder14 = "我未满 14 周岁"
        public static let ageFootnote = "这一项只用于判断是否需要监护人同意"

        // 监护人同意。核心原则：给出「先不绑定继续用」的出口，并放在同等显著位置。
        public static let guardianTitle = "需要家长帮个忙"
        public static let guardianSubtitle = "按规定，未满 14 周岁需要监护人同意才能绑定账号。"
        public static let guardianTip = "你可以先不绑定继续使用——所有功能都不受影响，记录会存在这台手机里。等方便的时候再让家长确认。"
        public static let guardianPresent = "家长现在就在旁边"
        public static let guardianSkip = "先不绑定，继续用"

        // 绑定成功。「存好了」而不是「登录成功」；列出具体同步了什么。
        public static let successTitle = "存好了"
        public static func successDetail(days: Int, notes: Int, sealedLetters: Int) -> String {
            "你的 \(days) 天记录、\(notes) 句心里话\n和 \(sealedLetters) 封未拆的信，都已经同步"
        }
        public static let successBack = "回去继续"

        // 账号页
        public static let accountNavTitle = "设置 / 账号"
        public static let accountTitle = "账号"
        public static let rowBindType = "登录方式"
        public static let rowPhone = "手机号"
        public static let rowPhoneUnbound = "未绑定"
        public static let rowSyncNow = "立即同步"
        public static let rowExport = "导出我的数据"
        public static let rowSignOut = "退出登录"
        public static let rowDeleteAccount = "注销账号"
        public static func lastSynced(_ when: String) -> String { "上次同步：\(when)" }
        public static let justNow = "刚刚"
        public static let synced = "已同步"
        public static let signedOut = "已退出"

        // 注销。法定权利，**不做挽留弹窗、不做二次劝阻**（设置阻碍会被判定为违规）。
        public static let deleteNavTitle = "账号 / 注销"
        public static let deleteTitle = "注销账号"
        public static let deleteSubtitle = "这件事不能撤销，请确认你知道会发生什么。"
        public static let deleteConsequences = [
            "账号及绑定的手机号 / 微信信息会被删除",
            "云端的打卡记录、心里话、信件会被删除",
            "未开启的信件将永久丢失，无法找回",
            "这台手机上的本地记录会保留",
            "删除将在 15 个工作日内完成",
        ]
        /// 上面第 3 条必须用强调色 —— 这是最重要的一条。
        public static let deleteEmphasizedIndex = 2
        public static let deleteConfirmCheckbox = "我已了解上述后果，确认注销"
        public static let deleteConfirmButton = "确认注销"
        public static let deleteFootnote = "建议先导出数据再注销"
        public static let deleteSubmitted = "已提交注销申请"
        public static let exportedJSON = "已导出 JSON"
    }

    // MARK: - 设置（需求文档 5.13）—— 资料完全未提供

    public enum Settings {
        public static let title = missing("设置页标题")
        public static let rowExams = missing("设置项·考试管理")
        public static let rowSkins = missing("设置项·皮肤")
        public static let rowNotifications = missing("设置项·通知开关")
        public static let rowExport = missing("设置项·数据导出")
        public static let rowAbout = missing("设置项·关于")
        public static let rowPrivacy = missing("设置项·隐私政策")
        /// 出分日的强约束：常驻但不显眼、可找到。**不做诊断、不做引导性提问。**
        /// 热线信息必须来源权威（需求文档待决事项 5），此处绝不自行编写。
        public static let rowMentalHealth = missing("设置项·心理支持资源")
        public static let mentalHealthContent = missing("心理支持资源内容（需权威来源，不可自拟）")
        public static let rowAccount = missing("设置项·账号入口（未登录态文案）")
    }

    // MARK: - 通知（需求文档 5.11）—— 正文资料未提供

    public enum Notifications {
        public static func milestone(_ days: Int) -> String { missing("节点通知正文·还剩\(days)天") }
        public static let letterOpen = missing("信件开启日通知正文")
        public static let examDayMorning = missing("考试当天早上的祝福通知正文")
        /// 5.11：权限请求时机为**第一次打卡之后**，且附一句说明。原型只给了这半句。
        public static let permissionRationaleFragment = "我们一年只会打扰你几次"
        public static let permissionRationale = missing("通知权限请求的完整说明文案")
    }

    // MARK: - 皮肤（需求文档 5.9）

    public enum Skins {
        public static let unlockToast = missing("皮肤解锁提示文案")
    }

    // MARK: - 小组件引导（需求文档 5.10）

    public enum WidgetPrompt {
        public static let title = missing("小组件添加引导·标题")
        public static let body = missing("小组件添加引导·正文")
    }

    // MARK: - 小组件本身

    public enum Widget {
        /// 还没走完引导时的占位。**绝不显示 0 天** —— 那会让人以为倒计时已经结束。
        public static let notConfigured = missing("小组件占位态文案（尚未完成引导时）")

        public static let smallDisplayName = missing("小组件名称·桌面小号")
        public static let mediumDisplayName = missing("小组件名称·桌面中号")
        public static let circularDisplayName = missing("小组件名称·锁屏圆形")
        public static let rectangularDisplayName = missing("小组件名称·锁屏矩形")
        public static let widgetDescription = missing("小组件描述（添加面板里的说明）")
    }

    // MARK: - 考后接力（需求文档 5.12）—— 文案资料未提供

    public enum PostExam {
        public static let homeTitle = missing("考后态首页文案")
        /// 5.12 强约束：出分日文案保持中性，**不使用「恭喜」**。
        public static let resultDayNotice = missing("出分日文案（中性，禁用「恭喜」）")
    }
}
