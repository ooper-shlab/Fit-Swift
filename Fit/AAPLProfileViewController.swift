//
//  AAPLProfileViewController.swift
//  Fit
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/7/25.
//
//
/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information

    Abstract:
    Displays age, height, and weight information retrieved from HealthKit.
*/

import UIKit
import HealthKit

enum MyError: Error {case err}

// A mapping of logical sections of the table view to actual indexes.
enum AAPLProfileViewControllerTableViewIndex: Int {
    case age = 0
    case height
    case weight
}


@objc(AAPLProfileViewController)
class AAPLProfileViewController: UITableViewController, HavingHealthStore {
    
    var healthStore: HKHealthStore?
    
    // Note that the user's age is not editable.
    @IBOutlet private weak var ageUnitLabel: UILabel!
    @IBOutlet private weak var ageValueLabel: UILabel!
    
    @IBOutlet private weak var heightValueLabel: UILabel!
    @IBOutlet private weak var heightUnitLabel: UILabel!
    
    @IBOutlet private weak var weightValueLabel: UILabel!
    @IBOutlet private weak var weightUnitLabel: UILabel!
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Set up an HKHealthStore, asking the user for read/write permissions. The profile view controller is the
        // first view controller that's shown to the user, so we'll ask for all of the desired HealthKit permissions now.
        // In your own app, you should consider requesting permissions the first time a user wants to interact with
        // HealthKit data.
        if HKHealthStore.isHealthDataAvailable() {
            let writeDataTypes = self.dataTypesToWrite()
            let readDataTypes = self.dataTypesToRead()
            self.healthStore?.requestAuthorization(toShare: writeDataTypes, read: readDataTypes) {success, error in
                if !success {
                    NSLog("You didn't allow HealthKit to access these read/write data types. In your app, try to handle this error gracefully when a user decides not to provide access. The error was: \(error!). If you're using a simulator, try it on a device.")
                    
                    return
                }
                
                DispatchQueue.main.async {
                    // Update the user interface based on the current user's health information.
                    self.updateUsersAgeLabel()
                    self.updateUsersHeightLabel()
                    self.updateUsersWeightLabel()
                }
            }
        }
    }
    
    //MARK: - HealthKit Permissions
    
    // Returns the types of data that Fit wishes to write to HealthKit.
    private func dataTypesToWrite() -> Set<HKSampleType> {
        let dietaryCalorieEnergyType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.dietaryEnergyConsumed)!
        let activeEnergyBurnType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!
        let heightType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.height)!
        let weightType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyMass)!
        
        return [dietaryCalorieEnergyType, activeEnergyBurnType, heightType, weightType]
    }
    
    // Returns the types of data that Fit wishes to read from HealthKit.
    private func dataTypesToRead() -> Set<HKObjectType> {
        let dietaryCalorieEnergyType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.dietaryEnergyConsumed)!
        let activeEnergyBurnType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!
        let heightType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.height)!
        let weightType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyMass)!
        let birthdayType = HKObjectType.characteristicType(forIdentifier: HKCharacteristicTypeIdentifier.dateOfBirth)!
        let biologicalSexType = HKObjectType.characteristicType(forIdentifier: HKCharacteristicTypeIdentifier.biologicalSex)!
        
        return [dietaryCalorieEnergyType, activeEnergyBurnType, heightType, weightType, birthdayType, biologicalSexType]
    }
    
    //MARK: - Reading HealthKit Data
    
    private func updateUsersAgeLabel() {
        // Set the user's age unit (years).
        self.ageUnitLabel.text = NSLocalizedString("Age (yrs)", comment: "")
        
        do {
            guard let dateOfBirth = try self.healthStore?.dateOfBirth() else {throw MyError.err}
            // Compute the age of the user.
            let now = Date()
            
            let ageComponents = (Calendar.current as NSCalendar).components(.year, from: dateOfBirth, to: now, options: .wrapComponents)
            
            let usersAge = ageComponents.year!
            
            self.ageValueLabel.text = NumberFormatter.localizedString(from: usersAge as NSNumber, number: .none)
        } catch _ {
            NSLog("Either an error occured fetching the user's age information or none has been stored yet. In your app, try to handle this gracefully.")
            
            self.ageValueLabel.text = NSLocalizedString("Not available", comment: "")
        }
    }
    
    private func updateUsersHeightLabel() {
        // Fetch user's default height unit in inches.
        let lengthFormatter = LengthFormatter()
        lengthFormatter.unitStyle = Formatter.UnitStyle.long
        
        let heightFormatterUnit = LengthFormatter.Unit.inch
        let heightUnitString = lengthFormatter.unitString(fromValue: 10, unit: heightFormatterUnit)
        let localizedHeightUnitDescriptionFormat = NSLocalizedString("Height (%@)", comment: "")
        
        self.heightUnitLabel.text = String(format: localizedHeightUnitDescriptionFormat, heightUnitString)
        
        let heightType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.height)!
        
        // Query to get the user's latest height, if it exists.
        self.healthStore?.aapl_mostRecentQuantitySampleOfType(heightType, predicate: nil) {mostRecentQuantity, error in
            if mostRecentQuantity == nil {
                NSLog("Either an error occured fetching the user's height information or none has been stored yet. In your app, try to handle this gracefully.")
                
                DispatchQueue.main.async {
                    self.heightValueLabel.text = NSLocalizedString("Not available", comment: "")
                }
            } else {
                // Determine the height in the required unit.
                let heightUnit = HKUnit.inch()
                let usersHeight = mostRecentQuantity!.doubleValue(for: heightUnit)
                
                // Update the user interface.
                DispatchQueue.main.async {
                    self.heightValueLabel.text = NumberFormatter.localizedString(from: usersHeight as NSNumber, number: NumberFormatter.Style.none)
                }
            }
        }
    }
    
    private func updateUsersWeightLabel() {
        // Fetch the user's default weight unit in pounds.
        let massFormatter = MassFormatter()
        massFormatter.unitStyle = .long
        
        let weightFormatterUnit = MassFormatter.Unit.pound
        let weightUnitString = massFormatter.unitString(fromValue: 10, unit: weightFormatterUnit)
        let localizedWeightUnitDescriptionFormat = NSLocalizedString("Weight (%@)", comment: "")
        
        self.weightUnitLabel.text = String(format:localizedWeightUnitDescriptionFormat, weightUnitString)
        
        // Query to get the user's latest weight, if it exists.
        let weightType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyMass)!
        
        self.healthStore?.aapl_mostRecentQuantitySampleOfType(weightType, predicate: nil) {mostRecentQuantity, error in
            if mostRecentQuantity == nil {
                NSLog("Either an error occured fetching the user's weight information or none has been stored yet. In your app, try to handle this gracefully.")
                
                DispatchQueue.main.async {
                    self.weightValueLabel.text = NSLocalizedString("Not available", comment: "")
                }
            } else {
                // Determine the weight in the required unit.
                let weightUnit = HKUnit.pound()
                let usersWeight = mostRecentQuantity!.doubleValue(for: weightUnit)
                
                // Update the user interface.
                DispatchQueue.main.async {
                    self.weightValueLabel.text = NumberFormatter.localizedString(from: usersWeight as NSNumber, number: .none)
                }
            }
        }
    }
    
    //MARK: - Writing HealthKit Data
    
    private func saveHeightIntoHealthStore(_ height: Double) {
        // Save the user's height into HealthKit.
        let inchUnit = HKUnit.inch()
        let heightQuantity = HKQuantity(unit: inchUnit, doubleValue: height)
        
        let heightType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.height)!
        let now = Date()
        
        let heightSample = HKQuantitySample(type: heightType, quantity: heightQuantity, start: now, end: now)
        
        self.healthStore?.save(heightSample, withCompletion: {success, error in
            if !success {
                NSLog("An error occured saving the height sample \(heightSample). In your app, try to handle this gracefully. The error was: \(error!).")
                abort()
            }
            
            self.updateUsersHeightLabel()
        }) 
    }
    
    private func saveWeightIntoHealthStore(_ weight: Double) {
        // Save the user's weight into HealthKit.
        let poundUnit = HKUnit.pound()
        let weightQuantity = HKQuantity(unit: poundUnit, doubleValue: weight)
        
        let weightType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyMass)!
        let now = Date()
        
        let weightSample = HKQuantitySample(type: weightType, quantity: weightQuantity, start: now, end: now)
        
        self.healthStore?.save(weightSample, withCompletion: {success, error in
            if !success {
                NSLog("An error occured saving the weight sample \(weightSample). In your app, try to handle this gracefully. The error was: \(error!).")
                abort()
            }
            
            self.updateUsersWeightLabel()
        }) 
    }
    
    //MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let index = AAPLProfileViewControllerTableViewIndex(rawValue: indexPath.row), index != .age else {return}
        
        // Set up variables based on what row the user has selected.
        var title: String!
        var valueChangedHandler: ((Double)->Void)!
        
        if index == .height {
            title = NSLocalizedString("Your Height", comment: "")
            
            valueChangedHandler = self.saveHeightIntoHealthStore
        } else if index == .weight {
            title = NSLocalizedString("Your Weight", comment: "")
            
            valueChangedHandler = self.saveWeightIntoHealthStore
        }
        
        // Create an alert controller to present.
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        
        // Add the text field to let the user enter a numeric value.
        alertController.addTextField {textField in
            // Only allow the user to enter a valid number.
            textField.keyboardType = .decimalPad
        }
        
        // Create the "OK" button.
        let okTitle = NSLocalizedString("OK", comment: "")
        let okAction = UIAlertAction(title: okTitle, style: .default) {action in
            let textField = alertController.textFields?.first
            
            let value = Double(textField?.text ?? "0")!
            
            valueChangedHandler(value)
            
            tableView.deselectRow(at: indexPath, animated: true)
        }
        
        alertController.addAction(okAction)
        
        // Create the "Cancel" button.
        let cancelTitle = NSLocalizedString("Cancel", comment: "")
        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) {action in
            tableView.deselectRow(at: indexPath, animated: true)
        }
        
        alertController.addAction(cancelAction)
        
        // Present the alert controller.
        self.present(alertController, animated: true, completion: nil)
    }
    
    //MARK: - Convenience
    
    private lazy var numberFormatter: NumberFormatter = NumberFormatter()
    
}
