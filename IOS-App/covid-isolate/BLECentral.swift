//
//  BLECentral.swift
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

class BLECentral : NSObject {

    public static let covidIsolateServiceUUID = CBUUID(string: "86223527-b64e-475d-b646-bc45127e1cbb")
    
    public static let characteristicUUID = CBUUID(string: "87aa09fa-7345-406b-8f92-f12f6ba3eceb")
    
    public static var loaded = false
    
    public static var pCIdSize = 0
        
    var centralManager: CBCentralManager!
    
    var user:cIUtils.User?
    var privateKey:SecKey?
    
    private var persistentContainer: NSPersistentContainer?

    var viewContext: NSManagedObjectContext {
       return persistentContainer!.viewContext
    }
    
    let personnalContactIdSize = 320
    var receiveBuffer:Data = Data()
    static var receivedPCIdsCount:Int = 0

    static var contactEventTime:TimeInterval = -60
    
    var discoveredPeripheral: CBPeripheral?
    var transferCharacteristic: CBCharacteristic?
    var connectionIterationsComplete = 0
    
    let defaultIterations = 5     // change this value based on test usecase
    
    var data = Data()
    
    var deviceChache = [CBPeripheral:String]()
    
    static var pCIdExchangeCache = [String:String]()
    var knownDevices = [CBUUID]()

    // MARK: - view lifecycle
    
    public func loadBLECentral(persistentContainer: NSPersistentContainer, user:cIUtils.User, privateKey:SecKey) {
        self.persistentContainer = persistentContainer
        self.user = user
        self.privateKey = privateKey
        BLECentral.loaded = true
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }
    
    public func stopBLECentral() {
        BLECentral.loaded = false
        centralManager.stopScan()
        os_log("Scanning stopped")
        receiveBuffer.removeAll(keepingCapacity: false)
        data.removeAll(keepingCapacity: false)
    }
    
    public func startScannig() {
        retrievePeripheral()
    }
    
    public func stopScanning() {
        centralManager.stopScan()
    }
    // MARK: - Helper Methods
    
    /*
     * We will first check if we are already connected to our counterpart
     * Otherwise, scan for peripherals - specifically for our service's 128bit CBUUID
     */
    public func retrievePeripheral() {
        centralManager.scanForPeripherals(withServices: [BLECentral.covidIsolateServiceUUID],
                                               options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
    
    /*
     *  Call this when things either go wrong, or you're done with the connection.
     *  This cancels any subscriptions if there are any, or straight disconnects if not.
     *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
     */
    private func cleanup() {
        // Don't do anything if we're not connected
        guard let discoveredPeripheral = discoveredPeripheral,
            case .connected = discoveredPeripheral.state else { return }
        
        for service in (discoveredPeripheral.services ?? [] as [CBService]) {
            for characteristic in (service.characteristics ?? [] as [CBCharacteristic]) {
                if characteristic.uuid == BLECentral.characteristicUUID && characteristic.isNotifying {
                    // It is notifying, so unsubscribe
                    self.discoveredPeripheral?.setNotifyValue(false, for: characteristic)
                }
            }
        }
        
        // If we've gotten this far, we're connected, but we're not subscribed, so we just disconnect
//        centralManager.cancelPeripheralConnection(discoveredPeripheral)
    }
}

extension BLECentral: CBCentralManagerDelegate {
    // implementations of the CBCentralManagerDelegate methods
    
    internal func centralManagerDidUpdateState(_ central: CBCentralManager) {

        switch central.state {
        case .poweredOn:
            // ... so start working with the peripheral
            os_log("Central CBManager is powered on")
            retrievePeripheral()
        case .poweredOff:
            os_log("Central CBManager is not powered on")
            // In a real app, you'd deal with all the states accordingly
            return
        case .resetting:
            os_log("CBManager is resetting")
            // In a real app, you'd deal with all the states accordingly
            return
        case .unauthorized:
            // In a real app, you'd deal with all the states accordingly
            if #available(iOS 13.0, *) {
                switch central.authorization {
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
            os_log("A previously unknown central manager state occurred")
            // In a real app, you'd deal with yet unknown cases that might occur in the future
            return
        }
    }

    /*
     *  This callback comes whenever a peripheral that is advertising the transfer serviceUUID is discovered.
     *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
     *  we start the connection process
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Reject if the signal strength is too low to attempt data transfer.
        // Change the minimum RSSI value depending on your app’s use case.
        guard RSSI.intValue >= -100
            else {
                os_log("Discovered perhiperal not in expected range, at %d", RSSI.intValue)
                return
        }
        
        os_log("Discovered %s at %d", String(describing: peripheral.name), RSSI.intValue)
        
        // Device is in range - have we already seen it?
        
        if deviceChache.keys.contains(peripheral) {
            // check if 20 minutes passed
            print(Date().distance(to: cIUtils.TimeDateStampStringToDate(inputString: deviceChache[peripheral]!)!))
            print(BLECentral.receivedPCIdsCount)
            if  Date().distance(to: cIUtils.TimeDateStampStringToDate(inputString: deviceChache[peripheral]!)!) < BLECentral.contactEventTime {
                print("Reconnecting to perhiperal %@", peripheral)
                centralManager.retrieveConnectedPeripherals(withServices: knownDevices)
                deviceChache[peripheral] = cIUtils.genStringTimeDateStamp()
                cIKeyExchange.makePeripheralPCIdReqFromCentral(bleCentral: self, per: peripheral)
            }
        } else {
            os_log("Connecting to perhiperal(without timer) %@", peripheral)
            centralManager.connect(peripheral, options: nil)
            deviceChache[peripheral] = cIUtils.genStringTimeDateStamp()
            knownDevices.append(CBUUID.init(string: peripheral.identifier.uuidString))
        }
    }

    /*
     *  If the connection fails for whatever reason, we need to deal with it.
     */
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        os_log("Failed to connect to %@. %s", peripheral, String(describing: error))
        cleanup()
    }
    
    /*
     *  We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        os_log("Peripheral Connected")
        
        
        // set iteration info
        connectionIterationsComplete += 1
        
        // Clear the data that we may already have
        data.removeAll(keepingCapacity: false)
        
        // Make sure we get the discovery callbacks
        peripheral.delegate = self
        
        // Search only for services that match our UUID
        peripheral.discoverServices([BLECentral.covidIsolateServiceUUID])
    }
    
    /*
     *  Once the disconnection happens, we need to clean up our local copy of the peripheral
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        os_log("Perhiperal Disconnected")
        discoveredPeripheral = nil
        
        // We're disconnected, so start scanning again
        if connectionIterationsComplete < defaultIterations {
            retrievePeripheral()
        } else {
            os_log("Connection iterations completed")
        }
    }

}

extension BLECentral: CBPeripheralDelegate {
    // implementations of the CBPeripheralDelegate methods

    /*
     *  The peripheral letting us know when services have been invalidated.
     */
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        
        for service in invalidatedServices where service.uuid == BLECentral.covidIsolateServiceUUID {
            os_log("Transfer service is invalidated - rediscover services")
            peripheral.discoverServices([BLECentral.covidIsolateServiceUUID])
        }
    }

    /*
     *  The Transfer Service was discovered
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            os_log("Error discovering services: %s", error.localizedDescription)
            cleanup()
            return
        }
        
        // Discover the characteristic we want...
        
        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        guard let peripheralServices = peripheral.services else { return }
        for service in peripheralServices {
            peripheral.discoverCharacteristics([BLECentral.characteristicUUID], for: service)
        }
    }
    
    /*
     *  The Transfer characteristic was discovered.
     *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Deal with errors (if any).
        if let error = error {
            os_log("Error discovering characteristics: %s", error.localizedDescription)
            cleanup()
            return
        }
        
        // Again, we loop through the array, just in case and check if it's the right one
        guard let serviceCharacteristics = service.characteristics else { return }
        for characteristic in serviceCharacteristics where characteristic.uuid == BLECentral.characteristicUUID {
            // If it is, subscribe to it
            transferCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
        }
        
        // Once this is complete, we just need to wait for the data to come in.
    }
    
    /*
     *   This callback lets us know more data has arrived via notification on the characteristic
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Deal with errors (if any)
        if let error = error {
            print("Error discovering characteristics: %s", error.localizedDescription)
            cleanup()
            return
        }
        receiveBuffer.append(characteristic.value!)
        print(receiveBuffer.count)
        if receiveBuffer.count == personnalContactIdSize {
            if BLECentral.pCIdExchangeCache.keys.contains(peripheral.identifier.uuidString) {
                if  Date().distance(to: cIUtils.TimeDateStampStringToDate(inputString: BLECentral.pCIdExchangeCache[peripheral.identifier.uuidString]!)!) < BLECentral.contactEventTime {
                    cIKeyExchange.addPCIdFromCentral(bleCentral: self, peripheral: peripheral, contactId: receiveBuffer.base64EncodedString())
                } else {
                    print("keys already exchanged")
                }
            } else {
                cIKeyExchange.addPCIdFromCentral(bleCentral: self, peripheral: peripheral, contactId: receiveBuffer.base64EncodedString())
            }
        }
        receiveBuffer.removeAll()
    }

    /*
     *  The peripheral letting us know whether our subscribe/unsubscribe happened or not
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // Deal with errors (if any)
        if let error = error {
            os_log("Error changing notification state: %s", error.localizedDescription)
            return
        }
        
        // Exit if it's not the transfer characteristic
        guard characteristic.uuid == BLECentral.characteristicUUID else { return }
        
        if characteristic.isNotifying {
            // Notification has started
            os_log("Notification began on %@", characteristic)
        } else {
            // Notification has stopped, so disconnect from the peripheral
            os_log("Notification stopped on %@. Disconnecting", characteristic)
            cleanup()
        }
        
    }
    
    /*
     *  This is called when peripheral is ready to accept more data when using write without response
     */
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        os_log("Peripheral is ready, send data")
    }
    
}
