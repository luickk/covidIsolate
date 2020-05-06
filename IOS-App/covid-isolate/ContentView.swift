//
//  ContentView.swift
//  covid-isolate
//
//  Created by luick klippel on 04.04.20.
//  Copyright © 2020 luick klippel. All rights reserved.
//

import SwiftUI
import CoreBluetooth

class MainClass: ObservableObject {
   public var ToggleSwitchState = false
    init(){}
}

struct ContentView: View {
    
    // ui declarations
    @State private var toggle_ct : Bool = true
    @Environment(\.managedObjectContext) var context
    
    @ObservedObject var oMainClass = MainClass()
    
    @State private var user:cIUtils.User = cIUtils.User(id: "", dailySync: false, infectiousIdentifier: false, registrationDate: Date(), keyPairChainTagName: "")
    
    @State private var contactList: [ContactList] = [ContactList]()
    
    @State var showKeyPrivateAlert = false
    @State var infectiousStatusCheckAlert = false
    @State var showKeyPublicAlert = false
    @State var showGenTestPCId = false
    @State var showGenTestPCIdVerify = false
    
    @State var infectionStatusCheck: String = "...."
    
    let appDel = UIApplication.shared.delegate as! AppDelegate
    
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
                    // Text("Contact Tracing")
                    Text("Contact Tracing: \(ToggleAction(State: toggle_ct))")
                }
                .padding()
                Button(action: {
                   self.infectionStatusButtonCheck()
                }) {
                   Text("Check infection status")
                }
                .padding()
                Text(infectionStatusCheck).padding()
                
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
                    Alert(title: Text("Your Private Key: "), message:     Text(Data(RSACrypto.secKeyToString(key: RSACrypto.getRSAKeyFromKeychain(user.keyPairChainTagName+"-private"))!.utf8).base64EncodedString()), dismissButton: .default(Text("I'll keep it secret!")))
                }
                Button(action: {
                   self.showKeyPublicAlert = true
                }) {
                   Text("Show secret public key")
                       .foregroundColor(Color.red)
                    .padding([ .leading, .trailing])
               }
                .alert(isPresented: self.$showKeyPublicAlert) {
                    print(RSACrypto.secKeyToString(key: RSACrypto.getRSAKeyFromKeychain(user.keyPairChainTagName+"-public")))
                    
                    return Alert(title: Text("Your Public Key: "), message:     Text(Data(RSACrypto.secKeyToString(key: RSACrypto.getRSAKeyFromKeychain(user.keyPairChainTagName+"-public"))!.utf8).base64EncodedString()
                    ), dismissButton: .default(Text("I'll keep it secret!")))
                }
                Button(action: {
                      cIUtils.deleteAllData(context: self.context ,entity: "ContactList")
                      do {
                          try self.context.save()
                      } catch {
                      }
                      self.contactList = cIUtils.fetchContactList(context: self.context, limit: 30)
                  }) {
                    Text("Reset Contact List")
                        .foregroundColor(Color.red)
                     .padding([ .leading, .trailing])
                }
                Divider()
                
                Button(action: {
                    self.contactList = cIUtils.fetchContactList(context: self.context, limit: 30)
                }) {
                    Text("Contacts (click to refresh)")
                }.padding()
                    .foregroundColor(.black)
                
                Divider()
                
                List(self.contactList) { contact in
                    VStack(alignment: .leading) {
                        Text("CID: ").font(.caption).fontWeight(.thin) + Text(contact.contactId!.base64EncodedString().prefix(10) + "...")
                            .font(.caption)
                        Text(contact.dateTime!)
                            .fontWeight(.thin)
                            .font(.caption)
                        Text(String(contact.distance))
                            .fontWeight(.thin)
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.horizontal)
        }
        .onAppear(perform: {
            self.user = cIUtils.fetchSingleUserFromCoreDb(context: self.context)!
            self.contactList = cIUtils.fetchContactList(context: self.context, limit: 30)
        })
    }
    
    func ToggleAction(State: Bool) -> String {
        if (State != oMainClass.ToggleSwitchState)
        {
            oMainClass.ToggleSwitchState = State
            if State {
                self.appDel.bleCentralManager.startScannig()
                self.appDel.blePeripheralManager.startAdvertising()
            } else {
                self.appDel.bleCentralManager.stopScanning()
                self.appDel.blePeripheralManager.stopAdvertising()
            }
        }
        return String(State)
    }
    
    func infectionStatusButtonCheck() {
        let amountOfContactsToCheck = 100
        let fileName = "key.csv"
        let remoteInfectiousKeyCSVPath = "https://cy8berpunk.com/key.csv"

        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
          cIUtils.fetchInfectiousContactKeyCSV(remoteUrl: URL(string: remoteInfectiousKeyCSVPath)!, localUrl: dir.appendingPathComponent(fileName)) { result in
                switch result {
                  case true:
                      let infectiousContactsDates = cIUtils.infectionStatusCheck(context: self.context, localUrl: dir.appendingPathComponent(fileName), forTheLastContacts: amountOfContactsToCheck)
                      print(infectiousContactsDates)
                      if infectiousContactsDates.count <= 0 {
                          self.infectionStatusCheck = "You were NOT in contact with somebody infectious for the last "+String(amountOfContactsToCheck)+" contacts"
                      } else {
                          self.infectionStatusCheck = "You were in contact with somebody infectious at: " + infectiousContactsDates.joined(separator: ",")
                      }
                  case false:
                      self.infectionStatusCheck = "error while downloading"
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
