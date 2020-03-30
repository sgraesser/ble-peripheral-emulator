//
//  ThermometerVC.swift
//  BLE Peripheral Emulator
//
//  Created by Steve Graesser on 3/28/20.
//  Copyright © 2020 Steve Graesser. All rights reserved.
//

import UIKit
import CoreBluetooth

let healthThermometerService = CBUUID(string: "1809")
let tempatureMeasurementUUID = CBUUID(string: "2A1C")
let measurementIntervalUUID = CBUUID(string: "2A21")

struct TMFlagOptions: OptionSet {
	let rawValue: UInt8
	
	static let tempatureInF		= TMFlagOptions(rawValue: 1 << 0)
	static let timeStamp		= TMFlagOptions(rawValue: 1 << 1)
	static let tempatureType	= TMFlagOptions(rawValue: 1 << 2)
}

class ThermometerVC: UIViewController {
	private var peripheralManager: CBPeripheralManager!
	
	private var tempature: Float = 36.4		// Store internally as C
	private var tempatureFlags: TMFlagOptions = []
	private var measurementInterval: UInt16 = 1
	private var connectedDevices = [CBCentral]()
	private var htService: CBMutableService!
	private var htMeasurementCharacteristic: CBMutableCharacteristic!
	private var htMeasurementIntervalCharacteristic: CBMutableCharacteristic!
	
	@IBOutlet var advertisingSwitch: UISwitch!
	@IBOutlet var peripheralsConnected: UILabel!
	@IBOutlet var tempatureTF: UITextField!
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
		htMeasurementCharacteristic = CBMutableCharacteristic(type: heartRateMeasurementUUID, properties: [.read, .notify], value: nil, permissions: .readable)
		htService.characteristics = [htMeasurementCharacteristic]

		peripheralsConnected.text = String(connectedDevices.count)
		let tempInF = convertCtoF(tempature)
		tempatureTF.text = String(format: "%.1f", tempInF)
		measurementIntervalTF.text = String(measurementInterval)
			
		tempatureTF.inputAccessoryView = createAccessoryToolbar(with: #selector(doneTempatureTF(_:)))
		measurementIntervalTF.inputAccessoryView = createAccessoryToolbar(with: #selector(doneMeasurementIntervalTF(_:)))
		tempatureTF.delegate = self
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
	private func convertTempature() -> Data {
		let exponent:UInt8 = 0xFF
		let mantissa:Int = lroundf(tempature * 10)
		
		var value = Data(count: 5)
		value[0] = tempatureFlags.rawValue
		value[1] = exponent
		value[2] = UInt8(mantissa >> 16)
		value[3] = UInt8(mantissa >> 8)
		value[4] = UInt8(mantissa & 0xFF)
		
		return value
	}
	
	private func convertCtoF(_ tempInC: Float) -> Float {
		let x = (tempInC + 40) * (9/5) - 40
		return x
	}
	
	private func convertFtoC(_ tempInF: Float) -> Float {
		let x = (tempInF + 40) * (5/9) - 40
		return x
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
			print("Advertising service stopped")
			peripheralManager.stopAdvertising()
			peripheralManager.remove(htService)
			
			connectedDevices.removeAll()
			peripheralsConnected.text = String(connectedDevices.count)
		}
	}

	@IBAction func notifyTapped(_ sender: UIButton) {
		let value = convertTempature()
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
		let range = 1...65535
		guard let aNumber = numberFormatter.number(from: measurementIntervalTF.text!),
			range ~= aNumber.intValue else {
			let msg = "Invalid number entered. Please enter a number between \(range.lowerBound) and \(range.upperBound)"
			invalidNumberAlert(msg) { (action) in
				self.measurementIntervalTF.text = String(self.measurementInterval)
			}
			
			return
		}
		measurementInterval = aNumber.uint16Value

		measurementIntervalTF.endEditing(true)
	}
	
	@objc func doneTempatureTF(_ sender: UIBarButtonItem) {
		let range = 0.0..<1000.0
		guard let aNumber = numberFormatter.number(from: tempatureTF.text!),
			range ~= aNumber.doubleValue else {
			let msg = "Invalid number entered. Please enter a number between \(range.lowerBound) and \(range.upperBound)"
			invalidNumberAlert(msg) { (action) in
				let tempInF = self.convertCtoF(self.tempature)
				self.tempatureTF.text = String(format: "%.1f", tempInF)
			}
			
			return
		}
		let tempInF = aNumber.floatValue
		tempature = convertFtoC(tempInF)
		
		// Update the display to show only 1 number after the decimal point
		tempatureTF.text = String(format: "%.1f", tempInF)
		measurementIntervalTF.text = String(measurementInterval)

		tempatureTF.endEditing(true)
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
			print("Bluetooth is On")
		default:
			print("Bluetooth is not active")
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
		if request.characteristic.uuid == htMeasurementCharacteristic.uuid {
			value = convertTempature()
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
				let value = convertTempature()
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
		textField.resignFirstResponder()
		return true
	}
}
