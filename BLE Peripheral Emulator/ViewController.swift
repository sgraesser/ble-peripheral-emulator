//
//  ViewController.swift
//  BLE Peripheral Emulator
//
//  Created by Steve Graesser on 3/15/20.
//  Copyright © 2020 White Lab Consulting. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
	
	@IBOutlet var battery: UIButton!
	@IBOutlet var exposureNotification: UIButton!
	@IBOutlet var heartRateMonitor: UIButton!
	@IBOutlet var healthThermometer: UIButton!

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view.
		battery.isHidden = true
		// Can only be shown on iOS 13.6 or earlier
		let version = UIDevice.current.systemVersion
		let hideEN = version.compare("13.6", options: .numeric) == .orderedDescending
		exposureNotification.isHidden = hideEN
		
		// Make our button corners rounded
		battery.layer.cornerRadius = 4
		exposureNotification.layer.cornerRadius = 4
		heartRateMonitor.layer.cornerRadius = 4
		healthThermometer.layer.cornerRadius = 4
	}

}

