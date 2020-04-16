//
//  OwnPublicKeyList+CoreDataProperties.swift
//  covidIsolate
//
//  Created by luick klippel on 15.04.20.
//  Copyright © 2020 luick klippel. All rights reserved.
//
//

import Foundation
import CoreData


extension OwnPublicKeyList {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<OwnPublicKeyList> {
        return NSFetchRequest<OwnPublicKeyList>(entityName: "OwnPublicKeyList")
    }

    @NSManaged public var publicKey: String?
    @NSManaged public var timeDataStamp: String?

}
