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
	@IBOutlet var heartRateMonitor: UIButton!
	@IBOutlet var healthThermometer: UIButton!

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view.
		battery.isHidden = true
		
		// Make our button corners rounded
		battery.layer.cornerRadius = 4
		heartRateMonitor.layer.cornerRadius = 4
		healthThermometer.layer.cornerRadius = 4
	}

}

