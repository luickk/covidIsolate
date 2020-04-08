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
        bytes.map { String(format: "%02X", $0) }.joined()
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
    
    public static func genStringTimeDateStamp() -> String{
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm,d:MMM:y"
        return formatter.string(for: Date())!
    }
    
    public static func createPersonnalContactId(id: String, timeStamp: String, privateKey: SecKey) -> String {
        let unsignedContactId = (timeStamp+"/"+id).data(using: .utf8)
        let unsignedContactIdHashDigest = SHA512.hash(data: unsignedContactId!).hexStr
        let contactIdSignature = RSACrypto.createRSASignature(privateKey: privateKey, data: unsignedContactIdHashDigest.data(using: .utf8)! as CFData)
        
        let personnalContactId = unsignedContactIdHashDigest+"/"+String(decoding: contactIdSignature!, as: UTF8.self)
        return personnalContactId
    }
    
    
    public static func verifyPersonnalContactId(personnalContactId: String, publicKey: SecKey) -> Bool {
        let splitPersonnalContactId = personnalContactId.components(separatedBy: "/")
        let unsignedContactIdHashDigest = splitPersonnalContactId[0].data(using: .utf8)! as CFData
        let signature = splitPersonnalContactId[1].data(using: .utf8)! as CFData
        return RSACrypto.verifyRSASignature(publicKey: publicKey, signature: signature, data: unsignedContactIdHashDigest)
    }
    
    public static func generateNewUser() -> User {
            let uuid = UUID().uuidString
            let (publicKey, privateKey) = RSACrypto.generateRSAKeyPair(tagName: uuid)
            RSACrypto.addRSAPrivateKey(RSACrypto.secKeyToString(key: privateKey!)!, tagName: uuid+"-private")
            RSACrypto.addRSAPublicKey(RSACrypto.secKeyToString(key: publicKey!)!, tagName: uuid+"-public")
                
            return User(id:uuid, dailySync: false, infectiousIdentifier: false, registrationDate: Date(), keyPairChainTagName: uuid)
    }
}
