//
//  ViewController.swift
//  BLE Peripheral Emulator
//
//  Created by Steve Graesser on 3/15/20.
//  Copyright © 2020 Steve Graesser. All rights reserved.
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
	}

}

