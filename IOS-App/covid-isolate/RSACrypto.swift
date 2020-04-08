import Foundation
import Security

// params
let signingAlgorithm: SecKeyAlgorithm = .rsaSignatureDigestPKCS1v15SHA512
let useKeyHashes = false

public class RSACrypto: NSObject {
    
    //  Swift-RSAUtils
    //  Created by Thanh Nguyen on 7/10/15.
    // Base64 encode a block of data
    static fileprivate func base64Encode(_ data: Data) -> String {
        return data.base64EncodedString(options: [])
    }
    
    //  Swift-RSAUtils
    //  Created by Thanh Nguyen on 7/10/15.
    // Base64 decode a base64-ed string
    static fileprivate func base64Decode(_ strBase64: String) -> Data {
        let data = Data(base64Encoded: strBase64, options: [])
        return data!
    }
    
    //  Swift-RSAUtils
    //  Created by Thanh Nguyen on 7/10/15.
    // Encrypts data with a RSA key
    static public func encryptWithRSAKey(_ data: Data, rsaKeyRef: SecKey, padding: SecPadding) -> Data? {
        let blockSize = SecKeyGetBlockSize(rsaKeyRef)
        let maxChunkSize = blockSize - 11

        var decryptedDataAsArray = [UInt8](repeating: 0, count: data.count / MemoryLayout<UInt8>.size)
        (data as NSData).getBytes(&decryptedDataAsArray, length: data.count)

        var encryptedData = [UInt8](repeating: 0, count: 0)
        var idx = 0
        while (idx < decryptedDataAsArray.count ) {
            var idxEnd = idx + maxChunkSize
            if ( idxEnd > decryptedDataAsArray.count ) {
                idxEnd = decryptedDataAsArray.count
            }
            var chunkData = [UInt8](repeating: 0, count: maxChunkSize)
            for i in idx..<idxEnd {
                chunkData[i-idx] = decryptedDataAsArray[i]
            }

            var encryptedDataBuffer = [UInt8](repeating: 0, count: blockSize)
            var encryptedDataLength = blockSize

            let status = SecKeyEncrypt(rsaKeyRef, padding, chunkData, idxEnd-idx, &encryptedDataBuffer, &encryptedDataLength)
            if ( status != noErr ) {
                NSLog("Error while ecrypting: %i", status)
                return nil
            }
            //let finalData = removePadding(encryptedDataBuffer)
            encryptedData += encryptedDataBuffer

            idx += maxChunkSize
        }

        return Data(bytes: UnsafePointer<UInt8>(encryptedData), count: encryptedData.count)
    }
    
    //  Swift-RSAUtils
    //  Created by Thanh Nguyen on 7/10/15.
    // Decrypt an encrypted data with a RSA key
    static public func decryptWithRSAKey(_ encryptedData: Data, rsaKeyRef: SecKey, padding: SecPadding) -> Data? {
        let blockSize = SecKeyGetBlockSize(rsaKeyRef)

        var encryptedDataAsArray = [UInt8](repeating: 0, count: encryptedData.count / MemoryLayout<UInt8>.size)
        (encryptedData as NSData).getBytes(&encryptedDataAsArray, length: encryptedData.count)

        var decryptedData = [UInt8](repeating: 0, count: 0)
        var idx = 0
        while (idx < encryptedDataAsArray.count ) {
            var idxEnd = idx + blockSize
            if ( idxEnd > encryptedDataAsArray.count ) {
                idxEnd = encryptedDataAsArray.count
            }
            var chunkData = [UInt8](repeating: 0, count: blockSize)
            for i in idx..<idxEnd {
                chunkData[i-idx] = encryptedDataAsArray[i]
            }

            var decryptedDataBuffer = [UInt8](repeating: 0, count: blockSize)
            var decryptedDataLength = blockSize

            let status = SecKeyDecrypt(rsaKeyRef, padding, chunkData, idxEnd-idx, &decryptedDataBuffer, &decryptedDataLength)
            if ( status != noErr ) {
                return nil
            }
            let finalData = removePadding(decryptedDataBuffer)
            decryptedData += finalData

            idx += blockSize
        }

        return Data(bytes: UnsafePointer<UInt8>(decryptedData), count: decryptedData.count)
    }
    
    //  Swift-RSAUtils
    //  Created by Thanh Nguyen on 7/10/15.
    static fileprivate func removePadding(_ data: [UInt8]) -> [UInt8] {
        var idxFirstZero = -1
        var idxNextZero = data.count
        for i in 0..<data.count {
            if ( data[i] == 0 ) {
                if ( idxFirstZero < 0 ) {
                    idxFirstZero = i
                } else {
                    idxNextZero = i
                    break
                }
            }
        }
        var newData = [UInt8](repeating: 0, count: idxNextZero-idxFirstZero-1)
        for i in idxFirstZero+1..<idxNextZero {
            newData[i-idxFirstZero-1] = data[i]
        }
        return newData
    }
    
    //  Swift-RSAUtils
    //  Created by Thanh Nguyen on 7/10/15.
    // Verify that the supplied key is in fact a X509 public key and strip the header
    // On disk, a X509 public key file starts with string "-----BEGIN PUBLIC KEY-----",
    // and ends with string "-----END PUBLIC KEY-----"
    static fileprivate func stripPublicKeyHeader(_ pubkey: Data) -> Data? {
        if ( pubkey.count == 0 ) {
            return nil
        }
        
        var keyAsArray = [UInt8](repeating: 0, count: pubkey.count / MemoryLayout<UInt8>.size)
        (pubkey as NSData).getBytes(&keyAsArray, length: pubkey.count)
        
        var idx = 0
        if (keyAsArray[idx] != 0x30) {
            return nil
        }
        idx += 1
        
        if (keyAsArray[idx] > 0x80) {
            idx += Int(keyAsArray[idx]) - 0x80 + 1
        } else {
            idx += 1
        }
        
        let seqiod = [UInt8](arrayLiteral: 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00)
        for i in idx..<idx+15 {
            if ( keyAsArray[i] != seqiod[i-idx] ) {
                return nil
            }
        }
        idx += 15
        
        if (keyAsArray[idx] != 0x03) {
            return nil
        }
        idx += 1
        
        if (keyAsArray[idx] > 0x80) {
            idx += Int(keyAsArray[idx]) - 0x80 + 1;
        } else {
            idx += 1
        }
        
        if (keyAsArray[idx] != 0x00) {
            return nil
        }
        idx += 1
        //return pubkey.subdata(in: idx..<keyAsArray.count - idx)
        //return pubkey.subdata(in: NSMakeRange(idx, keyAsArray.count - idx))
        return pubkey.subdata(in: NSMakeRange(idx, keyAsArray.count - idx).toRange()!)
    }
    
    //  Swift-RSAUtils
    //  Created by Thanh Nguyen on 7/10/15.
    // Verify that the supplied key is in fact a PEM RSA private key key and strip the header
    // On disk, a PEM RSA private key file starts with string "-----BEGIN RSA PRIVATE KEY-----",
    // and ends with string "-----END RSA PRIVATE KEY-----"
    static fileprivate func stripPrivateKeyHeader(_ privkey: Data) -> Data? {
        if ( privkey.count == 0 ) {
            return nil
        }

        var keyAsArray = [UInt8](repeating: 0, count: privkey.count / MemoryLayout<UInt8>.size)
        (privkey as NSData).getBytes(&keyAsArray, length: privkey.count)

        //magic byte at offset 22, check if it's actually ASN.1
        var idx = 22
        if ( keyAsArray[idx] != 0x04 ) {
            return nil
        }
        idx += 1
        
        //now we need to find out how long the key is, so we can extract the correct hunk
        //of bytes from the buffer.
        var len = Int(keyAsArray[idx])
        idx += 1
        let det = len & 0x80 //check if the high bit set
        if (det == 0) {
            //no? then the length of the key is a number that fits in one byte, (< 128)
            len = len & 0x7f
        } else {
            //otherwise, the length of the key is a number that doesn't fit in one byte (> 127)
            var byteCount = Int(len & 0x7f)
            if (byteCount + idx > privkey.count) {
                return nil
            }
            //so we need to snip off byteCount bytes from the front, and reverse their order
            var accum: UInt = 0
            var idx2 = idx
            idx += byteCount
            while (byteCount > 0) {
                //after each byte, we shove it over, accumulating the value into accum
                accum = (accum << 8) + UInt(keyAsArray[idx2])
                idx2 += 1
                byteCount -= 1
            }
            // now we have read all the bytes of the key length, and converted them to a number,
            // which is the number of bytes in the actual key.  we use this below to extract the
            // key bytes and operate on them
            len = Int(accum)
        }

        //return privkey.subdata(in: idx..<len)
        //return privkey.subdata(in: NSMakeRange(idx, len))
        return privkey.subdata(in: NSMakeRange(idx, len).toRange()!)
    }
    
    //  Swift-RSAUtils
    //  Created by Thanh Nguyen on 7/10/15.
    // Delete any existing RSA key from keychain
    static public func deleteRSAKeyFromKeychain(_ tagName: String) {
        let queryFilter: [String: AnyObject] = [
            String(kSecClass)             : kSecClassKey,
            String(kSecAttrKeyType)       : kSecAttrKeyTypeRSA,
            String(kSecAttrApplicationTag): tagName as AnyObject
        ]
        SecItemDelete(queryFilter as CFDictionary)
    }
    
    //  Swift-RSAUtils
    //  Created by Thanh Nguyen on 7/10/15.
    // Get a SecKeyRef from keychain
    static public func getRSAKeyFromKeychain(_ tagName: String) -> SecKey? {
        let queryFilter: [String: AnyObject] = [
            String(kSecClass)             : kSecClassKey,
            String(kSecAttrKeyType)       : kSecAttrKeyTypeRSA,
            String(kSecAttrApplicationTag): tagName as AnyObject,
            //String(kSecAttrAccessible)    : kSecAttrAccessibleWhenUnlocked,
            String(kSecReturnRef)         : true as AnyObject
        ]

        var keyPtr: AnyObject?
        let result = SecItemCopyMatching(queryFilter as CFDictionary, &keyPtr)
        if ( result != noErr || keyPtr == nil ) {
            return nil
        }
        return keyPtr as! SecKey?
    }
    
    //  Swift-RSAUtils
    //  Created by Thanh Nguyen on 7/10/15.
    // Add a RSA private key to keychain and return its SecKeyRef
    // privkeyBase64: RSA private key in base64 (data between "-----BEGIN RSA PRIVATE KEY-----" and "-----END RSA PRIVATE KEY-----")
    static public func addRSAPrivateKey(_ privkeyBase64: String, tagName: String) -> SecKey? {
        return addRSAPrivateKey(privkey: base64Decode(privkeyBase64), tagName: tagName)
    }
    
    //  Swift-RSAUtils
    //  Created by Thanh Nguyen on 7/10/15.
    static fileprivate func addRSAPrivateKey(privkey: Data, tagName: String) -> SecKey? {
        // Delete any old lingering key with the same tag
        deleteRSAKeyFromKeychain(tagName)

        // Add persistent version of the key to system keychain
        // var prt: AnyObject?
        let queryFilter = [
            String(kSecClass)              : kSecClassKey,
            String(kSecAttrKeyType)        : kSecAttrKeyTypeRSA,
            String(kSecAttrApplicationTag) : tagName,
            //String(kSecAttrAccessible)     : kSecAttrAccessibleWhenUnlocked,
            String(kSecValueData)          : privkey,
            String(kSecAttrKeyClass)       : kSecAttrKeyClassPrivate,
            String(kSecReturnPersistentRef): true
        ] as [String : Any]
        let result = SecItemAdd(queryFilter as CFDictionary, nil)
        if ((result != noErr) && (result != errSecDuplicateItem)) {
            return nil
        }

        return getRSAKeyFromKeychain(tagName)
    }
    
    //  Swift-RSAUtils
    //  Created by Thanh Nguyen on 7/10/15.
    // Add a RSA pubic key to keychain and return its SecKeyRef
    // pubkeyBase64: RSA public key in base64 (data between "-----BEGIN PUBLIC KEY-----" and "-----END PUBLIC KEY-----")
    static public func addRSAPublicKey(_ pubkeyBase64: String, tagName: String) -> SecKey? {
        return addRSAPublicKey(pubkey: base64Decode(pubkeyBase64), tagName: tagName)
    }
    
    //  Swift-RSAUtils
    //  Created by Thanh Nguyen on 7/10/15.
    static fileprivate func addRSAPublicKey(pubkey: Data, tagName: String) -> SecKey? {
        // Delete any old lingering key with the same tag
        deleteRSAKeyFromKeychain(tagName)
        
        // Add persistent version of the key to system keychain
        //var prt1: Unmanaged<AnyObject>?
        let queryFilter = [
            String(kSecClass)              : kSecClassKey,
            String(kSecAttrKeyType)        : kSecAttrKeyTypeRSA,
            String(kSecAttrApplicationTag) : tagName,
            String(kSecValueData)          : pubkey,
            String(kSecAttrKeyClass)       : kSecAttrKeyClassPublic,
            String(kSecReturnPersistentRef): true
        ] as [String : Any]
        let result = SecItemAdd(queryFilter as CFDictionary, nil)
        if ((result != noErr) && (result != errSecDuplicateItem)) {
            return nil
        }
        
        return getRSAKeyFromKeychain(tagName)
    }
    
    //  Swift-RSAUtils
    //  Created by Thanh Nguyen on 7/10/15.
    // Encrypt data with a RSA private key
    // privkeyBase64: RSA private key in base64 (data between "-----BEGIN RSA PRIVATE KEY-----" and "-----END RSA PRIVATE KEY-----")
    // NOT WORKING YET!
    static public func encryptWithRSAPrivateKey(_ data: Data, privkeyBase64: String, keychainTag: String) -> Data? {
        let myKeychainTag = keychainTag + (useKeyHashes ? "-" + String(privkeyBase64.hashValue) : "")
        var keyRef = getRSAKeyFromKeychain(myKeychainTag)
        if ( keyRef == nil ) {
            keyRef = addRSAPrivateKey(privkeyBase64, tagName: myKeychainTag)
        }
        if ( keyRef == nil ) {
            return nil
        }

        return encryptWithRSAKey(data, rsaKeyRef: keyRef!, padding: SecPadding.PKCS1)
    }
    
    //  Swift-RSAUtils
    //  Created by Thanh Nguyen on 7/10/15.
    // Encrypt data with a RSA public key
    // pubkeyBase64: RSA public key in base64 (data between "-----BEGIN PUBLIC KEY-----" and "-----END PUBLIC KEY-----")
    static public func encryptWithRSAPublicKey(_ data: Data, pubkeyBase64: String, keychainTag: String) -> Data? {
        let myKeychainTag = keychainTag + (useKeyHashes ? "-" + String(pubkeyBase64.hashValue) : "")
        var keyRef = getRSAKeyFromKeychain(myKeychainTag)
        if ( keyRef == nil ) {
            keyRef = addRSAPublicKey(pubkeyBase64, tagName: myKeychainTag)
        }
        if ( keyRef == nil ) {
            return nil
        }

        return encryptWithRSAKey(data, rsaKeyRef: keyRef!, padding: SecPadding.PKCS1)
    }
    
    //  Swift-RSAUtils
    //  Created by Thanh Nguyen on 7/10/15.
    // Decrypt an encrypted data with a RSA private key
    // privkeyBase64: RSA private key in base64 (data between "-----BEGIN RSA PRIVATE KEY-----" and "-----END RSA PRIVATE KEY-----")
    static public func decryptWithRSAPrivateKey(_ encryptedData: Data, privkeyBase64: String, keychainTag: String) -> Data? {
        let myKeychainTag = keychainTag + (useKeyHashes ? "-" + String(privkeyBase64.hashValue) : "")
        var keyRef = getRSAKeyFromKeychain(myKeychainTag)
        if ( keyRef == nil ) {
            keyRef = addRSAPrivateKey(privkeyBase64, tagName: myKeychainTag)
        }
        if ( keyRef == nil ) {
            return nil
        }

        return decryptWithRSAKey(encryptedData, rsaKeyRef: keyRef!, padding: SecPadding())
    }
    
    //  Swift-RSAUtils
    //  Created by Thanh Nguyen on 7/10/15.
    // Decrypt an encrypted data with a RSA public key
    // pubkeyBase64: RSA public key in base64 (data between "-----BEGIN PUBLIC KEY-----" and "-----END PUBLIC KEY-----")
    static public func decryptWithRSAPublicKey(_ encryptedData: Data, pubkeyBase64: String, keychainTag: String) -> Data? {
        let myKeychainTag = keychainTag + (useKeyHashes ? "-" + String(pubkeyBase64.hashValue) : "")
        var keyRef = getRSAKeyFromKeychain(myKeychainTag)
        if ( keyRef == nil ) {
            keyRef = addRSAPublicKey(pubkeyBase64, tagName: myKeychainTag)
        }
        if ( keyRef == nil ) {
            return nil
        }

        return decryptWithRSAKey(encryptedData, rsaKeyRef: keyRef!, padding: SecPadding())
    }
    
    static public func generateRSAKeyPair(tagName: String) -> (SecKey?, SecKey?) {
        let tag = tagName.data(using: .utf8)!
         let attributes: [String: Any] =
             [kSecAttrKeyType as String:            kSecAttrKeyTypeRSA,
              kSecAttrKeySizeInBits as String:      2048,
              kSecPrivateKeyAttrs as String:
                 [kSecAttrIsPermanent as String:    true,
                  kSecAttrApplicationTag as String: tag]
         ]
        var error: Unmanaged<CFError>?
        
        let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error)
        
        let publicKey = SecKeyCopyPublicKey(privateKey!)
        
        return (publicKey, privateKey)
    }
    
    static public func createRSASignature(privateKey: SecKey, data: CFData) ->  Data? {
        SecKeyIsAlgorithmSupported(privateKey, .sign, signingAlgorithm)
        var error: Unmanaged<CFError>?
        let signature = SecKeyCreateSignature(privateKey,
                                                    signingAlgorithm,
                                                    data as CFData,
                                                    &error) as Data?
        return signature
    }
    
    
    static public func verifyRSASignature(publicKey: SecKey, signature: CFData, data: CFData) -> Bool {
        SecKeyIsAlgorithmSupported(publicKey, .verify, signingAlgorithm)
        
        var error: Unmanaged<CFError>?
        return SecKeyVerifySignature(publicKey,
                                    signingAlgorithm,
                                    data as CFData,
                                    signature as CFData,
                                    &error)
    }
    
    static public func secKeyToString(key: SecKey?) -> String?{
        var error:Unmanaged<CFError>?
        if let cfdata = SecKeyCopyExternalRepresentation(key!, &error) {
           let data:Data = cfdata as Data
           let b64Key = data.base64EncodedString()
           
           return b64Key
        }
        return ""
    }
    static public func secKeyToData(key: SecKey?) -> Data?{
         var error:Unmanaged<CFError>?
         if let cfdata = SecKeyCopyExternalRepresentation(key!, &error) {
            let data:Data = cfdata as Data
            
            return data
         }
         return nil
     }
    
    static public func stringTosecKey(b64Key: String?) -> SecKey?{
        guard let data2 = Data.init(base64Encoded: b64Key!) else {
           return nil
        }

        let keyDict:[NSObject:NSObject] = [
           kSecAttrKeyType: kSecAttrKeyTypeRSA,
           kSecAttrKeyClass: kSecAttrKeyClassPublic,
           kSecAttrKeySizeInBits: NSNumber(value: 512),
           kSecReturnPersistentRef: true as NSObject
        ]

        guard let publicKey = SecKeyCreateWithData(data2 as CFData, keyDict as CFDictionary, nil) else {
            return nil
        }
        
        return publicKey
    }
}
