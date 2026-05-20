import AppKit
import SwiftUI

struct KeyCatcher: NSViewRepresentable {
    let onKey: (String) -> Void

    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.onKey = onKey

        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ nsView: KeyView, context: Context) {}
}

final class KeyView: NSView {
    var onKey: ((String) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard var token = PhysicalUSKeyMap.bindingToken(keyCode: event.keyCode) else {
            // Unmapped keys: swallow so IME/layout does not insert text into the panel.
            return
        }
        if event.modifierFlags.contains(.shift) {
            if token.count == 1, let ch = token.first, ch.isLetter {
                token = token.uppercased()
            } else if let shifted = PhysicalUSKeyMap.shiftedToken(for: token) {
                token = shifted
            }
        }
        onKey?(token)
    }
}
