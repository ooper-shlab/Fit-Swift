//
//  AAPLProfileViewController.swift
//  Fit
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/7/25.
//
//
/*
    Copyright (C) 2014 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information

    Abstract:

                Displays age, height, and weight information retrieved from HealthKit.

*/

import UIKit
import HealthKit

enum MyError: ErrorType {case Err}

// A mapping of logical sections of the table view to actual indexes.
enum AAPLProfileViewControllerTableViewIndex: Int {
    case Age = 0
    case Height
    case Weight
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
    
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // Set up an HKHealthStore, asking the user for read/write permissions. The profile view controller is the
        // first view controller that's shown to the user, so we'll ask for all of the desired HealthKit permissions now.
        // In your own app, you should consider requesting permissions the first time a user wants to interact with
        // HealthKit data.
        if HKHealthStore.isHealthDataAvailable() {
            let writeDataTypes = self.dataTypesToWrite()
            let readDataTypes = self.dataTypesToRead()
            self.healthStore?.requestAuthorizationToShareTypes(writeDataTypes, readTypes: readDataTypes) {success, error in
                if !success {
                    NSLog("You didn't allow HealthKit to access these read/write data types. In your app, try to handle this error gracefully when a user decides not to provide access. The error was: %@. If you're using a simulator, try it on a device.", error!)
                    
                    return
                }
                
                dispatch_async(dispatch_get_main_queue()) {
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
        let dietaryCalorieEnergyType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryEnergyConsumed)!
        let activeEnergyBurnType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned)!
        let heightType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeight)!
        let weightType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)!
        
        return [dietaryCalorieEnergyType, activeEnergyBurnType, heightType, weightType]
    }
    
    // Returns the types of data that Fit wishes to read from HealthKit.
    private func dataTypesToRead() -> Set<HKObjectType> {
        let dietaryCalorieEnergyType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryEnergyConsumed)!
        let activeEnergyBurnType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned)!
        let heightType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeight)!
        let weightType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)!
        let birthdayType = HKObjectType.characteristicTypeForIdentifier(HKCharacteristicTypeIdentifierDateOfBirth)!
        let biologicalSexType = HKObjectType.characteristicTypeForIdentifier(HKCharacteristicTypeIdentifierBiologicalSex)!
        
        return [dietaryCalorieEnergyType, activeEnergyBurnType, heightType, weightType, birthdayType, biologicalSexType]
    }
    
    //MARK: - Reading HealthKit Data
    
    private func updateUsersAgeLabel() {
        // Set the user's age unit (years).
        self.ageUnitLabel.text = NSLocalizedString("Age (yrs)", comment: "")
        
        do {
            guard let dateOfBirth = try self.healthStore?.dateOfBirth() else {throw MyError.Err}
            // Compute the age of the user.
            let now = NSDate()
            
            let ageComponents = NSCalendar.currentCalendar().components(.Year, fromDate: dateOfBirth, toDate: now, options: .WrapComponents)
            
            let usersAge = ageComponents.year
            
            self.ageValueLabel.text = NSNumberFormatter.localizedStringFromNumber(usersAge, numberStyle: .NoStyle)
        } catch _ {
            NSLog("Either an error occured fetching the user's age information or none has been stored yet. In your app, try to handle this gracefully.")
            
            self.ageValueLabel.text = NSLocalizedString("Not available", comment: "")
        }
    }
    
    private func updateUsersHeightLabel() {
        // Fetch user's default height unit in inches.
        let lengthFormatter = NSLengthFormatter()
        lengthFormatter.unitStyle = NSFormattingUnitStyle.Long
        
        let heightFormatterUnit = NSLengthFormatterUnit.Inch
        let heightUnitString = lengthFormatter.unitStringFromValue(10, unit: heightFormatterUnit)
        let localizedHeightUnitDescriptionFormat = NSLocalizedString("Height (%@)", comment: "")
        
        self.heightUnitLabel.text = String(format: localizedHeightUnitDescriptionFormat, heightUnitString)
        
        let heightType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeight)!
        
        // Query to get the user's latest height, if it exists.
        self.healthStore?.aapl_mostRecentQuantitySampleOfType(heightType, predicate: nil) {mostRecentQuantity, error in
            if mostRecentQuantity == nil {
                NSLog("Either an error occured fetching the user's height information or none has been stored yet. In your app, try to handle this gracefully.")
                
                dispatch_async(dispatch_get_main_queue()) {
                    self.heightValueLabel.text = NSLocalizedString("Not available", comment: "")
                }
            } else {
                // Determine the height in the required unit.
                let heightUnit = HKUnit.inchUnit()
                let usersHeight = mostRecentQuantity!.doubleValueForUnit(heightUnit)
                
                // Update the user interface.
                dispatch_async(dispatch_get_main_queue()) {
                    self.heightValueLabel.text = NSNumberFormatter.localizedStringFromNumber(usersHeight, numberStyle: NSNumberFormatterStyle.NoStyle)
                }
            }
        }
    }
    
    private func updateUsersWeightLabel() {
        // Fetch the user's default weight unit in pounds.
        let massFormatter = NSMassFormatter()
        massFormatter.unitStyle = .Long
        
        let weightFormatterUnit = NSMassFormatterUnit.Pound
        let weightUnitString = massFormatter.unitStringFromValue(10, unit: weightFormatterUnit)
        let localizedWeightUnitDescriptionFormat = NSLocalizedString("Weight (%@)", comment: "")
        
        self.weightUnitLabel.text = String(format:localizedWeightUnitDescriptionFormat, weightUnitString)
        
        // Query to get the user's latest weight, if it exists.
        let weightType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)!
        
        self.healthStore?.aapl_mostRecentQuantitySampleOfType(weightType, predicate: nil) {mostRecentQuantity, error in
            if mostRecentQuantity == nil {
                NSLog("Either an error occured fetching the user's weight information or none has been stored yet. In your app, try to handle this gracefully.")
                
                dispatch_async(dispatch_get_main_queue()) {
                    self.weightValueLabel.text = NSLocalizedString("Not available", comment: "")
                }
            } else {
                // Determine the weight in the required unit.
                let weightUnit = HKUnit.poundUnit()
                let usersWeight = mostRecentQuantity!.doubleValueForUnit(weightUnit)
                
                // Update the user interface.
                dispatch_async(dispatch_get_main_queue()) {
                    self.weightValueLabel.text = NSNumberFormatter.localizedStringFromNumber(usersWeight, numberStyle: .NoStyle)
                }
            }
        }
    }
    
    //MARK: - Writing HealthKit Data
    
    private func saveHeightIntoHealthStore(height: Double) {
        // Save the user's height into HealthKit.
        let inchUnit = HKUnit.inchUnit()
        let heightQuantity = HKQuantity(unit: inchUnit, doubleValue: height)
        
        let heightType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeight)!
        let now = NSDate()
        
        let heightSample = HKQuantitySample(type: heightType, quantity: heightQuantity, startDate: now, endDate: now)
        
        self.healthStore?.saveObject(heightSample) {success, error in
            if !success {
                NSLog("An error occured saving the height sample %@. In your app, try to handle this gracefully. The error was: %@.", heightSample, error!)
                abort()
            }
            
            self.updateUsersHeightLabel()
        }
    }
    
    private func saveWeightIntoHealthStore(weight: Double) {
        // Save the user's weight into HealthKit.
        let poundUnit = HKUnit.poundUnit()
        let weightQuantity = HKQuantity(unit: poundUnit, doubleValue: weight)
        
        let weightType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)!
        let now = NSDate()
        
        let weightSample = HKQuantitySample(type: weightType, quantity: weightQuantity, startDate: now, endDate: now)
        
        self.healthStore?.saveObject(weightSample) {success, error in
            if !success {
                NSLog("An error occured saving the weight sample %@. In your app, try to handle this gracefully. The error was: %@.", weightSample, error!)
                abort()
            }
            
            self.updateUsersWeightLabel()
        }
    }
    
    //MARK: - UITableViewDelegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard let index = AAPLProfileViewControllerTableViewIndex(rawValue: indexPath.row)
            
            // We won't allow people to change their date of birth, so ignore selection of the age cell.
            where index != .Age else {return}
        
        // Set up variables based on what row the user has selected.
        var title: String!
        var valueChangedHandler: (Double->Void)!
        
        if index == .Height {
            title = NSLocalizedString("Your Height", comment: "")
            
            valueChangedHandler = self.saveHeightIntoHealthStore
        } else if index == .Weight {
            title = NSLocalizedString("Your Weight", comment: "")
            
            valueChangedHandler = self.saveWeightIntoHealthStore
        }
        
        // Create an alert controller to present.
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .Alert)
        
        // Add the text field to let the user enter a numeric value.
        alertController.addTextFieldWithConfigurationHandler {textField in
            // Only allow the user to enter a valid number.
            textField.keyboardType = .DecimalPad
        }
        
        // Create the "OK" button.
        let okTitle = NSLocalizedString("OK", comment: "")
        let okAction = UIAlertAction(title: okTitle, style: .Default) {action in
            let textField = alertController.textFields?.first
            
            let value = Double(textField?.text ?? "0")!
            
            valueChangedHandler(value)
            
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
        
        alertController.addAction(okAction)
        
        // Create the "Cancel" button.
        let cancelTitle = NSLocalizedString("Cancel", comment: "")
        let cancelAction = UIAlertAction(title: cancelTitle, style: .Cancel) {action in
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
        
        alertController.addAction(cancelAction)
        
        // Present the alert controller.
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    //MARK: - Convenience
    
    private lazy var numberFormatter: NSNumberFormatter = NSNumberFormatter()
    
}