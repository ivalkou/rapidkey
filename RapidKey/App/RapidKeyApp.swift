//
//  RapidKeyApp.swift
//  RapidKey
//
//  Created by Valkou Ivan on 13.05.2026.
//

import SwiftUI

@main
struct RapidKeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("RapidKey", systemImage: "smallcircle.filled.circle") {
            MenuBarContent(appDelegate: appDelegate, configStore: appDelegate.configStore)
        }
        .menuBarExtraStyle(.menu)
    }
}
