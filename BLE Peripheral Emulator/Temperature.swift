//
//  Temperature.swift
//  BLE Peripheral Emulator
//
//  Created by Steve Graesser on 4/23/20.
//  Copyright © 2020 White Lab Consulting. All rights reserved.
//

import Foundation

class Temperature {
	var celsius: Double = 0
	var fahrenheit: Double { return celsius * 9 / 5 + 32 }
	
	init(celsius: Double) {
		self.celsius = celsius
	}
	
	init(fahrenheit: Double) {
		self.celsius = (fahrenheit - 32) * 5 / 9
	}
}
