//
//  ExposureNotificationVC.swift
//  BLE Peripheral Emulator
//
//  Created by Steve Graesser on 4/11/20.
//  Copyright © 2020 White Lab Consulting. All rights reserved.
//

import UIKit
import CoreBluetooth
import os.log

let contactDetectionService = CBUUID(string: "FD6F")
let contactDetectionUUID = CBUUID(string: "FD6F")
let majorVersion: Int8 = 0x01
let minorVersion: Int8 = 0x00

class ExposureNotificationVC: UIViewController {
	private var peripheralManager: CBPeripheralManager!
	
	private var temporaryExposureKey = ""
	private var diagnosisKey = ""
	private var proximityIdentifier = CBUUID(nsuuid: UUID())
	private var rotationInterval: UInt8 = 10
	private var connectedDevices = [CBCentral]()
	private var cdService: CBMutableService!
	private var cdProximityIdentifier: CBMutableCharacteristic!

	@IBOutlet var advertisingSwitch: UISwitch!
	@IBOutlet var peripheralsConnected: UILabel!
	@IBOutlet var proximityIdentifierLabel: UILabel!
	@IBOutlet var updateIntervalSlider: UISlider!
	@IBOutlet var updateIntervalLabel: UILabel!
	
	override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
		peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
		
		cdService = CBMutableService(type: contactDetectionService, primary: true)
		cdProximityIdentifier = CBMutableCharacteristic(type: contactDetectionUUID, properties:  [.read, .notify], value: nil, permissions: .readable)
		cdService.characteristics = [cdProximityIdentifier]
		
		peripheralsConnected.text = String(connectedDevices.count)
		proximityIdentifierLabel.text = proximityIdentifier.uuidString
		updateIntervalSlider.value = Float(rotationInterval)/100.0
		updateIntervalLabel.text = String(rotationInterval)
	}
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

	@IBAction func statusSwitchChanged(_ sender: UISwitch) {
		if sender.isOn {
			peripheralManager.add(cdService)
		}
		else {
			os_log(.debug, "Advertising service stopped")
			peripheralManager.stopAdvertising()
			peripheralManager.remove(cdService)
			
			connectedDevices.removeAll()
			peripheralsConnected.text = String(connectedDevices.count)
		}
	}
	
	@IBAction func batterySliderChanged(_ sender: UISlider) {
		updateIntervalLabel.text = String(Int(sender.value * 100))
	}
}

extension ExposureNotificationVC: CBPeripheralManagerDelegate {
	func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
		switch peripheral.state {
		case .poweredOn:
			os_log(.debug, "Bluetooth is On")
		default:
			os_log(.debug, "Bluetooth is not active")
		}
	}

	func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
		if error == nil {
			let advertisementData: [String : Any] =
				[CBAdvertisementDataServiceUUIDsKey: [cdService.uuid],
				 CBAdvertisementDataLocalNameKey: "Peripheral Emulator"]
			peripheralManager.startAdvertising(advertisementData)
		}
		else {
			os_log(.error, "Error publishing service: %@", String(describing: error))
		}
	}
	
	func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
		if error == nil {
			os_log(.debug, "Advertising service started")
		}
		else {
			os_log(.error, "Error advertising service: %@", String(describing: error))
		}
	}
	
	func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
		var value = Data(count: 16)
		if request.characteristic.uuid == cdProximityIdentifier.uuid {
			value = proximityIdentifier.data
			
			var metaData = Data(count: 4)
			metaData[0] = UInt8((majorVersion << 6) + (minorVersion << 4))
			let transmitPower = Int8.random(in: -90 ... -50)
			metaData[1] = UInt8(truncatingIfNeeded: transmitPower)
			value.append(metaData)
		}
		
		guard value.count > request.offset else {
			peripheralManager.respond(to: request, withResult: .invalidOffset)
			return
		}
		
		request.value = value.subdata(in: request.offset..<value.count)
		peripheralManager.respond(to: request, withResult: .success)
	}
}
