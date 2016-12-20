//
//  AAPLFoodPickerViewController.swift
//  Fit
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/7/24.
//
//
/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information

    Abstract:
    A UIViewController subclass that manages the selection of a food item.
*/

import UIKit

@objc(AAPLFoodPickerViewController)
class AAPLFoodPickerViewController: UITableViewController {
    
    var selectedFoodItem: AAPLFoodItem?
    
    private let AAPLFoodPickerViewControllerTableViewCellIdentifier = "cell"
    private let AAPLFoodPickerViewControllerUnwindSegueIdentifier = "AAPLFoodPickerViewControllerUnwindSegueIdentifier"
    
    private var foodItems: [AAPLFoodItem] = []
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // A hard-coded list of possible food items. In your application, you can decide how these should
        // be represented / created.
        self.foodItems = [
            ("Wheat Bagel", 240000.0),
            ("Bran with Raisins", 190000.0),
            ("Regular Instant Coffee", 1000.0),
            ("Banana", 439320.0),
            ("Cranberry Bagel", 416000.0),
            ("Oatmeal", 150000.0),
            ("Fruits Salad", 60000.0),
            ("Fried Sea Bass", 200000.0),
            ("Chips", 190000.0),
            ("Chicken Taco", 170000.0),
            ].map(AAPLFoodItem.init)
    }
    
    //MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.foodItems.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: AAPLFoodPickerViewControllerTableViewCellIdentifier, for: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let foodItem = self.foodItems[indexPath.row]
        
        cell.textLabel!.text = foodItem.name
        
        cell.detailTextLabel!.text = energyFormatter.string(fromJoules: foodItem.joules)
    }
    
    //MARK: - Convenience
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == AAPLFoodPickerViewControllerUnwindSegueIdentifier {
            let indexPathForSelectedRow = self.tableView.indexPathForSelectedRow!
            
            self.selectedFoodItem = self.foodItems[indexPathForSelectedRow.row]
        }
    }
    
    lazy var energyFormatter: EnergyFormatter = {
        
        let formatter = EnergyFormatter()
        formatter.unitStyle = .long
        formatter.isForFoodEnergyUse = true
        formatter.numberFormatter.maximumFractionDigits = 2
        
        return formatter
        }()
    
}
