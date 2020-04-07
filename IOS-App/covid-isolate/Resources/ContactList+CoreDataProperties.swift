//
//  ContactList+CoreDataProperties.swift
//  covidIsolate
//
//  Created by luick klippel on 06.04.20.
//  Copyright © 2020 luick klippel. All rights reserved.
//
//

import Foundation
import CoreData


extension ContactList : Identifiable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ContactList> {
        return NSFetchRequest<ContactList>(entityName: "ContactList")
    }

    @NSManaged public var contactId: String?
    @NSManaged public var dateTime: String?
    @NSManaged public var distance: Int32

}
