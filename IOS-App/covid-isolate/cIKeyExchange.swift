//
//  cIKeyExchange.swift
//  covidIsolate
//
//  Created by luick klippel on 02.05.20.
//  Copyright © 2020 luick klippel. All rights reserved.
//

import Foundation
import CoreData
import CoreBluetooth

public class cIKeyExchange {
    
    static func GenAndSendPCIdToCentral(blePeri: BLEPeripheral) {
        
        let timeStamp:String = cIUtils.genStringTimeDateStamp()
        
        let personnalContactId = cIUtils.createPersonnalContactId(id: blePeri.user!.id, timeStamp: timeStamp, privateKey: blePeri.privateKey!)

        // Get the data
        blePeri.dataToSend = Data(bytes: personnalContactId, count: personnalContactId.count)
        // dataToSend = "test-pcid-fromperipheral".data(using: .utf8)!
        
        // Reset the index
        blePeri.sendDataIndex = 0
        
        // Start sending
        blePeri.sendData()
    }

    static func makePeripheralPCIdReqFromCentral(bleCentral: BLECentral, per: CBPeripheral, rssi: Int) {
        if BLECentral.pCIdExchangeCache.keys.contains(per.identifier.uuidString) {
            if  Date().distance(to: cIUtils.TimeDateStampStringToDate(inputString: BLECentral.pCIdExchangeCache[per.identifier.uuidString]!)!) < BLECentral.contactEventTime {
                
                print("MAKING pCId Req")
                
                let timeStamp:String = cIUtils.genStringTimeDateStamp()
                
                let personnalContactId = cIUtils.createPersonnalContactId(id: bleCentral.user!.id, timeStamp: timeStamp, privateKey: bleCentral.privateKey!)
                
                let bytesDataToSend = personnalContactId + withUnsafeBytes(of: rssi, Array.init)
                
                // converting to data object and concatenating pCI(320 bytes) with rssi (+4bytes)
                let dataToSend = Data(bytes: bytesDataToSend, count: bytesDataToSend.count)
                
                if bleCentral.transferCharacteristic != nil{
                    per.writeValue(dataToSend, for: bleCentral.transferCharacteristic!, type: .withoutResponse)
                }
            } else {
                print("already exchanged keys, not making pCId req")
            }
        } else {
            print("MAKING pCId Req")
            
            let timeStamp:String = cIUtils.genStringTimeDateStamp()
            
            let personnalContactId = cIUtils.createPersonnalContactId(id: bleCentral.user!.id, timeStamp: timeStamp, privateKey: bleCentral.privateKey!)
            print(cIUtils.byteArray(from: rssi))
            let bytesDataToSend = personnalContactId + cIUtils.byteArray(from: rssi)
            
            // converting to data object and concatenating pCI(320 bytes) with rssi (+4bytes)
            let dataToSend = Data(bytes: bytesDataToSend, count: bytesDataToSend.count)
            
            if bleCentral.transferCharacteristic != nil{
                per.writeValue(dataToSend, for: bleCentral.transferCharacteristic!, type: .withoutResponse)
            }
        }
    }
    
    static func addPCIdFromPeri(blePeri: BLEPeripheral, peripheral: CBPeripheralManager, contactId: Data, rssi:Int) {
        BLECentral.receivedPCIdsCount += 1
        BLECentral.pCIdExchangeCache[blePeri.connectedCentral!.identifier.uuidString] = cIUtils.genStringTimeDateStamp()
        print("added pCId to pCId List")
        // answering pcid request (pcid request = other devices central pcid)
        GenAndSendPCIdToCentral(blePeri: blePeri)
        cIUtils.addContactToContactList(context: blePeri.viewContext, contactId: contactId, dateTime: cIUtils.genStringTimeDateStamp(), distance: rssi)
    }
    
    static func addPCIdFromCentral(bleCentral: BLECentral, peripheral: CBPeripheral, contactId: Data, rssi:Int) {
        BLECentral.receivedPCIdsCount += 1
        BLECentral.pCIdExchangeCache[peripheral.identifier.uuidString] = cIUtils.genStringTimeDateStamp()
        print("added pCId to pCId List")
        cIUtils.addContactToContactList(context: bleCentral.viewContext, contactId: contactId, dateTime: cIUtils.genStringTimeDateStamp(), distance: rssi)
        bleCentral.centralManager!.cancelPeripheralConnection(peripheral)
    }
}
