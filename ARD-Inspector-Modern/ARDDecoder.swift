import Foundation
import CommonCrypto

enum ARDDecoderError: Error {
    case decryptionFailed
    case unarchivingFailed
    case invalidPreferences
}

class ARDDecoder {
    static func decodePreferences(preferences: [String: Any], masterPassword: String) throws -> [String: Any] {
        guard let encryptedData = preferences["accessCredentials"] as? Data else {
            print("ARDDecoder: No accessCredentials found in preferences")
            throw ARDDecoderError.invalidPreferences
        }
        
        print("ARDDecoder: Encrypted data size: \(encryptedData.count) bytes")
        
        let key = try deriveKey(password: masterPassword)
        let decryptedData = try decryptAES128ECB(data: encryptedData, key: key)
        
        print("ARDDecoder: Decrypted data size: \(decryptedData.count) bytes")
        if decryptedData.count > 0 {
            let hexString = decryptedData.prefix(16).map { String(format: "%02x", $0) }.joined()
            print("ARDDecoder: Decrypted data (first 16 bytes): \(hexString)")
        }
        
        

        // The signature 'streamtyped' indicates a non-keyed NSUnarchiver archive.
        // We MUST use NSUnarchiver, not NSKeyedUnarchiver.
        // NSUnarchiver.unarchiveObject(with:) is the equivalent to [NSUnarchiver unarchiveObjectWithData:]
        if let decodedSecrets = NSUnarchiver.unarchiveObject(with: decryptedData) as? [String: Any] {
            print("ARDDecoder: Successfully unarchived using legacy NSUnarchiver")
            var newPreferences = preferences
            newPreferences["accessCredentials"] = decodedSecrets
            return newPreferences
        } else {
            print("ARDDecoder: NSUnarchiver returned nil or wrong type")
        }
        
        // Fallback to others just in case
        if let decodedSecrets = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(decryptedData) as? [String: Any] {
            var newPreferences = preferences
            newPreferences["accessCredentials"] = decodedSecrets
            return newPreferences
        }
        
        if let decodedSecrets = try? PropertyListSerialization.propertyList(from: decryptedData, options: [], format: nil) as? [String: Any] {
            var newPreferences = preferences
            newPreferences["accessCredentials"] = decodedSecrets
            return newPreferences
        }
        
        print("ARDDecoder: All unarchiving strategies failed")
        throw ARDDecoderError.unarchivingFailed
    }
    
    private static func deriveKey(password: String) throws -> Data {
        let passwordBytes = Array(password.utf16)
        let byteCount = passwordBytes.count * 2
        
        var paddedLength = byteCount
        paddedLength += 0xf
        paddedLength &= 0xfffffff0
        
        var buffer = [UInt8](repeating: 0, count: paddedLength)
        
        passwordBytes.withUnsafeBytes { ptr in
            let count = min(byteCount, paddedLength)
            memcpy(&buffer, ptr.baseAddress!, count)
        }
        
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        
        // We need to use CC_MD5 to decrypt the stored passwords.
        CC_MD5(buffer, CC_LONG(paddedLength), &digest)
        
        return Data(digest)
    }
    
    private static func decryptAES128ECB(data: Data, key: Data) throws -> Data {
        var decryptedData = Data(count: data.count)
        var numBytesDecrypted: Int = 0
        
        let dataCount = data.count
        let bufferSize = decryptedData.count
        
        let status = data.withUnsafeBytes { dataPtr in
            key.withUnsafeBytes { keyPtr in
                decryptedData.withUnsafeMutableBytes { decPtr in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmAES128),
                        CCOptions(kCCOptionECBMode),
                        keyPtr.baseAddress,
                        key.count,
                        nil,
                        dataPtr.baseAddress,
                        dataCount,
                        decPtr.baseAddress,
                        bufferSize,
                        &numBytesDecrypted
                    )
                }
            }
        }
        
        guard status == kCCSuccess else {
            throw ARDDecoderError.decryptionFailed
        }
        
        return decryptedData.prefix(numBytesDecrypted)
    }
}
