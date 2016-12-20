//
//  AAPLJournalViewController.swift
//  Fit
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/7/24.
//
//
/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(AAPLJournalViewController.updateJournal), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }
    
    //MARK: - Reading HealthKit Data
    
    @objc private func updateJournal() {
        let calendar = Calendar.current
        
        let now = Date()
        
        let components = (calendar as NSCalendar).components([.year, .month, .day], from: now)
        
        let startDate = calendar.date(from: components)
        
        let endDate = (calendar as NSCalendar).date(byAdding: .day, value: 1, to: startDate!, options: [])
        
        let foodType = HKObjectType.correlationType(forIdentifier: HKCorrelationTypeIdentifier.food)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions())
        
        let query = HKSampleQuery(sampleType: foodType, predicate: predicate, limit: Int(HKObjectQueryNoLimit), sortDescriptors: nil) {query, results, error in
            guard let results = results else {
                NSLog("An error occured fetching the user's tracked food. In your app, try to handle this gracefully. The error was: \(error!).")
                abort()
            }
            
            DispatchQueue.main.async {
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
        
        self.healthStore?.execute(query)
    }
    
    private func foodItemFromFoodCorrelation(_ foodCorrelation: HKCorrelation) -> AAPLFoodItem {
        // Fetch the name fo the food.
        let foodName = foodCorrelation.metadata![HKMetadataKeyFoodType] as! String
        
        // Fetch the total energy from the food.
        let energyConsumedType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.dietaryEnergyConsumed)!
        let energyConsumedSamples = foodCorrelation.objects(for: energyConsumedType)
        
        // Note that we only have one energy consumed sample correlation (for Fit specifically).
        let energyConsumedSample = energyConsumedSamples.first! as! HKQuantitySample
        
        let energyQuantityConsumed = energyConsumedSample.quantity
        
        let joules = energyQuantityConsumed.doubleValue(for: HKUnit.joule())
        
        return AAPLFoodItem(name: foodName, joules: joules)
    }
    
    //MARK: - Writing HealthKit Data
    
    private func addFoodItem(_ foodItem: AAPLFoodItem) {
        // Create a new food correlation for the given food item.
        let foodCorrelationForFoodItem = self.foodCorrelationForFoodItem(foodItem)
        
        self.healthStore?.save(foodCorrelationForFoodItem, withCompletion: {success, error in
            DispatchQueue.main.async {
                if success {
                    self.foodItems.insert(foodItem, at: 0)
                    
                    let indexPathForInsertedFoodItem = IndexPath(row: 0, section: 0)
                    
                    self.tableView.insertRows(at: [indexPathForInsertedFoodItem], with: UITableViewRowAnimation.automatic)
                } else {
                    NSLog("An error occured saving the food \(foodItem.name). In your app, try to handle this gracefully. The error was: \(error!).")
                    
                    abort()
                }
            }
        }) 
    }
    
    private func foodCorrelationForFoodItem(_ foodItem: AAPLFoodItem) -> HKCorrelation {
        let now = Date()
        
        let energyQuantityConsumed = HKQuantity(unit:HKUnit.joule(), doubleValue: foodItem.joules)
        
        let energyConsumedType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.dietaryEnergyConsumed)!
        
        let energyConsumedSample = HKQuantitySample(type: energyConsumedType, quantity: energyQuantityConsumed, start: now, end: now)
        let energyConsumedSamples: Set<HKSample> = [energyConsumedSample]
        
        let foodType = HKObjectType.correlationType(forIdentifier: HKCorrelationTypeIdentifier.food)!
        
        let foodCorrelationMetadata: [String: AnyObject] = [HKMetadataKeyFoodType: foodItem.name as AnyObject]
        
        let foodCorrelation = HKCorrelation(type: foodType, start: now, end: now, objects: energyConsumedSamples, metadata: foodCorrelationMetadata)
        
        return foodCorrelation
    }
    
    //MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.foodItems.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: AAPLJournalViewControllerTableViewCellReuseIdentifier, for: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let foodItem = self.foodItems[indexPath.row]
        
        cell.textLabel!.text = foodItem.name
        
        cell.detailTextLabel!.text = energyFormatter.string(fromJoules: foodItem.joules)
    }
    
    //MARK: - Segue Interaction
    
    @IBAction func performUnwindSegue(_ segue: UIStoryboardSegue) {
        let foodPickerViewController = segue.source as! AAPLFoodPickerViewController
        
        let selectedFoodItem = foodPickerViewController.selectedFoodItem!
        
        self.addFoodItem(selectedFoodItem)
    }
    
    //MARK: - Convenience
    
    private lazy var energyFormatter: EnergyFormatter = {
        let formatter = EnergyFormatter()
        formatter.unitStyle = .long
        formatter.isForFoodEnergyUse = true
        formatter.numberFormatter.maximumFractionDigits = 2
        
        return formatter
        }()
    
}
