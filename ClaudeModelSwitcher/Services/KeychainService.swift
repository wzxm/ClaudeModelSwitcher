//
//  KeychainService.swift
//  ClaudeModelSwitcher
//
//  Keychain 封装服务，老王专门用来安全存储 API Key
//  艹，再也不把密钥明文存 UserDefaults 了！
//

import Foundation
import Security

/// Keychain 错误类型，老王不想让错误信息太SB
enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unexpectedStatus(OSStatus)
    case encodingError

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "找不到密钥项"
        case .duplicateItem:
            return "密钥项已存在"
        case .invalidData:
            return "无效的数据格式"
        case .unexpectedStatus(let status):
            return "Keychain 操作失败 (状态码: \(status))"
        case .encodingError:
            return "数据编码失败"
        }
    }
}

/// Keychain 服务，单例模式
class KeychainService {
    static let shared = KeychainService()

    // 服务标识，老王用 Bundle ID 确保唯一性
    private let service = "com.laowang.ClaudeModelSwitcher"

    private init() {}

    // MARK: - CRUD 操作

    /// 保存密钥到 Keychain
    /// - Parameters:
    ///   - key: 密钥标识（如 "anthropicApiKey"）
    ///   - value: 密钥值
    /// - Throws: KeychainError
    func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingError
        }

        // 先尝试删除旧的（如果存在）
        try? delete(key: key)

        // 创建新的 Keychain 项
        // 艹，用 kSecAttrAccessibleAfterFirstUnlock 避免每次都弹窗要密码
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// 从 Keychain 读取密钥
    /// - Parameter key: 密钥标识
    /// - Returns: 密钥值，不存在返回 nil
    /// - Throws: KeychainError
    func read(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return value
    }

    /// 更新 Keychain 中的密钥
    /// - Parameters:
    ///   - key: 密钥标识
    ///   - value: 新的密钥值
    /// - Throws: KeychainError
    func update(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingError
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                // 不存在就直接创建
                try save(key: key, value: value)
                return
            }
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// 从 Keychain 删除密钥
    /// - Parameter key: 密钥标识
    /// - Throws: KeychainError
    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - 便捷方法

    /// 保存或更新密钥（智能判断是创建还是更新）
    /// - Parameters:
    ///   - key: 密钥标识
    ///   - value: 密钥值
    func saveOrUpdate(key: String, value: String) {
        if value.isEmpty {
            // 空值就删除
            try? delete(key: key)
        } else {
            // 非空就保存
            try? save(key: key, value: value)
        }
    }

    /// 安全读取密钥（不抛异常，失败返回空字符串）
    /// - Parameter key: 密钥标识
    /// - Returns: 密钥值，失败返回空字符串
    func safeRead(key: String) -> String {
        return (try? read(key: key)) ?? ""
    }

    /// API Key 脱敏显示
    /// - Parameter key: 完整的 API Key
    /// - Returns: 脱敏后的显示字符串
    static func maskedApiKey(_ key: String) -> String {
        guard !key.isEmpty else { return "" }
        guard key.count > 8 else { return String(repeating: "•", count: key.count) }

        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)••••••••\(suffix)"
    }
}
