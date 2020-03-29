//
//  HeartRateVC.swift
//  BLE Peripheral Emulator
//
//  Created by Steve Graesser on 3/15/20.
//  Copyright © 2020 Steve Graesser. All rights reserved.
//

import UIKit
import CoreBluetooth

let heartRateService = CBUUID(string: "180D")
let heartRateMeasurementUUID = CBUUID(string: "2A37")
let heartRateSensorLocationUUID = CBUUID(string: "2A38")

class HeartRateVC: UIViewController {
	private var peripheralManager: CBPeripheralManager!
	
	private var heartRate: UInt16 = 50
	private var heartRateFlags: UInt8 = 0x01
	private var bodySensor: UInt8 = 0
	private var energyExpended: UInt16 = 0
	
	private var connectedDevices = [CBCentral]()
	private var hrmService: CBMutableService!
	private var hrmMeasurementCharacteristic: CBMutableCharacteristic!
	private var hrmSensorLocationCharacteristic: CBMutableCharacteristic!

	@IBOutlet var advertisingSwitch: UISwitch!
	@IBOutlet var peripheralsConnected: UILabel!
	@IBOutlet var bodySensorLocationTF: UITextField!
	@IBOutlet var heartRateTF: UITextField!
	@IBOutlet var energyExpendedTF: UITextField!
	
	private var bodySensorValues = [String]()
	private var selectedIndex = 0
	private var pickerView: UIPickerView!

	override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
		peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
		
		hrmService = CBMutableService(type: heartRateService, primary: true)
		hrmMeasurementCharacteristic = CBMutableCharacteristic(type: heartRateMeasurementUUID, properties: [.read, .notify], value: nil, permissions: .readable)
		hrmSensorLocationCharacteristic = CBMutableCharacteristic(type: heartRateSensorLocationUUID, properties: .read, value: nil, permissions: .readable)
		hrmService.characteristics = [hrmMeasurementCharacteristic, hrmSensorLocationCharacteristic]

		peripheralsConnected.text = String(connectedDevices.count)
		heartRateTF.text = String(heartRate)
		
		bodySensorValues = ["Other - 0",
							"Chest - 1",
							"Wrist - 2",
							"Finger - 3",
							"Hand - 4",
							"Ear Lobe - 5",
							"Foot - 6"]
		pickerView = addPickerView(to: bodySensorLocationTF)
		
		heartRateTF.inputAccessoryView = createAccessoryToolbar(with: #selector(doneHeartRateTF(_:)))
		energyExpendedTF.inputAccessoryView = createAccessoryToolbar(with: #selector(doneEnergyExpendedTF(_:)))
    }
    
	// MARK: - Private
	
	private func convertHeartRate() -> Data {
		var value = Data(count: 1)
		if (heartRate < 256) {
			value = Data(count: 2)
			value[0] = heartRateFlags
			value[1] = UInt8(heartRate)
		} else {
			value = Data(count: 3)
			value[0] = heartRateFlags
			value[1] = UInt8(heartRate >> 8)
			value[2] = UInt8(heartRate & 0xFF)
		}
		
		return value
	}

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: - Actions
	
	@IBAction func statusSwitchChanged(_ sender: UISwitch) {
		if sender.isOn {
			peripheralManager.add(hrmService)
		}
		else {
			print("Advertising service stopped")
			peripheralManager.stopAdvertising()
			peripheralManager.remove(hrmService)
			
			connectedDevices.removeAll()
			peripheralsConnected.text = String(connectedDevices.count)
		}
	}
	
	@IBAction func notifyTapped(_ sender: UIButton) {
		let value = convertHeartRate()
		_ = peripheralManager.updateValue(value, for: hrmMeasurementCharacteristic, onSubscribedCentrals: connectedDevices)
	}
	
	// MARK: - UI Setup
	
	func addPickerView(to textField: UITextField) -> UIPickerView {
		let picker = UIPickerView(frame: .zero)
		picker.dataSource = self
		picker.delegate = self
		
		textField.inputView = picker

		// Picker toolbar setup
		let toolbar = createAccessoryToolbar(with: #selector(doneTapped(_:)))
		textField.inputAccessoryView = toolbar
		
		return picker
	}
	
	func createAccessoryToolbar(with action: Selector?) -> UIToolbar {
		let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 44))
		toolbar.barStyle = .default
		toolbar.isTranslucent = true
		let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: action)
		
		// If you remove the space element, the done button will be left aligned
		toolbar.setItems([flexibleSpace, doneButton], animated: true)
		toolbar.isUserInteractionEnabled = true
		toolbar.sizeToFit()
		
		return toolbar
	}
	
	// MARK: - Selector methods
	
	@objc func doneTapped(_ sender: UIBarButtonItem) {
		guard bodySensorValues.count > selectedIndex else { return }
		bodySensor = UInt8(selectedIndex)
		
		bodySensorLocationTF.endEditing(true)
		bodySensorLocationTF.text = bodySensorValues[selectedIndex]
	}
	
	@objc func doneHeartRateTF(_ sender: UIBarButtonItem) {
		heartRate = UInt16(heartRateTF.text ?? "0") ?? 0
		if heartRate > 255 {
			heartRateFlags = 0x01
		}
		else {
			heartRateFlags = 0x00
		}
		
		heartRateTF.endEditing(true)
	}
	
	@objc func doneEnergyExpendedTF(_ sender: UIBarButtonItem) {
		energyExpended = UInt16(heartRateTF.text ?? "0") ?? 0
		
		energyExpendedTF.endEditing(true)
	}
}

extension HeartRateVC: CBPeripheralManagerDelegate {
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
				[CBAdvertisementDataServiceUUIDsKey: [hrmService.uuid],
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
		if request.characteristic.uuid == hrmMeasurementCharacteristic.uuid {
			value = convertHeartRate()
		}
		else if request.characteristic.uuid == hrmSensorLocationCharacteristic.uuid {
			value[0] = bodySensor
		}
		else {
			peripheralManager.respond(to: request, withResult: .attributeNotFound)
		}

		guard value.count > request.offset else {
			peripheralManager.respond(to: request, withResult: .invalidOffset)
			return
		}
		
		request.value = value.subdata(in: request.offset..<value.count)
		peripheralManager.respond(to: request, withResult: .success)
	}
	
	func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
		if !connectedDevices.contains(central) {
			connectedDevices.append(central)
			peripheralsConnected.text = String(connectedDevices.count)
			
			if characteristic == hrmMeasurementCharacteristic {
				let value = convertHeartRate()
				_ = peripheral.updateValue(value, for: hrmMeasurementCharacteristic, onSubscribedCentrals: connectedDevices)
			}
		}
	}
	
	func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
		if connectedDevices.contains(central) {
			connectedDevices.removeAll(where: { $0 == central })
			peripheralsConnected.text = String(connectedDevices.count)
		}
	}
}

extension HeartRateVC: UIPickerViewDataSource {
	func numberOfComponents(in pickerView: UIPickerView) -> Int {
		return 1
	}
	
	func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		var numOfRows = 0
		if pickerView == self.pickerView {
			numOfRows = bodySensorValues.count
		}
		
		return numOfRows
	}
}

extension HeartRateVC: UIPickerViewDelegate {
	func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
		var title = ""
		if pickerView == self.pickerView {
			title = bodySensorValues[row]
		}
		
		return title
	}
	
	func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		if pickerView == self.pickerView {
			selectedIndex = row
		}
	}
}
