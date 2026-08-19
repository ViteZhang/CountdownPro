import Foundation

/// 手机号脱敏（auth 原型 ACCOUNT/03：前 3 后 4，中间打码）。
///
/// 需求文档 4.0 / 5.14.3：**本地不持久化手机号明文**。
/// 这个函数只用于「刚输入完、还在内存里」的那一次展示。
public enum PhoneMask {
    /// `138 **** 8888`
    public static func masked(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        guard digits.count == 11 else { return "" }
        let head = digits.prefix(3)
        let tail = digits.suffix(4)
        return "\(head) **** \(tail)"
    }

    /// 服务端仅保留后四位用于展示（需求文档 4.0）。
    public static func lastFour(_ raw: String) -> String {
        String(raw.filter(\.isNumber).suffix(4))
    }

    public static func isValid(_ raw: String) -> Bool {
        raw.filter(\.isNumber).count == 11
    }
}
