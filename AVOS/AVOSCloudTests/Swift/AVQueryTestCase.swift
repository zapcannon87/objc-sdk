//
//  AVQueryTestCase.swift
//  AVOSCloud-iOSTests
//
//  Created by zapcannon87 on 2018/10/16.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

import XCTest

class AVQueryTestCase: LCTestBase {
    
    // MARK: - Server Testing
    
    func tests_query_match_string() {
        
        for item in ["a+b", "\\E"] {
            
            let key: String = "firstName"
            let value: String = item
            let object: AVObject = AVObject()
            object[key] = value
            
            RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                semaphore.increment()
                object.saveInBackground({ (succeeded: Bool, error: Error?) in
                    XCTAssertTrue(Thread.isMainThread)
                    semaphore.decrement()
                    XCTAssertTrue(succeeded)
                    XCTAssertNil(error)
                    XCTAssertNotNil(object.objectId)
                })
            }, failure: { XCTFail("timeout") })
            
            if object.objectId != nil {
                
                for i in 0..<3 {
                    
                    let query: AVQuery = AVQuery(className: "AVObject")
                    query.order(byDescending: "updatedAt")
                    query.limit = 1
                    if i == 0 {
                        query.whereKey(key, contains: value)
                    } else if i == 1 {
                        query.whereKey(key, hasPrefix: value)
                    } else if i == 2 {
                        query.whereKey(key, hasSuffix: value)
                    } else { XCTFail() }
                    
                    RunLoopSemaphore.wait(async: { (semaphore: RunLoopSemaphore) in
                        semaphore.increment()
                        query.findObjectsInBackground({ (objects: [Any]?, error: Error?) in
                            XCTAssertTrue(Thread.isMainThread)
                            semaphore.decrement()
                            XCTAssertNotNil(objects?.first)
                            XCTAssertEqual((objects?.first as? AVObject)?.objectId, object.objectId)
                            XCTAssertNil(error)
                        })
                    }, failure: { XCTFail("timeout") })
                }
            }
        }
    }
    
}
