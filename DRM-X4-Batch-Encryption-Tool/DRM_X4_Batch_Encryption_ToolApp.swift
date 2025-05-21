//
//  DRM_X4_Batch_Encryption_ToolApp.swift
//  DRM-X4-Batch-Encryption-Tool
//
//  Created by Jason on 2025/4/28.
//

import SwiftUI

@main
struct DRM_X4_Batch_Encryption_ToolApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .help) {
                Button("DRM-X 4.0 Batch Encryption Tool Help") {
                    if let url = URL(string: "https://www.drm-x.com/DRM-X-4.0-Automatic-Batch-Encryption-Tool.aspx") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
