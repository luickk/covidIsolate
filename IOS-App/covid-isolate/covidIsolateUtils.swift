//
//  covidIsolateUtils.swift
//  covidIsolate
//
//  Created by luick klippel on 08.04.20.
//  Copyright © 2020 luick klippel. All rights reserved.
//

import Foundation
import Security
import CoreData
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

public class cIUtils : NSData {
    public struct User {
        var id: String
        var dailySync: Bool
        var infectiousIdentifier: Bool
        var registrationDate: Date
        var keyPairChainTagName: String
    }
    
    public static func fetchSingleUserFromCoreDb(context: NSManagedObjectContext) -> cIUtils.User?{
        var user:cIUtils.User = User(id: "", dailySync: false, infectiousIdentifier: false, registrationDate: Date(), keyPairChainTagName: "")
        do {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "User")
            fetchRequest.fetchLimit = 1
            let objects = try context.fetch(fetchRequest) as! [covidIsolate.User]
            user.id = objects[0].id!
            user.keyPairChainTagName = objects[0].keyPairChainTagName!
            user.infectiousIdentifier = objects[0].infectiousIdentifier
            user.registrationDate = objects[0].registrationDate
            user.dailySync = objects[0].dailySync
            
        } catch {
        }
        return user
    }
    
    public static func fetchContactList(context: NSManagedObjectContext) -> [ContactList]{
        var contacts:[ContactList] = [ContactList]()
        do {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ContactList")
            contacts = try context.fetch(fetchRequest) as! [covidIsolate.ContactList]
            
        } catch {
        }
        return contacts
    }
    
    public static func genStringTimeDateStamp() -> String{
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm,d:MMM:y"
        return formatter.string(for: Date())!
    }
    public static func TimeDateStampStringToDate(inputString:String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm,d:MMM:y"
        return formatter.date(from: inputString)
    }
    
    public static func createPersonnalContactId(id: String, timeStamp: String, privateKey: SecKey) -> [UInt8] {
        let unsignedContactId = (timeStamp+"/"+id).data(using: .utf8)
        
        let unsignedContactIdHashDigest = SHA512.hash(data: unsignedContactId!).bytes
        
        let signedcontactIdSignature = RSACrypto.createRSASignature(privateKey: privateKey, data: CFDataCreate(kCFAllocatorDefault, Array(unsignedContactIdHashDigest), unsignedContactIdHashDigest.count))

        var signedcontactIdSignatureByteBuffer = [UInt8](repeating:0, count: CFDataGetLength(signedcontactIdSignature))
        CFDataGetBytes(signedcontactIdSignature, CFRangeMake(0, CFDataGetLength(signedcontactIdSignature)), &signedcontactIdSignatureByteBuffer)
        
        let personnalContactId = unsignedContactIdHashDigest+signedcontactIdSignatureByteBuffer
        
        return personnalContactId
    }
    
    
    public static func verifyPersonnalContactId(personnalContactId: [UInt8], publicKey: SecKey) -> Bool {
        let signature = personnalContactId[personnalContactId.index(personnalContactId.startIndex, offsetBy: 64)...]
        let unsignedContactIdHashDigest = personnalContactId[..<personnalContactId.index(personnalContactId.endIndex, offsetBy: -256)]
        
        let cFsignature = CFDataCreate(kCFAllocatorDefault, Array(signature), signature.count)
        let cFunsignedContactIdHashDigest = CFDataCreate(kCFAllocatorDefault, Array(unsignedContactIdHashDigest), unsignedContactIdHashDigest.count)
        
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
