//
//  AAPLEnergyViewController.swift
//  Fit
//
//  Translated by OOPer in cooperation with shlab.jp, on 2014/10/18.
//
//
/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.refreshControl?.addTarget(self, action: #selector(EnergyViewController.refreshStatistics), for: .valueChanged)
        
        self.refreshStatistics()
        
        NotificationCenter.default.addObserver(self, selector: #selector(EnergyViewController.refreshStatistics), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name:NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }
    
    //MARK: - Reading HealthKit Data
    
    @objc private func refreshStatistics() {
        self.refreshControl?.beginRefreshing()
        
        let energyConsumedType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.dietaryEnergyConsumed)
        let activeEnergyBurnType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)
        
        // First, fetch the sum of energy consumed samples from HealthKit. Populate this by creating your
        // own food logging app or using the food journal view controller.
        self.fetchSumOfSamplesTodayForType(energyConsumedType!, unit: HKUnit.joule()) {totalJoulesConsumed, error in
            
            // Next, fetch the sum of active energy burned from HealthKit. Populate this by creating your
            // own calorie tracking app or the Health app.
            self.fetchSumOfSamplesTodayForType(activeEnergyBurnType!, unit: HKUnit.joule()) {activeEnergyBurned, error in
                
                // Last, calculate the user's basal energy burn so far today.
                self.fetchTotalBasalBurn {basalEnergyBurn, error in
                    
                    if basalEnergyBurn == nil {
                        NSLog("An error occurred trying to compute the basal energy burn. In your app, handle this gracefully. Error: \(error)")
                    }
                    
                    // Update the UI with all of the fetched values.
                    DispatchQueue.main.async {
                        self.activeEnergyBurned = activeEnergyBurned
                        
                        self.restingEnergyBurned = basalEnergyBurn?.doubleValue(for: HKUnit.joule()) ?? 0.0
                        
                        self.energyConsumed = totalJoulesConsumed
                        
                        self.netEnergy = self.energyConsumed - self.activeEnergyBurned - self.restingEnergyBurned
                        
                        self.refreshControl?.endRefreshing()
                    }
                }
            }
        }
    }
    
    private func fetchSumOfSamplesTodayForType(_ quantityType: HKQuantityType, unit: HKUnit, completion completionHandler: ((Double, Error?)->Void)?) {
        let predicate = predicateForSamplesToday()
        
        let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) {query, result, error in
            let sum = result?.sumQuantity()
            
            if completionHandler != nil {
                let value: Double = sum?.doubleValue(for: unit) ?? 0.0
                
                completionHandler!(value, error)
            }
        }
        
        self.healthStore?.execute(query)
    }
    
    // Calculates the user's total basal (resting) energy burn based off of their height, weight, age,
    // and biological sex. If there is not enough information, return an error.
    private func fetchTotalBasalBurn(_ completion: @escaping (HKQuantity?, Error?)->Void) {
        let todayPredicate = predicateForSamplesToday()
        
        let weightType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyMass)
        let heightType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.height)
        
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
                
                let dateOfBirth: Date?
                do {
                    dateOfBirth = try self.healthStore?.dateOfBirth()
                } catch let error {
                    completion(nil, error)
                    
                    return
                }
                
                let biologicalSexObject: HKBiologicalSexObject?
                do {
                    biologicalSexObject = try self.healthStore?.biologicalSex()
                } catch let error {
                    completion(nil, error)
                    
                    return
                }
                
                // Once we have pulled all of the information without errors, calculate the user's total basal energy burn
                let basalEnergyBurn = self.calculateBasalBurnTodayFromWeight(weight!, height: height!, dateOfBirth: dateOfBirth!, biologicalSex: biologicalSexObject!)
                
                completion(basalEnergyBurn, nil)
            }
        }
    }
    
    private func calculateBasalBurnTodayFromWeight(_ weight: HKQuantity, height: HKQuantity, dateOfBirth: Date, biologicalSex: HKBiologicalSexObject) -> HKQuantity {
        // Only calculate Basal Metabolic Rate (BMR) if we have enough information about the user
        
        // Note the difference between calling +unitFromString: vs creating a unit from a string with
        // a given prefix. Both of these are equally valid, however one may be more convenient for a given
        // use case.
        let heightInCentimeters = height.doubleValue(for: HKUnit(from: "cm"))
        let weightInKilograms = weight.doubleValue(for: HKUnit.gramUnit(with: .kilo))
        //
        let now = Date()
        //### I couldn't have found an equivalent of `options: .wrapComponents` in Calendar methods.
        let ageComponents = (Calendar.current as NSCalendar).components(.year, from: dateOfBirth, to: now, options: .wrapComponents)
        let ageInYears = ageComponents.year
        
        // BMR is calculated in kilocalories per day.
        let BMR = self.calculateBMRFromWeight(weightInKilograms, height: heightInCentimeters, age: ageInYears!, biologicalSex: biologicalSex.biologicalSex)
        
        // Figure out how much of today has completed so we know how many kilocalories the user has burned.
        let startOfToday = Calendar.current.startOfDay(for: now)
        let endOfToday = (Calendar.current as NSCalendar).date(byAdding: .day, value: 1, to: startOfToday, options: [])
        
        let secondsInDay = endOfToday!.timeIntervalSince(startOfToday)
        let percentOfDayComplete = now.timeIntervalSince(startOfToday) / secondsInDay
        
        let kilocaloriesBurned = BMR * percentOfDayComplete
        
        return HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: kilocaloriesBurned)
    }
    
    //MARK: - Convenience
    
    private func predicateForSamplesToday() -> NSPredicate {
        let calendar = Calendar.current
        
        let now = Date()
        
        let startDate = calendar.startOfDay(for: now)
        let endDate = (calendar as NSCalendar).date(byAdding: .day, value: 1, to: startDate, options: [])
        
        return HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    }
    
    /// Returns BMR value in kilocalories per day. Note that there are different ways of calculating the
    /// BMR. In this example we chose an arbitrary function to calculate BMR based on weight, height, age,
    /// and biological sex.
    private func calculateBMRFromWeight(_ weightInKilograms: Double, height heightInCentimeters: Double, age ageInYears: Int, biologicalSex: HKBiologicalSex) -> Double {
        var BMR: Double = 0.0
        
        // The BMR equation is different between males and females.
        if biologicalSex == .male {
            BMR = 66.0 + (13.8 * weightInKilograms) + (5.0 * heightInCentimeters) - (6.8 * Double(ageInYears))
        } else {
            BMR = 655 + (9.6 * weightInKilograms) + (1.8 * heightInCentimeters) - (4.7 * Double(ageInYears))
        }
        
        return BMR
    }
    
    //MARK: - NSEnergyFormatter
    
    private lazy var energyFormatter: EnergyFormatter = {
        let formatter = EnergyFormatter()
        formatter.unitStyle = .long
        formatter.isForFoodEnergyUse = true
        formatter.numberFormatter.maximumFractionDigits = 2
        return formatter
        }()
    
    //MARK: - Setter Overrides
    
    private func didSetActiveEnergyBurned(_ oldValue: Double) {
        
        self.activeEnergyBurnedValueLabel?.text = energyFormatter.string(fromJoules: activeEnergyBurned)
    }
    
    private func didSetEnergyConsumed(_ oldValue: Double) {
        
        self.consumedEnergyValueLabel?.text = energyFormatter.string(fromJoules: energyConsumed)
    }
    
    private func didSetRestingEnergyBurned(_ oldValue: Double) {
        
        self.restingEnergyBurnedValueLabel?.text = energyFormatter.string(fromJoules: restingEnergyBurned)
    }
    
    private func didSetNetEnergy(_ oldValue: Double) {
        
        self.netEnergyValueLabel?.text = energyFormatter.string(fromJoules: netEnergy)
    }
    
}
