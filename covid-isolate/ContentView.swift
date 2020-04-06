//
//  ContentView.swift
//  covid-isolate
//
//  Created by luick klippel on 04.04.20.
//  Copyright © 2020 luick klippel. All rights reserved.
//

import SwiftUI



struct ContentView: View {
    @State private var toggle_beacon : Bool = true
    @State private var toggle_listening : Bool = true
    @Environment(\.managedObjectContext) var context

    @FetchRequest(
        entity: User.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \User.id, ascending: true)
        ]
    ) var users: FetchedResults<User>
    
    
    @FetchRequest(
        entity: ContactList.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ContactList.contactId, ascending: true)
        ]
    ) var contactlist: FetchedResults<ContactList>
    
    var body: some View {
        Group {
            VStack(alignment: .center) {
                
                Text("Covid Isolation App")
                    .font(.title)
                    
                    
                Text("App designed to identify contacts in the past")
                    .font(.caption)
                    .fontWeight(.thin)
                Text("with infectious subjects ")
                    .font(.caption)
                    .fontWeight(.thin)
                
                Toggle(isOn: $toggle_beacon) {
                    Text("Beacon")
                }
                .padding()
                Toggle(isOn: $toggle_listening) {
                    Text("Listening")
                }
                .padding()
                Button(action: {}) {
                    Text("Check infection status")
                }
                .padding()
                
            }
            .padding(.horizontal)

            VStack(alignment: .center) {
                Divider()
                
                Text("Personnal Data").padding()
                
                ForEach(users) { user in
                    VStack(alignment: .leading) {
                        Text("ID: ").fontWeight(.thin) + Text(user.id!)
                            .font(.caption)
                        Text("Public Key: ").fontWeight(.thin) + Text(user.publicKey!)
                            .font(.caption)
                        Text("Private Key: ").fontWeight(.thin) + Text(user.privateKey!)
                            .font(.caption)
                    }
                }
                Button(action: {}) {
                    Text("Show Personnal Contact ID's")
                }
                .padding()
            }
            .padding(.horizontal)
            
            VStack(alignment: .center) {
                Divider()
                
                Text("Contacts").padding()
                
                ForEach(contactlist) { contact in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading) {
                            Text("CID: ").font(.caption).fontWeight(.thin) + Text(contact.contactId!)
                                .font(.caption)
                            Text(contact.dateTime!)
                                .fontWeight(.thin)
                                .font(.caption)
                            Divider()
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
