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

struct HRMFlagOptions: OptionSet {
	let rawValue: UInt8
	
	static let bpm16Bit			= HRMFlagOptions(rawValue: 1 << 0)
	static let sensorStatus1	= HRMFlagOptions(rawValue: 1 << 1)
	static let sensorStatus2	= HRMFlagOptions(rawValue: 1 << 2)
	static let energyExpended	= HRMFlagOptions(rawValue: 1 << 3)
	static let rrInterval		= HRMFlagOptions(rawValue: 1 << 4)
}

class HeartRateVC: UIViewController {
	private var peripheralManager: CBPeripheralManager!
	
	private var heartRate: UInt16 = 50
	private var heartRateFlags: HRMFlagOptions = []
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
	
	private var activeTextField: UITextField!

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
		heartRateTF.delegate = self
		energyExpendedTF.delegate = self
    }
    
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		let center = NotificationCenter.default
		center.addObserver(self, selector: #selector(keyboardDidShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
		center.addObserver(self, selector: #selector(keyboardDidHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		let center = NotificationCenter.default
		center.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
		center.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
	}

	// MARK: - Private
	
	private func convertHeartRate() -> Data {
		var value = Data(count: 1)
		if (heartRate < 256) {
			value = Data(count: 2)
			value[0] = heartRateFlags.rawValue
			value[1] = UInt8(heartRate)
		} else {
			value = Data(count: 3)
			value[0] = heartRateFlags.rawValue
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
			heartRateFlags.update(with: .bpm16Bit)
		}
		else {
			heartRateFlags.remove(.bpm16Bit)
		}
		
		heartRateTF.endEditing(true)
	}
	
	@objc func doneEnergyExpendedTF(_ sender: UIBarButtonItem) {
		energyExpended = UInt16(heartRateTF.text ?? "0") ?? 0
		if energyExpended > 0 {
			heartRateFlags.update(with: .energyExpended)
		}
		else {
			heartRateFlags.remove(.energyExpended)
		}
		
		energyExpendedTF.endEditing(true)
	}
	
	@objc func keyboardDidShow(_ notification: Notification) {
		guard
			let info = notification.userInfo as? [String: Any],
			let keyboardRect = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
			activeTextField != nil,
			self.view.frame.origin.y >= 0 else {
			return
		}
		
		var aRect = self.view.frame
		aRect.size.height -= keyboardRect.size.height
		let testFrame = self.activeTextField.convert(self.activeTextField.frame, to: self.view)
		let newTextFieldY = aRect.size.height - 30
		
		// Checking if the text field is really hidden behind the keyboard
		if !aRect.contains(testFrame.origin) {
			UIView.animate(withDuration: 0.25, delay: 0.0, options: .curveEaseIn, animations: {
				let bounds = self.view.bounds
				let y = self.view.frame.origin.y - (testFrame.origin.y - newTextFieldY)
				self.view.frame = CGRect(x: 0, y: y, width: bounds.width, height: bounds.height)
			}, completion: nil)
		}
	}
	
	@objc func keyboardDidHide(_ notification: Notification) {
		UIView.animate(withDuration: 0.25, delay: 0.0, options: .curveEaseIn, animations: {
			let bounds = self.view.bounds
			self.view.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
		}, completion: nil)
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

extension HeartRateVC: UITextFieldDelegate {
	func textFieldDidBeginEditing(_ textField: UITextField) {
		activeTextField = textField
	}
	
	func textFieldDidEndEditing(_ textField: UITextField) {
		activeTextField = nil
	}
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
}
