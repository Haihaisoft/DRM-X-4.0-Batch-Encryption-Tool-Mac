//
//  ContentView.swift
//  DRM-X4-Batch-Encryption-Tool
//
//  Created by Jason on 2025/4/28.
//

import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var currentUser: User? = nil
    
    var body: some View {
        if isLoggedIn {
            MainView(isLoggedIn: $isLoggedIn, currentUser: $currentUser)
        } else {
            LoginView(isLoggedIn: $isLoggedIn, currentUser: $currentUser)
        }
    }
}
