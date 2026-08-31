@preconcurrency import CoreAudio
import AudioToolbox
import Foundation

final class AudioHardwareService: @unchecked Sendable {
    typealias ChangeHandler = @Sendable () -> Void

    private let systemObject = AudioObjectID(kAudioObjectSystemObject)
    private let listenerQueue = DispatchQueue(label: "studio.rightfast.foh.core-audio-listener")
    private var listenerBlock: AudioObjectPropertyListenerBlock?

    var onChange: ChangeHandler?

    func devices() throws -> [AudioDevice] {
        let ids: [AudioObjectID] = try arrayProperty(
            objectID: systemObject,
            selector: kAudioHardwarePropertyDevices,
            scope: kAudioObjectPropertyScopeGlobal
        )

        return ids.flatMap { id in
            AudioDirection.allCases.compactMap { direction in
                makeDevice(objectID: id, direction: direction)
            }
        }
        .sorted { lhs, rhs in
            if lhs.direction != rhs.direction { return lhs.direction.rawValue < rhs.direction.rawValue }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    func defaultDeviceID(for direction: AudioDirection) throws -> AudioObjectID {
        let selector = direction == .input
            ? kAudioHardwarePropertyDefaultInputDevice
            : kAudioHardwarePropertyDefaultOutputDevice
        return try scalarProperty(
            objectID: systemObject,
            selector: selector,
            scope: kAudioObjectPropertyScopeGlobal
        )
    }

    func setDefaultDevice(_ device: AudioDevice) throws {
        let selector = device.direction == .input
            ? kAudioHardwarePropertyDefaultInputDevice
            : kAudioHardwarePropertyDefaultOutputDevice
        try setScalarProperty(
            device.objectID,
            objectID: systemObject,
            selector: selector,
            scope: kAudioObjectPropertyScopeGlobal
        )

        if device.direction == .output {
            try? setScalarProperty(
                device.objectID,
                objectID: systemObject,
                selector: kAudioHardwarePropertyDefaultSystemOutputDevice,
                scope: kAudioObjectPropertyScopeGlobal
            )
        }
    }

    func startObserving() {
        guard listenerBlock == nil else { return }
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.onChange?()
        }
        listenerBlock = block

        for selector in observedSelectors {
            var address = address(selector: selector, scope: kAudioObjectPropertyScopeGlobal)
            AudioObjectAddPropertyListenerBlock(systemObject, &address, listenerQueue, block)
        }
    }

    func stopObserving() {
        guard let listenerBlock else { return }
        for selector in observedSelectors {
            var address = address(selector: selector, scope: kAudioObjectPropertyScopeGlobal)
            AudioObjectRemovePropertyListenerBlock(systemObject, &address, listenerQueue, listenerBlock)
        }
        self.listenerBlock = nil
    }

    deinit {
        stopObserving()
    }

    private var observedSelectors: [AudioObjectPropertySelector] {
        [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultInputDevice,
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioHardwarePropertyDefaultSystemOutputDevice,
        ]
    }

    private func makeDevice(objectID: AudioObjectID, direction: AudioDirection) -> AudioDevice? {
        let scope = scope(for: direction)
        guard hasStreams(objectID: objectID, scope: scope),
              let uid = try? stringProperty(
                objectID: objectID,
                selector: kAudioDevicePropertyDeviceUID,
                scope: kAudioObjectPropertyScopeGlobal
              ),
              let name = try? stringProperty(
                objectID: objectID,
                selector: kAudioObjectPropertyName,
                scope: kAudioObjectPropertyScopeGlobal
              ) else { return nil }

        let transportValue: UInt32 = (try? scalarProperty(
            objectID: objectID,
            selector: kAudioDevicePropertyTransportType,
            scope: kAudioObjectPropertyScopeGlobal
        )) ?? 0

        let manufacturer = try? stringProperty(
            objectID: objectID,
            selector: kAudioObjectPropertyManufacturer,
            scope: kAudioObjectPropertyScopeGlobal
        )
        let sampleRate: Float64? = try? scalarProperty(
            objectID: objectID,
            selector: kAudioDevicePropertyNominalSampleRate,
            scope: kAudioObjectPropertyScopeGlobal
        )
        let isAlive = (try? booleanProperty(
            objectID: objectID,
            selector: kAudioDevicePropertyDeviceIsAlive,
            scope: kAudioObjectPropertyScopeGlobal
        )) ?? true
        let isRunning = (try? booleanProperty(
            objectID: objectID,
            selector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            scope: kAudioObjectPropertyScopeGlobal
        )) ?? false

        let volumeSelector = kAudioDevicePropertyVolumeScalar
        let muteSelector = kAudioDevicePropertyMute
        let canSetVolume = isSettable(objectID: objectID, selector: volumeSelector, scope: scope)
        let canSetMute = isSettable(objectID: objectID, selector: muteSelector, scope: scope)
        let volume: Float? = try? scalarProperty(
            objectID: objectID,
            selector: volumeSelector,
            scope: scope
        )
        let muteValue: UInt32? = try? scalarProperty(
            objectID: objectID,
            selector: muteSelector,
            scope: scope
        )

        return AudioDevice(
            objectID: objectID,
            uid: uid,
            name: name,
            manufacturer: manufacturer,
            direction: direction,
            transport: AudioTransport(coreAudioValue: transportValue),
            channelCount: channelCount(objectID: objectID, scope: scope),
            nominalSampleRate: sampleRate,
            isAlive: isAlive,
            isRunning: isRunning,
            canSetVolume: canSetVolume,
            canSetMute: canSetMute,
            canSetGain: direction == .input && canSetVolume,
            volume: volume,
            isMuted: muteValue.map { $0 != 0 }
        )
    }

    private func hasStreams(objectID: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool {
        var propertyAddress = address(selector: kAudioDevicePropertyStreams, scope: scope)
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(objectID, &propertyAddress, 0, nil, &dataSize)
        return status == noErr && dataSize >= UInt32(MemoryLayout<AudioStreamID>.size)
    }

    private func channelCount(objectID: AudioObjectID, scope: AudioObjectPropertyScope) -> Int {
        var propertyAddress = address(selector: kAudioDevicePropertyStreamConfiguration, scope: scope)
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(objectID, &propertyAddress, 0, nil, &dataSize) == noErr,
              dataSize >= UInt32(MemoryLayout<AudioBufferList>.size) else { return 0 }

        let pointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { pointer.deallocate() }

        guard AudioObjectGetPropertyData(objectID, &propertyAddress, 0, nil, &dataSize, pointer) == noErr else {
            return 0
        }
        let bufferList = pointer.assumingMemoryBound(to: AudioBufferList.self)
        return UnsafeMutableAudioBufferListPointer(bufferList).reduce(0) { partial, buffer in
            partial + Int(buffer.mNumberChannels)
        }
    }

    private func scope(for direction: AudioDirection) -> AudioObjectPropertyScope {
        direction == .input ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput
    }

    private func isSettable(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> Bool {
        var propertyAddress = address(selector: selector, scope: scope)
        guard AudioObjectHasProperty(objectID, &propertyAddress) else { return false }
        var settable: DarwinBoolean = false
        let status = AudioObjectIsPropertySettable(objectID, &propertyAddress, &settable)
        return status == noErr && settable.boolValue
    }

    private func stringProperty(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) throws -> String {
        var propertyAddress = address(selector: selector, scope: scope)
        guard AudioObjectHasProperty(objectID, &propertyAddress) else {
            throw CoreAudioError(operation: "Read string property", status: kAudioHardwareUnknownPropertyError)
        }
        var value: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(objectID, &propertyAddress, 0, nil, &dataSize, &value)
        guard status == noErr else {
            throw CoreAudioError(operation: "Read string property", status: status)
        }
        guard let value else {
            throw CoreAudioError(operation: "Read string property", status: kAudioHardwareUnspecifiedError)
        }
        return value.takeUnretainedValue() as String
    }

    private func scalarProperty<T: BitwiseCopyable>(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) throws -> T {
        var propertyAddress = address(selector: selector, scope: scope)
        guard AudioObjectHasProperty(objectID, &propertyAddress) else {
            throw CoreAudioError(operation: "Read scalar property", status: kAudioHardwareUnknownPropertyError)
        }
        var dataSize = UInt32(MemoryLayout<T>.size)
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        let status = AudioObjectGetPropertyData(objectID, &propertyAddress, 0, nil, &dataSize, pointer)
        guard status == noErr else {
            throw CoreAudioError(operation: "Read scalar property", status: status)
        }
        return pointer.move()
    }

    private func booleanProperty(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) throws -> Bool {
        var propertyAddress = address(selector: selector, scope: scope)
        guard AudioObjectHasProperty(objectID, &propertyAddress) else {
            throw CoreAudioError(operation: "Read Boolean property", status: kAudioHardwareUnknownPropertyError)
        }
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(objectID, &propertyAddress, 0, nil, &dataSize)
        guard status == noErr, dataSize > 0 else {
            throw CoreAudioError(operation: "Read Boolean property size", status: status)
        }
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize), alignment: 4)
        defer { pointer.deallocate() }
        pointer.initializeMemory(as: UInt8.self, repeating: 0, count: Int(dataSize))
        status = AudioObjectGetPropertyData(objectID, &propertyAddress, 0, nil, &dataSize, pointer)
        guard status == noErr else {
            throw CoreAudioError(operation: "Read Boolean property", status: status)
        }
        return pointer.load(as: UInt8.self) != 0
    }

    private func arrayProperty<T: BitwiseCopyable>(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) throws -> [T] {
        var propertyAddress = address(selector: selector, scope: scope)
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(objectID, &propertyAddress, 0, nil, &dataSize)
        guard status == noErr else {
            throw CoreAudioError(operation: "Read array property size", status: status)
        }
        let count = Int(dataSize) / MemoryLayout<T>.size
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: count)
        defer { pointer.deallocate() }
        status = AudioObjectGetPropertyData(objectID, &propertyAddress, 0, nil, &dataSize, pointer)
        guard status == noErr else {
            throw CoreAudioError(operation: "Read array property", status: status)
        }
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }

    private func setScalarProperty<T: BitwiseCopyable>(
        _ value: T,
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) throws {
        var propertyAddress = address(selector: selector, scope: scope)
        var mutableValue = value
        let status = AudioObjectSetPropertyData(
            objectID,
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<T>.size),
            &mutableValue
        )
        guard status == noErr else {
            throw CoreAudioError(operation: "Set default device", status: status)
        }
    }

    private func address(
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
