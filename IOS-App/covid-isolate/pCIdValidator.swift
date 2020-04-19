//
//  pCIdValidator.swift
//  covidIsolate
//
//  Created by luick klippel on 19.04.20.
//  Copyright © 2020 luick klippel. All rights reserved.
//

import Foundation
import CoreBluetooth
import CoreData

public class pCIdValidator :NSObject {
    func Init() {
        
    }
    
    public func addPCIdEntry(personnalContactId: Data, context: NSManagedObjectContext) {
        let pCIdListEntry = PersonnalContactIdList(entity: PersonnalContactIdList.entity(), insertInto: context)
        pCIdListEntry.contactId = personnalContactId.base64EncodedString()
        print("added pCId to pCId List")
    }
    
    public func regPCId(personnalContactId: [UInt8], peripheral: CBPeripheral) {
        
    }
}
