//
//  BLEManager.swift
//  covidIsolate
//
//  Created by luick klippel on 12.04.20.
//  Copyright © 2020 luick klippel. All rights reserved.
//

import SwiftUI
import Foundation
import UIKit
import CoreBluetooth
import CoreData
import os

class BLEPeripheral : NSObject {

    public static let covidIsolateServiceUUID = CBUUID(string: "86223527-b64e-475d-b646-bc45127e1cbb")
    
    public static let characteristicUUID = CBUUID(string: "87aa09fa-7345-406b-8f92-f12f6ba3eceb")
    
    public static var loaded = false
    
    let personnalContactIdSize = 320
    var receiveBuffer:Data = Data()
    
    var peripheralManager: CBPeripheralManager!
    var delContext = NSManagedObjectContext()

    var transferCharacteristic: CBMutableCharacteristic?
    var connectedCentral: CBCentral?
    var dataToSend = Data()
    var sendDataIndex: Int = 0
    
    // MARK: - View Lifecycle
    
    func loadBLEPeripheral(context: NSManagedObjectContext) {
        Alert(title: Text("Info"), message:     Text("listener loaded"), dismissButton: .default(Text("ok")))
        BLEPeripheral.loaded = true
        self.delContext = context
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [BLEPeripheral.covidIsolateServiceUUID]])
    }
    
    func stopBLEPeripheral() {
        BLEPeripheral.loaded = false
        peripheralManager.stopAdvertising()
        os_log("Adertising stopped")

        receiveBuffer.removeAll(keepingCapacity: false)
        dataToSend.removeAll(keepingCapacity: false)
        sendDataIndex = 0
    }
    
    // peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [TransferService.serviceUUID]])
    // peripheralManager.stopAdvertising()

    /*
     *  Sends the next amount of data to the connected central
     */
    static var sendingEOM = true
    
    func sendData() {
        
        guard let transferCharacteristic = transferCharacteristic else {
            return
        }
        
        // First up, check if we're meant to be sending an EOM
        if BLEPeripheral.sendingEOM {
            // send it
            let didSend = peripheralManager.updateValue("EOM".data(using: .utf8)!, for: transferCharacteristic, onSubscribedCentrals: nil)
            // Did it send?
            if didSend {
                // It did, so mark it as sent
                BLEPeripheral.sendingEOM = false
                os_log("Sent: EOM")
            }
            // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
            return
        }
        
        // We're not sending an EOM, so we're sending data
        // Is there any left to send?
        if sendDataIndex >= dataToSend.count {
            // No data left.  Do nothing
            return
        }
        
        // There's data left, so send until the callback fails, or we're done.
        var didSend = true
        while didSend {
            
            // Work out how big it should be
            var amountToSend = dataToSend.count - sendDataIndex
            if let mtu = connectedCentral?.maximumUpdateValueLength {
                amountToSend = min(amountToSend, mtu)
            }
            
            // Copy out the data we want
            let chunk = dataToSend.subdata(in: sendDataIndex..<(sendDataIndex + amountToSend))
            
            // Send it
            didSend = peripheralManager.updateValue(chunk, for: transferCharacteristic, onSubscribedCentrals: nil)
            
            // If it didn't work, drop out and wait for the callback
            if !didSend {
                return
            }
            
            let stringFromData = String(data: chunk, encoding: .ascii)
            
            // It did send, so update our index
            sendDataIndex += amountToSend
            // Was it the last one?
            if sendDataIndex >= dataToSend.count {
                // It was - send an EOM
                
                // Set this so if the send fails, we'll send it next time
                BLEPeripheral.sendingEOM = true
                
                //Send it
                let eomSent = peripheralManager.updateValue("EOM".data(using: .utf8)!,
                                                             for: transferCharacteristic, onSubscribedCentrals: nil)
                
                if eomSent {
                    // It sent; we're all done
                    BLEPeripheral.sendingEOM = false
                    os_log("Sent: EOM")
                }
                return
            }
        }
    }

    public func setupPeripheral() {
        
        // Build our service.
        
        // Start with the CBMutableCharacteristic.
        let transferCharacteristic = CBMutableCharacteristic(type: BLEPeripheral.characteristicUUID,
                                                             properties: [.notify, .writeWithoutResponse],
                                                         value: nil,
                                                         permissions: [.readable, .writeable])
        
        // Create a service from the characteristic.
        let transferService = CBMutableService(type: BLEPeripheral.covidIsolateServiceUUID, primary: true)
        
        // Add the characteristic to the service.
        transferService.characteristics = [transferCharacteristic]
        
        // And add it to the peripheral manager.
        peripheralManager.add(transferService)
        
        // Save the characteristic for later.
        self.transferCharacteristic = transferCharacteristic

    }
}

extension BLEPeripheral: CBPeripheralManagerDelegate {
    // implementations of the CBPeripheralManagerDelegate methods

    internal func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        switch peripheral.state {
        case .poweredOn:
            // ... so start working with the peripheral
            os_log("Peripheral CBManager is powered on")
            setupPeripheral()
        case .poweredOff:
            os_log("Peripheral CBManager is not powered on")
            // In a real app, you'd deal with all the states accordingly
            return
        case .resetting:
            os_log("Peripheral CBManager is resetting")
            // In a real app, you'd deal with all the states accordingly
            return
        case .unauthorized:
            // In a real app, you'd deal with all the states accordingly
            if #available(iOS 13.0, *) {
                switch peripheral.authorization {
                case .denied:
                    os_log("You are not authorized to use Bluetooth")
                case .restricted:
                    os_log("Bluetooth is restricted")
                default:
                    os_log("Unexpected authorization")
                }
            } else {
                // Fallback on earlier versions
            }
            return
        case .unknown:
            os_log("CBManager state is unknown")
            // In a real app, you'd deal with all the states accordingly
            return
        case .unsupported:
            os_log("Bluetooth is not supported on this device")
            // In a real app, you'd deal with all the states accordingly
            return
        @unknown default:
            os_log("A previously unknown peripheral manager state occurred")
            // In a real app, you'd deal with yet unknown cases that might occur in the future
            return
        }
    }

    /*
     *  Catch when someone subscribes to our characteristic, then start sending them data
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        os_log("Central subscribed to characteristic")
        

        let user = cIUtils.fetchSingleUserFromCoreDb(context:self.delContext)!
        
        let personnalContactId = cIUtils.createPersonnalContactId(id: user.id, timeStamp: cIUtils.genStringTimeDateStamp(), privateKey: RSACrypto.getRSAKeyFromKeychain(user.keyPairChainTagName+"-private")!)
        
        // Get the data
        dataToSend = NSData(bytes: personnalContactId, length: personnalContactId.count) as! Data
        
        // Reset the index
        sendDataIndex = 0
        
        // save central
        connectedCentral = central
        
        // Start sending
        sendData()
    }
    
    /*
     *  Recognize when the central unsubscribes
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        os_log("Central unsubscribed from characteristic")
        connectedCentral = nil
    }
    
    /*
     *  This callback comes in when the PeripheralManager is ready to send the next chunk of data.
     *  This is to ensure that packets will arrive in the order they are sent
     */
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        // Start sending again
        sendData()
    }
    
    /*
     * This callback comes in when the PeripheralManager received write to characteristics
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for aRequest in requests {
            guard let requestValue = aRequest.value,
                let stringFromData = String(data: requestValue, encoding: .utf8) else {
                    continue
            }
            receiveBuffer.append(requestValue)
            if receiveBuffer.count == personnalContactIdSize {
                
                receiveBuffer.removeAll()
            }
            os_log("Received write request of %d bytes: %s", requestValue.count, stringFromData)
            
        }
    }
}
