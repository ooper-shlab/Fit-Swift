//
//  AAPLFoodItem.swift
//  Fit
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/7/24.
//
//
/*
    Copyright (C) 2014 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information

    Abstract:

                A simple model class to represent food and its associated energy.

*/

import Foundation
import HealthKit

@objc(AAPLFoodItem)
class AAPLFoodItem: NSObject {
    
    // \c AAPLFoodItem properties are immutable.
    private(set) var name: String
    private(set) var joules: Double
    
    // Creates a new food item.
    init(name: String, joules: Double) {
        
        self.name = name
        self.joules = joules
        
        super.init()
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? AAPLFoodItem {
            return other.joules == self.joules && self.name == other.name
        }
        
        return false
    }
    
    override var description: String {
        return [
            "name": self.name,
            "joules": self.joules
            ].description
    }
    
}
