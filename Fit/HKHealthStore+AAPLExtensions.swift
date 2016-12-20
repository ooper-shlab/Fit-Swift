//
//  HKHealthStore+AAPLExtensions.swift
//  Fit
//
//  Translated by OOPer in cooperation with shlab.jp, on 2014/10/18.
//
//
/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information

    Abstract:
    Contains shared helper methods on HKHealthStore that are specific to Fit's use cases.
*/

import HealthKit

extension HKHealthStore {
    
    // Fetches the single most recent quantity of the specified type.
    func aapl_mostRecentQuantitySampleOfType(_ quantityType: HKQuantityType, predicate: NSPredicate?, completion: ((HKQuantity?, Error?)->Void)?) {
        let timeSortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        // Since we are interested in retrieving the user's latest sample, we sort the samples in descending order, and set the limit to 1. We are not filtering the data, and so the predicate is set to nil.
        let query = HKSampleQuery(sampleType: quantityType, predicate: nil, limit: 1, sortDescriptors: [timeSortDescriptor]) {query, results, error in
            if results == nil {
                completion?(nil, error)
                
                return
            }
            
            if completion != nil {
                // If quantity isn't in the database, return nil in the completion block.
                let quantitySample = results!.first as? HKQuantitySample
                let quantity = quantitySample?.quantity
                
                completion!(quantity, error)
            }
        }
        
        self.execute(query)
    }
    
}
