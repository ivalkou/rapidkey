//
//  RapidKeyApp.swift
//  RapidKey
//
//  Created by Valkou Ivan on 13.05.2026.
//

import AppKit
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

    private var updateAvailable: Bool {
        if case .updateAvailable = updateChecker.status { return true }
        return false
    }

    var body: some View {
        Image(nsImage: MenuBarIcon.image(updateAvailable: updateAvailable))
    }
}

private enum MenuBarIcon {
    static func image(updateAvailable: Bool) -> NSImage {
        let symbolName = "smallcircle.filled.circle"
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: "RapidKey")?
            .withSymbolConfiguration(config) else {
            return NSImage()
        }

        guard updateAvailable else {
            symbol.isTemplate = true
            return symbol
        }

        let size = symbol.size
        let badgeDiameter = max(4, size.height * 0.38)
        let composed = NSImage(size: size)
        composed.lockFocus()

        let bounds = NSRect(origin: .zero, size: size)
        symbol.draw(in: bounds)
        NSColor.labelColor.set()
        bounds.fill(using: .sourceAtop)

        let badgeRect = NSRect(
            x: size.width - badgeDiameter,
            y: size.height - badgeDiameter,
            width: badgeDiameter,
            height: badgeDiameter
        )
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: badgeRect).fill()

        composed.unlockFocus()
        composed.isTemplate = false
        return composed
    }
}
