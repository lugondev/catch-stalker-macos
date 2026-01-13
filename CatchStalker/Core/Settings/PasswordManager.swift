import Foundation
import CryptoKit

final class PasswordManager {
    static let shared = PasswordManager()
    
    private let keychainService = "com.catchstalker.password"
    private let keychainAccount = "masterPassword"
    
    private init() {}
    
    func setPassword(_ password: String) -> Bool {
        let hash = hashPassword(password)
        return saveToKeychain(hash)
    }
    
    func verifyPassword(_ password: String) -> Bool {
        guard let storedHash = getFromKeychain() else { return false }
        let inputHash = hashPassword(password)
        return storedHash == inputHash
    }
    
    func hasPassword() -> Bool {
        return getFromKeychain() != nil
    }
    
    func removePassword() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
    
    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func saveToKeychain(_ hash: String) -> Bool {
        let _ = removePassword()
        
        let data = hash.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data
        ]
        
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
    
    private func getFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
}
