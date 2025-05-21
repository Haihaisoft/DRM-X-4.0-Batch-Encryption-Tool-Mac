//
//  LocalizationHelper.swift
//  DRM-X4-Batch-Encryption-Tool
//
//  Created by Jason on 2025/4/29.
//
import Foundation
func localized(_ key: String, isChinese: Bool) -> String {
    let table = "Localizable"
    let language = isChinese ? "zh-Hans" : "en"
    
    guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        return NSLocalizedString(key, comment: "")
    }
    
    return NSLocalizedString(key, tableName: table, bundle: bundle, comment: "")
}
