//
//  AAPLJournalViewController.swift
//  Fit
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/7/24.
//
//
/*
    Copyright (C) 2014 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information

    Abstract:

                Displays information retrieved from HealthKit about the food items consumed today.

*/

import UIKit
import HealthKit

@objc(AAPLJournalViewController)
class AAPLJournalViewController: UITableViewController, HavingHealthStore {
    
    var healthStore: HKHealthStore?
    
    private var foodItems: [AAPLFoodItem] = []
    
    
    private let AAPLJournalViewControllerTableViewCellReuseIdentifier = "cell"
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.foodItems = []
        
        self.updateJournal()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateJournal", name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    //MARK: - Reading HealthKit Data
    
    private func updateJournal() {
        let calendar = NSCalendar.currentCalendar()
        
        let now = NSDate()
        
        let components = calendar.components([.Year, .Month, .Day], fromDate: now)
        
        let startDate = calendar.dateFromComponents(components)
        
        let endDate = calendar.dateByAddingUnit(.Day, value: 1, toDate: startDate!, options: [])
        
        let foodType = HKObjectType.correlationTypeForIdentifier(HKCorrelationTypeIdentifierFood)!
        
        let predicate = HKQuery.predicateForSamplesWithStartDate(startDate, endDate: endDate, options: .None)
        
        let query = HKSampleQuery(sampleType: foodType, predicate: predicate, limit: Int(HKObjectQueryNoLimit), sortDescriptors: nil) {query, results, error in
            guard let results = results else {
                NSLog("An error occured fetching the user's tracked food. In your app, try to handle this gracefully. The error was: %@.", error!)
                abort()
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                self.foodItems.removeAll()
                
                for foodCorrelation in results as! [HKCorrelation] {
                    // Create an AAPLFoodItem instance that contains the information we care about that's
                    // stored in the food correlation.
                    let foodItem = self.foodItemFromFoodCorrelation(foodCorrelation)
                    
                    self.foodItems.append(foodItem)
                }
                
                self.tableView.reloadData()
            }
        }
        
        self.healthStore?.executeQuery(query)
    }
    
    private func foodItemFromFoodCorrelation(foodCorrelation: HKCorrelation) -> AAPLFoodItem {
        // Fetch the name fo the food.
        let foodName = foodCorrelation.metadata![HKMetadataKeyFoodType] as! String
        
        // Fetch the total energy from the food.
        let energyConsumedType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryEnergyConsumed)!
        let energyConsumedSamples = foodCorrelation.objectsForType(energyConsumedType)
        
        // Note that we only have one energy consumed sample correlation (for Fit specifically).
        let energyConsumedSample = energyConsumedSamples.first! as! HKQuantitySample
        
        let energyQuantityConsumed = energyConsumedSample.quantity
        
        let joules = energyQuantityConsumed.doubleValueForUnit(HKUnit.jouleUnit())
        
        return AAPLFoodItem(name: foodName, joules: joules)
    }
    
    //MARK: - Writing HealthKit Data
    
    private func addFoodItem(foodItem: AAPLFoodItem) {
        // Create a new food correlation for the given food item.
        let foodCorrelationForFoodItem = self.foodCorrelationForFoodItem(foodItem)
        
        self.healthStore?.saveObject(foodCorrelationForFoodItem) {success, error in
            dispatch_async(dispatch_get_main_queue()) {
                if success {
                    self.foodItems.insert(foodItem, atIndex: 0)
                    
                    let indexPathForInsertedFoodItem = NSIndexPath(forRow: 0, inSection: 0)
                    
                    self.tableView.insertRowsAtIndexPaths([indexPathForInsertedFoodItem], withRowAnimation: UITableViewRowAnimation.Automatic)
                } else {
                    NSLog("An error occured saving the food %@. In your app, try to handle this gracefully. The error was: %@.", foodItem.name, error!)
                    
                    abort()
                }
            }
        }
    }
    
    private func foodCorrelationForFoodItem(foodItem: AAPLFoodItem) -> HKCorrelation {
        let now = NSDate()
        
        let energyQuantityConsumed = HKQuantity(unit:HKUnit.jouleUnit(), doubleValue: foodItem.joules)
        
        let energyConsumedType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryEnergyConsumed)!
        
        let energyConsumedSample = HKQuantitySample(type: energyConsumedType, quantity: energyQuantityConsumed, startDate: now, endDate: now)
        let energyConsumedSamples: Set<HKSample> = [energyConsumedSample]
        
        let foodType = HKObjectType.correlationTypeForIdentifier(HKCorrelationTypeIdentifierFood)!
        
        let foodCorrelationMetadata: [String: AnyObject] = [HKMetadataKeyFoodType: foodItem.name]
        
        let foodCorrelation = HKCorrelation(type: foodType, startDate: now, endDate: now, objects: energyConsumedSamples, metadata: foodCorrelationMetadata)
        
        return foodCorrelation
    }
    
    //MARK: - UITableViewDelegate
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.foodItems.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCellWithIdentifier(AAPLJournalViewControllerTableViewCellReuseIdentifier, forIndexPath: indexPath)
    }
    
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        let foodItem = self.foodItems[indexPath.row]
        
        cell.textLabel!.text = foodItem.name
        
        cell.detailTextLabel!.text = energyFormatter.stringFromJoules(foodItem.joules)
    }
    
    //MARK: - Segue Interaction
    
    @IBAction func performUnwindSegue(segue: UIStoryboardSegue) {
        let foodPickerViewController = segue.sourceViewController as! AAPLFoodPickerViewController
        
        let selectedFoodItem = foodPickerViewController.selectedFoodItem!
        
        self.addFoodItem(selectedFoodItem)
    }
    
    //MARK: - Convenience
    
    private lazy var energyFormatter: NSEnergyFormatter = {
        let formatter = NSEnergyFormatter()
        formatter.unitStyle = .Long
        formatter.forFoodEnergyUse = true
        formatter.numberFormatter.maximumFractionDigits = 2
        
        return formatter
        }()
    
}