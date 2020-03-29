//
//  BatteryServiceVC.swift
//  BLE Peripheral Emulator
//
//  Created by Steve Graesser on 3/15/20.
//  Copyright © 2020 Steve Graesser. All rights reserved.
//

import UIKit
import CoreBluetooth

let batteryServiceUUID = CBUUID(string: "180F")
let batteryLevelUUID = CBUUID(string: "2A19")

class BatteryServiceVC: UIViewController {
	private var peripheralManager: CBPeripheralManager!
	
	private var batteryLevel: UInt8 = 50
	private var connectedDevices = 0
	private var batteryService: CBMutableService!
	private var batteryLevelCharacteristic: CBMutableCharacteristic!

	@IBOutlet var advertisingSwitch: UISwitch!
	@IBOutlet var peripheralsConnected: UILabel!
	@IBOutlet var batteryLevelSlider: UISlider!
	@IBOutlet var batteryLevelLabel: UILabel!
	
	override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
		peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
		
		batteryService = CBMutableService(type: batteryServiceUUID, primary: true)
		batteryLevelCharacteristic = CBMutableCharacteristic(type: batteryLevelUUID, properties: .read, value: nil, permissions: .readable)
		batteryService.characteristics = [batteryLevelCharacteristic]
		
		peripheralsConnected.text = String(connectedDevices)
		batteryLevelSlider.value = Float(batteryLevel)/100.0
		batteryLevelLabel.text = String(batteryLevel)
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
			peripheralManager.add(batteryService)
		}
		else {
			print("Advertising service stopped")
			peripheralManager.stopAdvertising()
			peripheralManager.remove(batteryService)
		}
	}
	
	@IBAction func batterySliderChanged(_ sender: UISlider) {
		batteryLevelLabel.text = String(Int(sender.value * 100))
	}
}

extension BatteryServiceVC: CBPeripheralManagerDelegate {
	func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
		switch peripheral.state {
		case .poweredOn:
			print("Bluetooth is On")
		default:
			print("Bluetooth is not active")
		}
	}

	func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
		if error == nil {
			let advertisementData: [String : Any] =
				[CBAdvertisementDataServiceUUIDsKey: [batteryService.uuid],
				 CBAdvertisementDataLocalNameKey: "Peripheral Emulator"]
			peripheralManager.startAdvertising(advertisementData)
		}
		else {
			print("Error publishing service: \(error?.localizedDescription ?? "unknown")")
		}
	}
	
	func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
		if error == nil {
			print("Advertising service started")
		}
		else {
			print("Error advertising service: \(error?.localizedDescription ?? "unknown")")
		}
	}
	
	func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
		var value = Data(count: 1)
		if request.characteristic.uuid == batteryLevelCharacteristic.uuid {
			value[0] = batteryLevel
		}
		
		guard value.count > request.offset else {
			peripheralManager.respond(to: request, withResult: .invalidOffset)
			return
		}
		
		request.value = value.subdata(in: request.offset..<value.count)
		peripheralManager.respond(to: request, withResult: .success)
	}
}
