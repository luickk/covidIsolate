//
//  ContentView.swift
//  covid-isolate
//
//  Created by luick klippel on 04.04.20.
//  Copyright © 2020 luick klippel. All rights reserved.
//

import SwiftUI
import CoreBluetooth



struct ContentView: View {
    
    // ui declarations
    @State private var toggle_ct : Bool = true
    @Environment(\.managedObjectContext) var context
    
    @State private var user:cIUtils.User = cIUtils.User(id: "", dailySync: false, infectiousIdentifier: false, registrationDate: Date(), keyPairChainTagName: "")
    
    @State private var contactList:[ContactList] = [ContactList]()

    @State var showKeyPrivateAlert = false
    @State var showKeyPublicAlert = false
    @State var showGenTestPCId = false
    @State var showGenTestPCIdVerify = false
    
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
                
                Toggle(isOn: $toggle_ct) {
                    Text("Contact Tracing")
                }
                .padding()
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
        
            VStack(alignment: .leading) {
                Text("ID: ").fontWeight(.thin) + Text(user.id)
                    .font(.caption)

                Button(action: {
                    self.showKeyPrivateAlert = true
                 }) {
                    Text("Show secret private key")
                        .foregroundColor(Color.red)
                    .padding([.leading, .top, .trailing])
                }
                .alert(isPresented: self.$showKeyPrivateAlert) {
                    Alert(title: Text("Your Private Key: "), message:     Text(RSACrypto.secKeyToString(key: RSACrypto.getRSAKeyFromKeychain(user.keyPairChainTagName+"-private"))!), dismissButton: .default(Text("I'll keep it secret!")))
                }
                Button(action: {
                   self.showKeyPublicAlert = true
                }) {
                   Text("Show secret public key")
                       .foregroundColor(Color.red)
                    .padding([ .leading, .trailing])
               }
                .alert(isPresented: self.$showKeyPublicAlert) {
                    Alert(title: Text("Your Public Key: "), message:     Text(RSACrypto.secKeyToString(key: RSACrypto.getRSAKeyFromKeychain(user.keyPairChainTagName+"-public"))!), dismissButton: .default(Text("I'll keep it secret!")))
                }

                Button(action: {
                    self.showGenTestPCId = true
                }) {
                    Text("gen test PCId")
                        .foregroundColor(Color.red)
                        .padding([ .leading, .trailing])
                }
                 .alert(isPresented: self.$showGenTestPCId) {
                     let pCI = cIUtils.createPersonnalContactId(id: user.id, timeStamp:cIUtils.genStringTimeDateStamp(), privateKey: RSACrypto.getRSAKeyFromKeychain(user.keyPairChainTagName+"-private")!)
                    
                    return Alert(title: Text("Personnal Contact Id"), message: Text(String(bytes: pCI, encoding: .ascii)!), dismissButton: .default(Text("ok")))
                 }
                
                Button(action: {
                    self.showGenTestPCIdVerify = true
                }) {
                    Text("validate generated test PCId")
                        .foregroundColor(Color.red)
                        .padding([ .leading, .trailing])
                }
                 .alert(isPresented: self.$showGenTestPCIdVerify) {
                    let pCI = cIUtils.createPersonnalContactId(id: user.id, timeStamp:cIUtils.genStringTimeDateStamp(), privateKey: RSACrypto.getRSAKeyFromKeychain(user.keyPairChainTagName+"-private")!)
                    
                    return Alert(title: Text("Personnal Contact Id verification"), message:     Text(String(cIUtils.verifyPersonnalContactId(personnalContactId: pCI, publicKey:  RSACrypto.getRSAKeyFromKeychain(user.keyPairChainTagName+"-public")!))), dismissButton: .default(Text("ok")))
                 }
                
                Divider()
                
                Text("Contacts").padding()
                
                Button(action: {
                    self.contactList = cIUtils.fetchContactList(context: self.context)
                }) {
                    Text("refresh")
                }
                .padding()
                
                ScrollView(.vertical, showsIndicators: false) {
                    ForEach(self.contactList) { contact in
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
            .padding(.horizontal)
        }.onAppear(perform: {
            self.user = cIUtils.fetchSingleUserFromCoreDb(context: self.context)!
            self.contactList = cIUtils.fetchContactList(context: self.context)
        })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
