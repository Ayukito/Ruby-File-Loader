//
//  main.swift
//  Ruby File Loader
//
//  Created by Lynn Isip on 8/9/20.
//  Copyright © 2020 Lynn Isip. All rights reserved.
//

import Foundation

func shell(_ args: String...) -> Int32 {
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = args
    task.launch()
    task.waitUntilExit()
    return task.terminationStatus
}

let myScript = Bundle.main.path(forResource: "run", ofType: "command")
shell(myScript.unsafelyUnwrapped)
