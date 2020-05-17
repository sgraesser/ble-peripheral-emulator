//
//  ThermometerVC.swift
//  BLE Peripheral Emulator
//
//  Created by Steve Graesser on 3/28/20.
//  Copyright © 2020 White Lab Consulting. All rights reserved.
//

import UIKit
import CoreBluetooth
import os

let healthThermometerService = CBUUID(string: "1809")
let temperatureMeasurementUUID = CBUUID(string: "2A1C")
let measurementIntervalUUID = CBUUID(string: "2A21")

struct TMFlagOptions: OptionSet {
	let rawValue: UInt8
	
	static let temperatureInF	= TMFlagOptions(rawValue: 1 << 0)
	static let timeStamp		= TMFlagOptions(rawValue: 1 << 1)
	static let temperatureType	= TMFlagOptions(rawValue: 1 << 2)
}

class ThermometerVC: UIViewController {
	private var peripheralManager: CBPeripheralManager!
	
	private var temperature = Temperature(celsius: 36.4)
	private var temperatureFlags: TMFlagOptions = []
	private var measurementInterval: UInt16 = 1
	private var connectedDevices = [CBCentral]()
	private var htService: CBMutableService!
	private var htMeasurementCharacteristic: CBMutableCharacteristic!
	private var htMeasurementIntervalCharacteristic: CBMutableCharacteristic!
	
	@IBOutlet var advertisingSwitch: UISwitch!
	@IBOutlet var peripheralsConnected: UILabel!
	@IBOutlet var temperatureTF: UITextField!
	@IBOutlet var measurementIntervalTF: UITextField!
	@IBOutlet var stackViewTopConstraint: NSLayoutConstraint!
	
	private var topConstraintValue: CGFloat = 0
	private var activeTextField: UITextField!
	private let numberFormatter = NumberFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
		peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
		
		htService = CBMutableService(type: healthThermometerService, primary: true)
		htMeasurementCharacteristic = CBMutableCharacteristic(type: temperatureMeasurementUUID, properties: [.read, .notify], value: nil, permissions: .readable)
		htMeasurementIntervalCharacteristic = CBMutableCharacteristic(type: measurementIntervalUUID, properties: [.read], value: nil, permissions: .readable)
		htService.characteristics = [htMeasurementCharacteristic, htMeasurementIntervalCharacteristic]

		peripheralsConnected.text = String(connectedDevices.count)
		temperatureTF.text = String(format: "%.1f", temperature.fahrenheit)
		measurementIntervalTF.text = String(measurementInterval)
			
		temperatureTF.inputAccessoryView = createAccessoryToolbar(with: #selector(doneTemperatureTF(_:)))
		measurementIntervalTF.inputAccessoryView = createAccessoryToolbar(with: #selector(doneMeasurementIntervalTF(_:)))
		temperatureTF.delegate = self
		measurementIntervalTF.delegate = self
		topConstraintValue = stackViewTopConstraint.constant
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		let center = NotificationCenter.default
		center.addObserver(self, selector: #selector(keyboardWasShown(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
		center.addObserver(self, selector: #selector(keyboardWillBeHidden(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		
		let center = NotificationCenter.default
		center.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
		center.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
	}

	// MARK: - Private
	
	/// Converts a Float value to a 32-bit floating point data type as described in IEEE 11073
	/// - Returns: floating point data representation
	private func convertTemperature() -> Data {
		let exponent:UInt8 = 0xFF
		let mantissa:Int = lround(temperature.celsius * 10)
		
		var value = Data(count: 5)
		value[0] = temperatureFlags.rawValue
		value[1] = exponent
		value[2] = UInt8(mantissa >> 16)
		value[3] = UInt8(mantissa >> 8)
		value[4] = UInt8(mantissa & 0xFF)
		
		return value
	}
	
	private func convertMeasurementInterval() -> Data {
		var value = Data(count: 2)
		value[0] = UInt8(measurementInterval >> 8)
		value[1] = UInt8(measurementInterval & 0xFF)
		
		return value
	}
	
	/// Notifiy the user that an invalid number has been entered.
	/// - Parameters:
	///   - text: Why the number is invalid
	///   - handler: What to do after the alert has been dismissed (e.g. reset the field to the original value)
	private func invalidNumberAlert(_ text: String, handler: ((UIAlertAction) -> Void)? = nil) {
		let alert = UIAlertController(title: "Invalid Input", message: text, preferredStyle: .alert)
		let okButton = UIAlertAction(title: "Ok", style: .default, handler: handler)
		alert.addAction(okButton)
		
		present(alert, animated: true, completion: nil)
	}

	/// Validates the string entered into a UITextField
	/// - Parameters:
	///   - textField: the text field text to validate
	///   - range: the valid range for the number
	///   - previousValue: the string to restore the text field to in case validation fails
	/// - Returns: result of validation
	func validateNumberEntry(_ textField: UITextField, range: ClosedRange<Int>, previousValue: String) -> Result<NSNumber, Error> {
		guard let aNumber = numberFormatter.number(from: textField.text!),
			range ~= aNumber.intValue else {
			let msg = "Invalid number entered. Please enter a number between \(range.lowerBound) and \(range.upperBound)"
			invalidNumberAlert(msg) { (action) in
				textField.text = previousValue
			}
			
			return .failure(ValidationError.outOfRange)
		}
		
		return .success(aNumber)
	}
	
	/// Updates the temperature value after validating the input string
	/// - Returns: true if the number is valid
	func updateTemperature() -> Bool {
		var isValid = true
		
		let currentValue = String(format: "%.1f", temperature.fahrenheit)
		let range = 0...1000
		let result = validateNumberEntry(temperatureTF, range: range, previousValue: currentValue)
		switch result {
		case .success(let aNumber):
			temperature.fahrenheit = aNumber.doubleValue
			
			// Update the display to show only 1 number after the decimal point
			temperatureTF.text = String(format: "%.1f", temperature.fahrenheit)
		case .failure(let error):
			os_log(.error, "Error: %@", String(describing: error))
			isValid = false
		}
		
		return isValid
	}
	
	/// Updates the measurement interval value after validating the input string
	/// - Returns: true if the number is valid
	func updateMeasurementInterval() -> Bool {
		var isValid = true
		
		let range = 1...65535
		let result = validateNumberEntry(measurementIntervalTF, range: range, previousValue: String(measurementInterval))
		switch result {
		case .success(let aNumber):
			measurementInterval = aNumber.uint16Value
		case .failure(let error):
			os_log(.error, "Error: %@", String(describing: error))
			isValid = false
		}
		
		return isValid
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
			peripheralManager.add(htService)
		}
		else {
			os_log(.debug, "Advertising service stopped")
			peripheralManager.stopAdvertising()
			peripheralManager.remove(htService)
			
			connectedDevices.removeAll()
			peripheralsConnected.text = String(connectedDevices.count)
		}
	}

	@IBAction func notifyTapped(_ sender: UIButton) {
		let value = convertTemperature()
		_ = peripheralManager.updateValue(value, for: htMeasurementCharacteristic, onSubscribedCentrals: connectedDevices)
	}
	
	// MARK: - UI Setup
	
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
	
	@objc func doneMeasurementIntervalTF(_ sender: UIBarButtonItem) {
		let validValue = updateMeasurementInterval()
		if validValue {
			measurementIntervalTF.endEditing(true)
		}
	}
	
	@objc func doneTemperatureTF(_ sender: UIBarButtonItem) {
		let validValue = updateTemperature()
		if validValue {
			temperatureTF.endEditing(true)
		}
	}
	
	// Called when the UIKeyboardDidShowNotification is sent.
	@objc func keyboardWasShown(_ notification: Notification) {
		guard
			let info = notification.userInfo as? [String: Any],
			let keyboardRect = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
			let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
			activeTextField != nil,
			topConstraintValue == stackViewTopConstraint.constant else {
			return
		}
		
		var aRect = self.view.frame
		aRect.size.height -= keyboardRect.size.height
		let testFrame = self.activeTextField.convert(self.activeTextField.frame, to: self.view)
		let newTextFieldY = aRect.size.height - 30
		
		// Checking if the text field is really hidden behind the keyboard
		if !aRect.contains(testFrame.origin) {
			UIView.animate(withDuration: duration, delay: 0.0, options: .curveEaseIn, animations: {
				let y = self.view.frame.origin.y - (testFrame.origin.y - newTextFieldY)
				self.stackViewTopConstraint.constant = self.topConstraintValue + y
			}, completion: nil)
		}
	}
	
	// Called when the UIKeyboardWillHideNotification is sent
	@objc func keyboardWillBeHidden(_ notification: Notification) {
		guard
			let info = notification.userInfo as? [String: Any],
			let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
			return
		}
		UIView.animate(withDuration: duration, delay: 0.0, options: .curveEaseIn, animations: {
			self.stackViewTopConstraint.constant = self.topConstraintValue
		}, completion: nil)
	}
}

extension ThermometerVC: CBPeripheralManagerDelegate {
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
				[CBAdvertisementDataServiceUUIDsKey: [htService.uuid],
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
		var value = Data(count: 1)
		if request.characteristic.uuid == htMeasurementCharacteristic.uuid {
			value = convertTemperature()
		}
		else if request.characteristic.uuid == htMeasurementIntervalCharacteristic.uuid {
			value = convertMeasurementInterval()
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
			
			if characteristic == htMeasurementCharacteristic {
				let value = convertTemperature()
				_ = peripheral.updateValue(value, for: htMeasurementCharacteristic, onSubscribedCentrals: connectedDevices)
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

extension ThermometerVC: UITextFieldDelegate {
	func textFieldDidBeginEditing(_ textField: UITextField) {
		activeTextField = textField
	}
	
	func textFieldDidEndEditing(_ textField: UITextField) {
		activeTextField = nil
	}
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		var shouldReturn = true
		
		if textField == temperatureTF {
			shouldReturn = updateTemperature()
			textField.resignFirstResponder()
		}
		else if textField == measurementIntervalTF {
			shouldReturn = updateMeasurementInterval()
			textField.resignFirstResponder()
		}
		
		return shouldReturn
	}
}
