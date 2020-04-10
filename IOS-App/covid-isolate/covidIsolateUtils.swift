//
//  covidIsolateUtils.swift
//  covidIsolate
//
//  Created by luick klippel on 08.04.20.
//  Copyright © 2020 luick klippel. All rights reserved.
//

import Foundation
import Security
import CommonCrypto
import CryptoKit

// CryptoKit.Digest utils
extension Digest {
    var bytes: [UInt8] { Array(makeIterator()) }
    var data: Data { Data(bytes) }

    var hexStr: String {
        bytes.map { String($0) }.joined()
    }
}

// by stackoverflow
extension String {
    func split(by length: Int) -> [String] {
        var startIndex = self.startIndex
        var results = [Substring]()
        
        print(startIndex)
        while startIndex < self.endIndex {
            let endIndex = self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            print(endIndex)
            results.append(self[startIndex..<endIndex])
            startIndex = endIndex
        }

        return results.map { String($0) }
    }
}

public class cIUtils {
    public struct User {
        var id: String
        var dailySync: Bool
        var infectiousIdentifier: Bool
        var registrationDate: Date
        var keyPairChainTagName: String
    }
    
    static public func splitStr(at: Int, _ val: String) -> [String] {
        var a:String = ""
        var b:String = ""
        var i:Int = 0
        var ind:String.Index
        for _ in val {
            if i > at {
                ind = val.index(val.startIndex, offsetBy: i)
                b = b + String(val[ind])
            } else if i <= at {
                ind = val.index(val.startIndex, offsetBy: i)
                a = a + String(val[ind])
            }
            i += 1
        }
        return [a,b]
    }
    
    public static func genStringTimeDateStamp() -> String{
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm,d:MMM:y"
        return formatter.string(for: Date())!
    }
    
    public static func createPersonnalContactId(id: String, timeStamp: String, privateKey: SecKey) -> [UInt8] {
        let unsignedContactId = (timeStamp+"/"+id).data(using: .utf8)
        var unsignedContactIdHashDigest = [UInt8](SHA256.hash(data: unsignedContactId!).hexStr.data(using: .utf8)!)
        let signedcontactIdSignature = [UInt8](RSACrypto.createRSASignature(privateKey: privateKey, data: NSData(bytes: &unsignedContactIdHashDigest, length: unsignedContactIdHashDigest.count) as CFData)!.base64EncodedData())
        
        print("unsigned hash digest: " + String(bytes: unsignedContactIdHashDigest, encoding: .utf8)!)
        // print("unsigned hash: " + String(unsignedContactIdHashDigest.count))
        print("signed id sig: " + String(bytes: signedcontactIdSignature, encoding: .utf8)!)
        // print("signed id sig: " + String(signedcontactIdSignature.count))
        let personnalContactId = unsignedContactIdHashDigest+signedcontactIdSignature
        // print("pCId: " + String(personnalContactId.count))
        // print("pCId:" + String(bytes: personnalContactId, encoding: .utf8)!)
        // print("------------------------------------------")
        return personnalContactId
    }
    
    
    public static func verifyPersonnalContactId(personnalContactId: [UInt8], publicKey: SecKey) -> Bool {
        let signedHashDigestCount:Int = 344
        var signature = personnalContactId[personnalContactId.index(personnalContactId.startIndex, offsetBy: personnalContactId.count-signedHashDigestCount)...]
        var unsignedContactIdHashDigest = personnalContactId[..<personnalContactId.index(personnalContactId.endIndex, offsetBy: -signedHashDigestCount)]
        print("Signature:"+String(bytes: signature, encoding: .utf8)!)
        print("unsignedContactIdHashDigest:"+String(bytes: unsignedContactIdHashDigest, encoding: .utf8)!)
        
        let cFsignature = CFDataCreate(kCFAllocatorDefault, Array(signature), signature.count)
        let cFunsignedContactIdHashDigest = CFDataCreate(kCFAllocatorDefault, Array(unsignedContactIdHashDigest), unsignedContactIdHashDigest.count)
        print(cFsignature)
        print(cFunsignedContactIdHashDigest)
        
        
        return RSACrypto.verifyRSASignature(publicKey: publicKey, signature: cFsignature!, data: cFunsignedContactIdHashDigest!)
    }
    
    public static func generateNewUser() -> User {
            let uuid = UUID().uuidString
            let (publicKey, privateKey) = RSACrypto.generateRSAKeyPair(tagName: uuid)
            RSACrypto.addRSAPrivateKey(RSACrypto.secKeyToString(key: privateKey!)!, tagName: uuid+"-private")
            RSACrypto.addRSAPublicKey(RSACrypto.secKeyToString(key: publicKey!)!, tagName: uuid+"-public")
                
            return User(id:uuid, dailySync: false, infectiousIdentifier: false, registrationDate: Date(), keyPairChainTagName: uuid)
    }
}
