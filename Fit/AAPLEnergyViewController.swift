//
//  AAPLEnergyViewController.swift
//  Fit
//
//  Translated by OOPer in cooperation with shlab.jp, on 2014/10/18.
//
//
/*
    Copyright (C) 2014 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information

    Abstract:

                Displays energy-related information retrieved from HealthKit.

*/

import UIKit
import HealthKit

@objc(AAPLEnergyViewController)
class EnergyViewController : UITableViewController, HavingHealthStore {
    
    var healthStore: HKHealthStore?
    
    @IBOutlet private weak var activeEnergyBurnedValueLabel: UILabel?
    @IBOutlet private weak var restingEnergyBurnedValueLabel: UILabel?
    @IBOutlet private weak var consumedEnergyValueLabel: UILabel?
    @IBOutlet private weak var netEnergyValueLabel: UILabel?
    
    private var activeEnergyBurned: Double = 0.0 {
        didSet {
            didSetActiveEnergyBurned(oldValue)
        }
    }
    private var restingEnergyBurned: Double = 0.0 {
        didSet {
            didSetRestingEnergyBurned(oldValue)
        }
    }
    private var energyConsumed: Double = 0.0 {
        didSet {
            didSetEnergyConsumed(oldValue)
        }
    }
    private var netEnergy: Double = 0.0 {
        didSet {
            didSetNetEnergy(oldValue)
        }
    }
    
    //MARK: - View Life Cycle
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.refreshControl?.addTarget(self, action: #selector(EnergyViewController.refreshStatistics), forControlEvents: .ValueChanged)
        
        self.refreshStatistics()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(EnergyViewController.refreshStatistics), name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name:UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    //MARK: - Reading HealthKit Data
    
    @objc private func refreshStatistics() {
        self.refreshControl?.beginRefreshing()
        
        let energyConsumedType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryEnergyConsumed)
        let activeEnergyBurnType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned)
        
        // First, fetch the sum of energy consumed samples from HealthKit. Populate this by creating your
        // own food logging app or using the food journal view controller.
        self.fetchSumOfSamplesTodayForType(energyConsumedType!, unit: HKUnit.jouleUnit()) {totalJoulesConsumed, error in
            
            // Next, fetch the sum of active energy burned from HealthKit. Populate this by creating your
            // own calorie tracking app or the Health app.
            self.fetchSumOfSamplesTodayForType(activeEnergyBurnType!, unit: HKUnit.jouleUnit()) {activeEnergyBurned, error in
                
                // Last, calculate the user's basal energy burn so far today.
                self.fetchTotalBasalBurn {basalEnergyBurn, error in
                    
                    if basalEnergyBurn == nil {
                        NSLog("An error occurred trying to compute the basal energy burn. In your app, handle this gracefully. Error: \(error)")
                    }
                    
                    // Update the UI with all of the fetched values.
                    dispatch_async(dispatch_get_main_queue()) {
                        self.activeEnergyBurned = activeEnergyBurned
                        
                        self.restingEnergyBurned = basalEnergyBurn?.doubleValueForUnit(HKUnit.jouleUnit()) ?? 0.0
                        
                        self.energyConsumed = totalJoulesConsumed
                        
                        self.netEnergy = self.energyConsumed - self.activeEnergyBurned - self.restingEnergyBurned
                        
                        self.refreshControl?.endRefreshing()
                    }
                }
            }
        }
    }
    
    private func fetchSumOfSamplesTodayForType(quantityType: HKQuantityType, unit: HKUnit, completion completionHandler: ((Double, NSError?)->Void)?) {
        let predicate = predicateForSamplesToday()
        
        let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .CumulativeSum) {query, result, error in
            let sum = result?.sumQuantity()
            
            if completionHandler != nil {
                let value: Double = sum?.doubleValueForUnit(unit) ?? 0.0
                
                completionHandler!(value, error)
            }
        }
        
        self.healthStore?.executeQuery(query)
    }
    
    // Calculates the user's total basal (resting) energy burn based off of their height, weight, age,
    // and biological sex. If there is not enough information, return an error.
    private func fetchTotalBasalBurn(completion: (HKQuantity?, NSError?)->Void) {
        let todayPredicate = predicateForSamplesToday()
        
        let weightType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)
        let heightType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeight)
        
        self.healthStore?.aapl_mostRecentQuantitySampleOfType(weightType!, predicate: nil) {weight, error in
            if weight == nil {
                completion(nil, error)
                
                return
            }
            
            self.healthStore?.aapl_mostRecentQuantitySampleOfType(heightType!, predicate: todayPredicate) {height, error in //NOTE: this error may have NSError from aapl_mostRecentQuantitySampleOfType
                if height == nil {
                    completion(nil, error)
                    
                    return
                }
                
                let dateOfBirth: NSDate?
                do {
                    dateOfBirth = try self.healthStore?.dateOfBirth()
                } catch let error as NSError {
                    completion(nil, error)
                    
                    return
                } catch {
                    fatalError()
                }
                
                let biologicalSexObject: HKBiologicalSexObject?
                do {
                    biologicalSexObject = try self.healthStore?.biologicalSex()
                } catch let error as NSError {
                    completion(nil, error)
                    
                    return
                } catch {
                    fatalError()
                }
                
                // Once we have pulled all of the information without errors, calculate the user's total basal energy burn
                let basalEnergyBurn = self.calculateBasalBurnTodayFromWeight(weight!, height: height!, dateOfBirth: dateOfBirth!, biologicalSex: biologicalSexObject!)
                
                completion(basalEnergyBurn, nil)
            }
        }
    }
    
    private func calculateBasalBurnTodayFromWeight(weight: HKQuantity, height: HKQuantity, dateOfBirth: NSDate, biologicalSex: HKBiologicalSexObject) -> HKQuantity {
        // Only calculate Basal Metabolic Rate (BMR) if we have enough information about the user
        
        // Note the difference between calling +unitFromString: vs creating a unit from a string with
        // a given prefix. Both of these are equally valid, however one may be more convenient for a given
        // use case.
        let heightInCentimeters = height.doubleValueForUnit(HKUnit(fromString: "cm"))
        let weightInKilograms = weight.doubleValueForUnit(HKUnit.gramUnitWithMetricPrefix(.Kilo))
        //
        let now = NSDate()
        let ageComponents = NSCalendar.currentCalendar().components(.Year, fromDate: dateOfBirth, toDate: now, options: .WrapComponents)
        let ageInYears = ageComponents.year
        
        // BMR is calculated in kilocalories per day.
        let BMR = self.calculateBMRFromWeight(weightInKilograms, height: heightInCentimeters, age: ageInYears, biologicalSex: biologicalSex.biologicalSex)
        
        // Figure out how much of today has completed so we know how many kilocalories the user has burned.
        let startOfToday = NSCalendar.currentCalendar().startOfDayForDate(now)
        let endOfToday = NSCalendar.currentCalendar().dateByAddingUnit(.Day, value: 1, toDate: startOfToday, options: [])
        
        let secondsInDay = endOfToday!.timeIntervalSinceDate(startOfToday)
        let percentOfDayComplete = now.timeIntervalSinceDate(startOfToday) / secondsInDay
        
        let kilocaloriesBurned = BMR * percentOfDayComplete
        
        return HKQuantity(unit: HKUnit.kilocalorieUnit(), doubleValue: kilocaloriesBurned)
    }
    
    //MARK: - Convenience
    
    private func predicateForSamplesToday() -> NSPredicate {
        let calendar = NSCalendar.currentCalendar()
        
        let now = NSDate()
        
        let startDate = calendar.startOfDayForDate(now)
        let endDate = calendar.dateByAddingUnit(.Day, value: 1, toDate: startDate, options: [])
        
        return HKQuery.predicateForSamplesWithStartDate(startDate, endDate: endDate, options: .StrictStartDate)
    }
    
    /// Returns BMR value in kilocalories per day. Note that there are different ways of calculating the
    /// BMR. In this example we chose an arbitrary function to calculate BMR based on weight, height, age,
    /// and biological sex.
    private func calculateBMRFromWeight(weightInKilograms: Double, height heightInCentimeters: Double, age ageInYears: Int, biologicalSex: HKBiologicalSex) -> Double {
        var BMR: Double = 0.0
        
        // The BMR equation is different between males and females.
        if biologicalSex == .Male {
            BMR = 66.0 + (13.8 * weightInKilograms) + (5.0 * heightInCentimeters) - (6.8 * Double(ageInYears))
        } else {
            BMR = 655 + (9.6 * weightInKilograms) + (1.8 * heightInCentimeters) - (4.7 * Double(ageInYears))
        }
        
        return BMR
    }
    
    //MARK: - NSEnergyFormatter
    
    private lazy var energyFormatter: NSEnergyFormatter = {
        let formatter = NSEnergyFormatter()
        formatter.unitStyle = .Long
        formatter.forFoodEnergyUse = true
        formatter.numberFormatter.maximumFractionDigits = 2
        return formatter
        }()
    
    //MARK: - Setter Overrides
    
    private func didSetActiveEnergyBurned(oldValue: Double) {
        
        self.activeEnergyBurnedValueLabel?.text = energyFormatter.stringFromJoules(activeEnergyBurned)
    }
    
    private func didSetEnergyConsumed(oldValue: Double) {
        
        self.consumedEnergyValueLabel?.text = energyFormatter.stringFromJoules(energyConsumed)
    }
    
    private func didSetRestingEnergyBurned(oldValue: Double) {
        
        self.restingEnergyBurnedValueLabel?.text = energyFormatter.stringFromJoules(restingEnergyBurned)
    }
    
    private func didSetNetEnergy(oldValue: Double) {
        
        self.netEnergyValueLabel?.text = energyFormatter.stringFromJoules(netEnergy)
    }
    
}