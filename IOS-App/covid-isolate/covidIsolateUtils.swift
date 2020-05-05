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
import CoreBluetooth

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
    
    public static func fetchInfectiousContactKeyCSV(remoteUrl: URL, localUrl: URL) {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig)
        let request = try! URLRequest(url: remoteUrl)

        let task = session.downloadTask(with: request) { (tempLocalUrl, response, error) in
           if let tempLocalUrl = tempLocalUrl, error == nil {
               // Success
               if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                   print("Success: \(statusCode)")
               }

               do {
                try FileManager.default.removeItem(at: localUrl)
                   
               } catch (let writeError) {
                   print("error deleting file \(localUrl) : \(writeError)")
               }
               do {
                try FileManager.default.copyItem(at: tempLocalUrl, to: localUrl)
                   
               } catch (let writeError) {
                   print("error writing file \(localUrl) : \(writeError)")
               }

           } else {
               print("Failure: %@", error?.localizedDescription);
           }
        }
        task.resume()
    }
    
    // returns array with dates of infectious contacts
    public static func infectionStatusCheck(context: NSManagedObjectContext, localUrl: URL, forTheLastContacts: Int) -> [String]{
        var infectiousContactsDates:[String] = [String]()
        let lastXContacts = self.fetchContactList(context: context, limit: forTheLastContacts)
        do {
            let contents = try String(contentsOf: localUrl, encoding: .utf8)
            let rows = contents.components(separatedBy: "\n")
            for row in rows {
                let infectiousPublicKey = row.components(separatedBy: ";")[0]
                let publicKey:SecKey?
                print(infectiousPublicKey)
                publicKey = RSACrypto.stringTosecKey(b64Key: infectiousPublicKey)
                
                if publicKey != nil {
                    for contact in lastXContacts {
                       let pCIdBytes = [UInt8](contact.contactId!.data(using: .ascii)!)
                       if verifyPersonnalContactId(personnalContactId: pCIdBytes, publicKey: publicKey!) {
                           infectiousContactsDates.append(contact.dateTime!)
                           print("infect found")
                       } else {
                           print("no infect found")
                       }
                    }
                } else {
                    print("invalid key")
                }
            }
        } catch {
           print("File Read Error for file \(localUrl)")
           
       }
        return infectiousContactsDates
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
    
    public static func fetchContactList(context: NSManagedObjectContext, limit: Int) -> [ContactList]{
        var contacts:[ContactList] = [ContactList]()
        do {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ContactList")
            let sort = NSSortDescriptor(key: #keyPath(ContactList.dateTime), ascending: false)
            fetchRequest.sortDescriptors = [sort]
            if limit != 0 {
                fetchRequest.fetchLimit = limit
            }
            contacts = try context.fetch(fetchRequest) as! [covidIsolate.ContactList]
            
        } catch {
        }
        return contacts
    }
    
    public static func byteArray<T>(from value: T) -> [UInt8] where T: FixedWidthInteger {
        withUnsafeBytes(of: value.bigEndian, Array.init)
    }
    
    public static func addContactToContactList(context: NSManagedObjectContext, contactId: String, dateTime: String, distance: Int) {
        let newContact = ContactList(entity: ContactList.entity(), insertInto: context)
        newContact.contactId = contactId
        newContact.dateTime = dateTime
        newContact.distance = distance
        
        do {
            try context.save()
        } catch let error as NSError {
            print("Error While Deleting Note: \(error.userInfo)")
        }
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
