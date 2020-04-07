//
//  User+CoreDataProperties.swift
//  covidIsolate
//
//  Created by luick klippel on 04.04.20.
//  Copyright © 2020 luick klippel. All rights reserved.
//
//

import Foundation
import CoreData


extension User : Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }

    @NSManaged public var keyPairChainTagName: String?
    @NSManaged public var id: String?
    @NSManaged public var infectiousIdentifier: Bool
    @NSManaged public var dailySync: Bool
    @NSManaged public var registrationDate: Date

}
