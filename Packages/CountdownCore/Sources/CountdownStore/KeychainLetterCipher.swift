import Foundation
import CountdownKit

#if canImport(CryptoKit) && canImport(Security)
import CryptoKit
import Security

/// 信件正文的真实加密实现：AES-GCM，密钥存 Keychain。
///
/// 密钥的 Keychain 属性刻意选成：
/// - `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
///   → **不随 iCloud 钥匙串同步、不进 iTunes/iCloud 备份**。
///     换机后旧密文自然失效，这与产品语义一致：信件的云端副本由服务端持有并在
///     绑定账号后随账号恢复；未绑定账号的用户换机丢数据，正是 D-10 里那句
///     「换机丢数据引发差评」所对应的、需要账号来解决的问题 —— 而不是靠把密钥泄露到备份里解决。
/// - 设备内可用（AfterFirstUnlock），保证 WidgetKit 在后台刷新时也能工作。
///   注意：**小组件永远不需要解密信件**，它只读天数与打卡（5.10），
///   所以这条属性其实只服务于主 App 的后台任务。
public struct KeychainLetterCipher: LetterCipher {

    private let account: String
    private let service: String

    public init(service: String = "com.countdownpro.letters", account: String = "letter-key-v1") {
        self.service = service
        self.account = account
    }

    public func seal(_ plaintext: String) throws -> Data {
        let key = try loadOrCreateKey()
        let box = try AES.GCM.seal(Data(plaintext.utf8), using: key)
        guard let combined = box.combined else { throw LetterVaultError.cipherFailure }
        return combined
    }

    public func reveal(_ ciphertext: Data) throws -> String {
        let key = try loadOrCreateKey()
        let box = try AES.GCM.SealedBox(combined: ciphertext)
        let data = try AES.GCM.open(box, using: key)
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Keychain

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func loadOrCreateKey() throws -> SymmetricKey {
        if let existing = try loadKey() { return existing }
        let key = SymmetricKey(size: .bits256)
        try storeKey(key)
        return key
    }

    private func loadKey() throws -> SymmetricKey? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw LetterVaultError.cipherFailure }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            return nil
        default:
            throw LetterVaultError.cipherFailure
        }
    }

    private func storeKey(_ key: SymmetricKey) throws {
        var query = baseQuery
        query[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw LetterVaultError.cipherFailure
        }
    }
}
#endif
