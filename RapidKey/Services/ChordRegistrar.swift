import Carbon

private let hotKeySignature = OSType(0x4C445250)

final class ChordRegistrar {
    private var eventHandler: EventHandlerRef?
    private var hotKeyRefsByID: [UInt32: EventHotKeyRef] = [:]
    private var handlersByHotKeyID: [UInt32: () -> Void] = [:]

    func start() {
        guard eventHandler == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let userData else { return noErr }
                let registrar = Unmanaged<ChordRegistrar>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                registrar.handlersByHotKeyID[hotKeyID.id]?()
                return noErr
            },
            1,
            &eventSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandler
        )
    }

    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        start()
        unregister(id: id)

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: id)
        handlersByHotKeyID[id] = handler

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            hotKeyRefsByID[id] = ref
        } else {
            handlersByHotKeyID[id] = nil
        }
    }

    func unregister(id: UInt32) {
        if let ref = hotKeyRefsByID.removeValue(forKey: id) {
            UnregisterEventHotKey(ref)
        }
        handlersByHotKeyID[id] = nil
    }

    func unregisterAll() {
        for ref in hotKeyRefsByID.values {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefsByID.removeAll()
        handlersByHotKeyID.removeAll()
    }

    deinit {
        unregisterAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
