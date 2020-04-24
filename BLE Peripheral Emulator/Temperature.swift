//
//  Temperature.swift
//  BLE Peripheral Emulator
//
//  Created by Steve Graesser on 4/23/20.
//  Copyright © 2020 White Lab Consulting. All rights reserved.
//

import Foundation

struct Temperature: Equatable {
	var celsius: Double = 0
	var fahrenheit: Double {
		get { return celsius * 9 / 5 + 32 }
		set { celsius = (newValue - 32) * 5 / 9 }
	}
}

func ==(lhs: Temperature, rhs: Temperature) -> Bool {
	return lhs.celsius == rhs.celsius
}
