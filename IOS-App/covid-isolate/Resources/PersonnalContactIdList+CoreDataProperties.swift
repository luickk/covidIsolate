//
//  PersonnalContactIdList+CoreDataProperties.swift
//  covidIsolate
//
//  Created by luick klippel on 07.04.20.
//  Copyright © 2020 luick klippel. All rights reserved.
//
//

import Foundation
import CoreData


extension PersonnalContactIdList {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PersonnalContactIdList> {
        return NSFetchRequest<PersonnalContactIdList>(entityName: "PersonnalContactIdList")
    }

    @NSManaged public var userId: String?
    @NSManaged public var contactId: String?
    @NSManaged public var dateTime: String?

}
