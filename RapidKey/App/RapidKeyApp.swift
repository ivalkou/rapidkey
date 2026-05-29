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
        MenuBarExtra {
            MenuBarContent(
                appDelegate: appDelegate,
                configStore: appDelegate.configStore,
                updateChecker: appDelegate.updateChecker
            )
        } label: {
            MenuBarLabel(updateChecker: appDelegate.updateChecker)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var updateChecker: UpdateChecker

    var body: some View {
        if case .updateAvailable = updateChecker.status {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "smallcircle.filled.circle")
                Circle()
                    .frame(width: 5, height: 5)
                    .offset(x: 2, y: -2)
            }
        } else {
            Image(systemName: "smallcircle.filled.circle")
        }
    }
}
