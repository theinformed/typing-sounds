// main.swift -- native menu-bar typing sounds with an audio engine that sleeps when quiet.
// Created by LT Sean Egan, PhD 2026-08-19
// Modified: SDE 2026-11-04 profiles, optional key routing and event-driven audio recovery.
import AppKit
import AVFoundation
import ServiceManagement
import CoreGraphics
import Darwin


enum AudioEngineError: LocalizedError {
    case missingResource(String)
    case unsupportedAudioFormat(String)
    case stage(String, Error)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name): return "Missing bundled sound: \(name)"
        case .unsupportedAudioFormat(let name): return "Unsupported sound format: \(name)"
        case .stage(let name, let error): return "\(name): \(error.localizedDescription)"
        }
    }
}

final class SoundOutput {
    static let shared = SoundOutput()
    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
    private var players: [AVAudioPlayerNode] = []
    private var availableAt: [TimeInterval] = []
    private var nextPlayer = 0
    private var idleTimer: DispatchSourceTimer?
    private var buffers: [URL: AVAudioPCMBuffer] = [:]
    private(set) var lastError: Error?
    private(set) var generation = 0
    private var routeObserver: NSObjectProtocol?

    var isRunning: Bool { engine.isRunning }
    var voiceCount: Int { players.count }

    func silenceForTesting() { engine.mainMixerNode.outputVolume = 0 }

    private init() {
        // One graph, eight overlapping voices; no player or decoder per keystroke.
        for _ in 0..<8 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
            availableAt.append(0)
        }
        routeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in self?.stop() }
    }

    deinit {
        if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) }
    }

    func buffer(for url: URL) throws -> AVAudioPCMBuffer {
        if let cached = buffers[url] { return cached }
        let file = try AVAudioFile(forReading: url)
        guard file.processingFormat.sampleRate == format.sampleRate,
              file.processingFormat.channelCount == format.channelCount,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length)) else {
            throw AudioEngineError.unsupportedAudioFormat(url.lastPathComponent)
        }
        try file.read(into: buffer)
        buffers[url] = buffer
        return buffer
    }

    func play(_ buffer: AVAudioPCMBuffer, volume: Double) {
        guard volume > 0 else { return }
        do {
            if !engine.isRunning { try engine.start() }
            lastError = nil
        } catch {
            lastError = error
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        let index = availableAt.firstIndex(where: { $0 <= now }) ?? nextPlayer
        let player = players[index]
        nextPlayer = (index + 1) % players.count
        player.stop()
        player.volume = Float(max(0, min(1, volume)))
        player.scheduleBuffer(buffer, completionHandler: nil)
        player.play()

        // Keep the longest ringing sound, then release the audio hardware. Moving
        // one timer avoids a queue of cancelled callbacks during fast typing.
        let duration = Double(buffer.frameLength) / buffer.format.sampleRate
        availableAt[index] = now + duration
        let remaining = max(0, (availableAt.max() ?? now) - now + 0.2)
        if let timer = idleTimer {
            timer.schedule(deadline: .now() + remaining, leeway: .milliseconds(20))
        } else {
            let timer = DispatchSource.makeTimerSource(queue: .main)
            let timerGeneration = generation
            timer.setEventHandler { [weak self] in
                guard let self, self.generation == timerGeneration else { return }
                self.stop()
            }
            idleTimer = timer
            timer.schedule(deadline: .now() + remaining, leeway: .milliseconds(20))
            timer.resume()
        }
    }

    func stop() {
        generation += 1
        idleTimer?.cancel()
        idleTimer = nil
        players.forEach { $0.stop() }
        engine.stop()
        availableAt = Array(repeating: 0, count: players.count)
    }
}

final class SoundPool {
    private let buffer: AVAudioPCMBuffer

    init(url: URL) throws {
        buffer = try SoundOutput.shared.buffer(for: url)
    }

    var duration: TimeInterval { Double(buffer.frameLength) / buffer.format.sampleRate }

    func play(volume: Double) {
        SoundOutput.shared.play(buffer, volume: volume)
    }
}

final class TypingAudioEngine {
    private struct KeyboardSoundSet {
        let letterPools: [SoundPool]
        let numberPools: [SoundPool]
        let spacePool: SoundPool
        let backspacePool: SoundPool
        let returnPool: SoundPool

        var allPools: [SoundPool] {
            letterPools + numberPools + [spacePool, backspacePool, returnPool]
        }
    }

    private let typingPools: [Int: SoundPool]
    private let typingFallback: SoundPool
    private let clubPool: SoundPool
    private let typewriterKeyPool: SoundPool
    private let typewriterSpacePool: SoundPool
    private let typewriterBackspacePool: SoundPool
    private let typewriterCarriagePool: SoundPool
    private let typewriterBellPool: SoundPool
    private let clackyLetterPools: [SoundPool]
    private let clackyNumberPools: [SoundPool]
    private let sharpLetterPools: [SoundPool]
    private let sharpNumberPools: [SoundPool]
    private let hermesKeyPool: SoundPool
    private let hermesSpacePool: SoundPool
    private let hermesBellPool: SoundPool
    private let modelMLetterPools: [SoundPool]
    private let modelMNumberPools: [SoundPool]
    private let modelMSpacePool: SoundPool
    private let modelMBackspacePool: SoundPool
    private let modelMReturnPool: SoundPool
    private let modelFLetterPools: [SoundPool]
    private let modelFNumberPools: [SoundPool]
    private let modelFSpacePool: SoundPool
    private let modelFBackspacePool: SoundPool
    private let modelFReturnPool: SoundPool
    private let keyboardSets: [SoundPreset: KeyboardSoundSet]
    private let bubblePools: [SoundPool]
    private let musicBoxPools: [SoundPool]
    private let chimePools: [SoundPool]
    private let drumPools: [SoundPool]
    private let casinoPools: [SoundPool]
    private let retroClickPools: [SoundPool]
    private let sparkPools: [SoundPool]
    private let quackPools: [SoundPool]
    private let designedPools: [SoundPreset: [SoundPool]]
    private var musicBoxIndex = 0
    private var chimeIndex = 0
    private var drumIndex = 0
    private var volume = Preferences.shared.volume
    private var playbackGeneration = 0

    // Typing.com's current browser keyCode-to-sprite mapping for ordinary typing keys.
    // Values identify the pre-cut sprite files. Missing browser codes use space's sample.
    private static let typingSegmentByDOMCode: [Int: Int] = [
        8: 1, 9: 2, 10: 3, 11: 4, 12: 5, 13: 6, 14: 7, 15: 8,
        16: 1, 17: 2, 18: 3, 19: 4, 20: 5, 21: 6,
        22: 1, 23: 2, 24: 3, 25: 4, 26: 5, 27: 6, 28: 9,
        29: 0, 30: 2, 31: 3, 32: 4, 33: 5, 34: 6,
        35: 1, 36: 2, 37: 3, 38: 4, 39: 5, 40: 6, 41: 1,
        42: 10, 43: 1, 44: 1, 45: 2, 46: 3, 47: 4,
        48: 5, 49: 6, 50: 1, 51: 2, 52: 3, 53: 4,
        54: 10, 55: 0, 56: 11, 57: 12, 58: 13, 59: 1,
        60: 2, 61: 3, 62: 4, 63: 5, 64: 6,
        65: 1, 66: 2, 67: 3, 68: 4, 69: 2, 70: 2,
        71: 1, 72: 2, 73: 3, 74: 11, 75: 4, 76: 5,
        77: 6, 78: 14, 79: 1, 80: 2, 81: 3, 82: 4,
        83: 5, 87: 5, 88: 6, 91: 1, 92: 2, 93: 3
    ]

    // macOS virtual key codes translated to browser keyCode values used by Typing.com.
    private static let domCodeByMacKeyCode: [CGKeyCode: Int] = [
        0: 65, 1: 83, 2: 68, 3: 70, 4: 72, 5: 71, 6: 90, 7: 88,
        8: 67, 9: 86, 10: 92, 11: 66, 12: 81, 13: 87, 14: 69, 15: 82,
        16: 89, 17: 84, 18: 49, 19: 50, 20: 51, 21: 52, 22: 54, 23: 53,
        24: 61, 25: 57, 26: 55, 27: 45, 28: 56, 29: 48, 30: 93,
        31: 79, 32: 85, 33: 91, 34: 73, 35: 80, 36: 13, 37: 76,
        38: 74, 39: 39, 40: 75, 41: 59, 42: 92, 43: 44, 44: 47,
        45: 78, 46: 77, 47: 46, 48: 9, 49: 32, 50: 96, 51: 8,
        52: 13, 65: 46, 67: 42, 69: 43, 71: 12, 75: 47, 76: 13,
        78: 45, 81: 61, 82: 48, 83: 49, 84: 50, 85: 51, 86: 52,
        87: 53, 88: 54, 89: 55, 91: 56, 92: 57, 117: 8
    ]

    static let soundableKeyCodes: Set<CGKeyCode> = Set(domCodeByMacKeyCode.keys)

    init() throws {
        func bundledPool(_ name: String) throws -> SoundPool {
            guard let url = Bundle.main.url(
                forResource: name,
                withExtension: "wav",
                subdirectory: "Sounds"
            ) else {
                throw AudioEngineError.missingResource("\(name).wav")
            }
            return try SoundPool(url: url)
        }

        func keyboardSet(_ slug: String) throws -> KeyboardSoundSet {
            let keys = try (1...5).map { try bundledPool("kb-\(slug)-key\($0)") }
            return KeyboardSoundSet(
                letterPools: Array(keys[0...3]),
                numberPools: [keys[4], keys[2], keys[1]],
                spacePool: try bundledPool("kb-\(slug)-space"),
                backspacePool: try bundledPool("kb-\(slug)-backspace"),
                returnPool: try bundledPool("kb-\(slug)-return")
            )
        }

        var pools: [Int: SoundPool] = [:]
        for segment in 0..<16 {
            let name = String(format: "typing-com-%02d", segment)
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds") else { continue }
            pools[segment] = try SoundPool(url: url)
        }
        typingPools = pools
        typingFallback = try pools[4] ?? bundledPool("typewriter-key")

        let clubURL = Bundle.main.url(
            forResource: "typingclub-typewriter",
            withExtension: "wav",
            subdirectory: "Sounds"
        )
        clubPool = try clubURL.map { try SoundPool(url: $0) } ?? bundledPool("typewriter-key")

        typewriterKeyPool = try bundledPool("typewriter-key")
        typewriterSpacePool = try bundledPool("typewriter-space")
        typewriterBackspacePool = try bundledPool("typewriter-backspace")
        typewriterCarriagePool = try bundledPool("typewriter-carriage")
        typewriterBellPool = try bundledPool("typewriter-bell")
        clackyLetterPools = try (1...4).map { try bundledPool("clacky-\($0)") }
        clackyNumberPools = try (5...8).map { try bundledPool("clacky-\($0)") }
        sharpLetterPools = try (1...4).map { try bundledPool("sharp-\($0)") }
        sharpNumberPools = try (5...8).map { try bundledPool("sharp-\($0)") }
        hermesKeyPool = try bundledPool("hermes-key")
        hermesSpacePool = try bundledPool("hermes-space")
        hermesBellPool = try bundledPool("hermes-bell")
        modelMLetterPools = try (1...4).map { try bundledPool("model-m-letter-\($0)") }
        modelMNumberPools = try (1...4).map { try bundledPool("model-m-number-\($0)") }
        modelMSpacePool = try bundledPool("model-m-space")
        modelMBackspacePool = try bundledPool("model-m-backspace")
        modelMReturnPool = try bundledPool("model-m-return")
        modelFLetterPools = try (1...4).map { try bundledPool("model-f-letter-\($0)") }
        modelFNumberPools = try (1...4).map { try bundledPool("model-f-number-\($0)") }
        modelFSpacePool = try bundledPool("model-f-space")
        modelFBackspacePool = try bundledPool("model-f-backspace")
        modelFReturnPool = try bundledPool("model-f-return")
        var sets: [SoundPreset: KeyboardSoundSet] = [
            .mxBlue: try keyboardSet("mx-blue"),
            .holyPanda: try keyboardSet("holy-panda"),
            .mxBrown: try keyboardSet("mx-brown"),
            .mxBlack: try keyboardSet("mx-black"),
            .alpaca: try keyboardSet("alpaca"),
            .gateronBlackInk: try keyboardSet("gateron-black-ink"),
            .developerClick: try keyboardSet("developer")
        ]
        for (preset, slug) in [(SoundPreset.nkCream, "nk-cream"), (.boxNavy, "box-navy"),
                                (.topre, "topre"), (.tealios, "tealios"), (.alpsBlue, "alps-blue")] {
            if Bundle.main.url(forResource: "kb-\(slug)-key1", withExtension: "wav", subdirectory: "Sounds") != nil {
                sets[preset] = try keyboardSet(slug)
            }
        }
        keyboardSets = sets
        bubblePools = try (1...5).map { try bundledPool("bubble-\($0)") }
        musicBoxPools = try (1...8).map { try bundledPool("musicbox-\($0)") }
        chimePools = try (1...3).map { try bundledPool("chime-\($0)") }
        drumPools = try ["kick", "hat", "snare", "hat", "kick", "hat", "snare", "hat"].map {
            try bundledPool("drum-\($0)")
        }
        casinoPools = try (1...7).map { try bundledPool("casino-chip-\($0)") }
        retroClickPools = try (1...5).map { try bundledPool("retro-click-\($0)") }
        sparkPools = try (1...6).map { try bundledPool("spark-\($0)") }
        quackPools = try (1...2).map { try bundledPool("quack-\($0)") }
        designedPools = try Dictionary(uniqueKeysWithValues: SoundPreset.designedCases.map { preset in
            (preset, try preset.designedResources.map(bundledPool))
        })
    }

    var diagnosticSummary: String {
        "Typing.com segments: \(typingPools.count); TypingClub duration: \(String(format: "%.3f", clubPool.duration)) seconds"
    }

    func setVolume(_ volume: Double) {
        self.volume = volume
    }

    private func playTypewriterSpecial(
        keyCode: CGKeyCode,
        spacePool: SoundPool,
        bellPool: SoundPool
    ) -> Bool {
        switch keyCode {
        case 36, 52, 76:
            typewriterCarriagePool.play(volume: volume * 0.9)
            let generation = playbackGeneration
            let outputGeneration = SoundOutput.shared.generation
            let bellVolume = volume * 0.65
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self, self.playbackGeneration == generation,
                      SoundOutput.shared.generation == outputGeneration else { return }
                bellPool.play(volume: bellVolume)
            }
            return true
        case 49:
            spacePool.play(volume: volume * 0.8)
            return true
        case 51, 117:
            typewriterBackspacePool.play(volume: volume * 0.8)
            return true
        default:
            return false
        }
    }

    private static let numberKeys: Set<CGKeyCode> = [18, 19, 20, 21, 22, 23, 25, 26, 28, 29, 65, 67, 69, 75, 76, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92]
    private func isNumberKey(_ keyCode: CGKeyCode) -> Bool { Self.numberKeys.contains(keyCode) }

    private func playComputerKeyboardSpecial(
        keyCode: CGKeyCode,
        spacePool: SoundPool,
        backspacePool: SoundPool,
        returnPool: SoundPool
    ) -> Bool {
        switch keyCode {
        case 36, 52, 76:
            returnPool.play(volume: volume)
            return true
        case 49:
            spacePool.play(volume: volume)
            return true
        case 51, 117:
            backspacePool.play(volume: volume * 0.95)
            return true
        default:
            return false
        }
    }

    func play(preset: SoundPreset, macKeyCode: CGKeyCode, volume requestedVolume: Double? = nil) {
        let previousVolume = volume
        if let requestedVolume { volume = requestedVolume }
        defer { volume = previousVolume }
        switch preset {
        case .typingCom:
            let domCode = Self.domCodeByMacKeyCode[macKeyCode] ?? 32
            let segment = Self.typingSegmentByDOMCode[domCode] ?? 4
            (typingPools[segment] ?? typingFallback).play(volume: volume)
        case .typingClub:
            clubPool.play(volume: volume)
        case .classicTypewriter:
            if !playTypewriterSpecial(
                keyCode: macKeyCode,
                spacePool: typewriterSpacePool,
                bellPool: typewriterBellPool
            ) {
                typewriterKeyPool.play(volume: volume * 0.85)
            }
        case .hardClack:
            if !playTypewriterSpecial(
                keyCode: macKeyCode,
                spacePool: typewriterSpacePool,
                bellPool: typewriterBellPool
            ) {
                let pools = isNumberKey(macKeyCode) ? clackyNumberPools : clackyLetterPools
                pools[Int(macKeyCode) % pools.count].play(volume: volume * 0.9)
            }
        case .sharpStrike:
            if !playTypewriterSpecial(
                keyCode: macKeyCode,
                spacePool: typewriterSpacePool,
                bellPool: typewriterBellPool
            ) {
                let pools = isNumberKey(macKeyCode) ? sharpNumberPools : sharpLetterPools
                pools[Int(macKeyCode) % pools.count].play(volume: volume)
                clubPool.play(volume: volume * 0.22)
            }
        case .hermesTypewriter:
            if !playTypewriterSpecial(
                keyCode: macKeyCode,
                spacePool: hermesSpacePool,
                bellPool: hermesBellPool
            ) {
                if isNumberKey(macKeyCode) {
                    clackyNumberPools[Int(macKeyCode) % clackyNumberPools.count].play(volume: volume * 0.72)
                } else {
                    hermesKeyPool.play(volume: volume * 0.9)
                }
            }
        case .ibmModelM:
            if !playComputerKeyboardSpecial(
                keyCode: macKeyCode,
                spacePool: modelMSpacePool,
                backspacePool: modelMBackspacePool,
                returnPool: modelMReturnPool
            ) {
                let pools = isNumberKey(macKeyCode) ? modelMNumberPools : modelMLetterPools
                pools[Int(macKeyCode) % pools.count].play(volume: volume)
            }
        case .ibmModelF:
            if !playComputerKeyboardSpecial(
                keyCode: macKeyCode,
                spacePool: modelFSpacePool,
                backspacePool: modelFBackspacePool,
                returnPool: modelFReturnPool
            ) {
                let pools = isNumberKey(macKeyCode) ? modelFNumberPools : modelFLetterPools
                pools[Int(macKeyCode) % pools.count].play(volume: volume)
            }
        case .mxBlue, .holyPanda, .mxBrown, .mxBlack, .alpaca, .gateronBlackInk, .developerClick, .nkCream, .boxNavy, .topre, .tealios, .alpsBlue:
            guard let set = keyboardSets[preset] else { return }
            if !playComputerKeyboardSpecial(
                keyCode: macKeyCode,
                spacePool: set.spacePool,
                backspacePool: set.backspacePool,
                returnPool: set.returnPool
            ) {
                let pools = isNumberKey(macKeyCode) ? set.numberPools : set.letterPools
                pools[Int(macKeyCode) % pools.count].play(volume: volume)
            }
        case .bubblePop:
            bubblePools[Int(macKeyCode) % bubblePools.count].play(volume: volume * 0.9)
        case .musicBox:
            musicBoxPools[musicBoxIndex].play(volume: volume * 0.45)
            musicBoxIndex = (musicBoxIndex + 1) % musicBoxPools.count
        case .chimes:
            chimePools[chimeIndex].play(volume: volume * 0.4)
            chimeIndex = (chimeIndex + 1) % chimePools.count
        case .drumKit:
            drumPools[drumIndex].play(volume: volume * 0.5)
            drumIndex = (drumIndex + 1) % drumPools.count
        case .casinoChips:
            casinoPools[Int(macKeyCode) % casinoPools.count].play(volume: volume * 0.65)
        case .retroClicks:
            retroClickPools[Int(macKeyCode) % retroClickPools.count].play(volume: volume * 0.75)
        case .electricSpark:
            sparkPools[Int(macKeyCode) % sparkPools.count].play(volume: volume * 0.5)
        case .duckQuacks:
            quackPools[Int(macKeyCode) % quackPools.count].play(volume: volume * 0.72)
        case .mutedTypewriter, .ribbonTypewriter, .electricTypewriter, .deskTypewriter,
             .feltPiano, .marimba, .pluckedStrings, .glassBells, .waterDrops, .woodBlocks,
             .rubberBounce, .arcadeBlips, .terminalBeeps, .radarPings, .laserTicks:
            guard let pools = designedPools[preset] else { return }
            let index: Int
            switch macKeyCode {
            case 36, 52, 76: index = 4
            case 49: index = 3
            case 51, 117: index = 2
            default: index = Int(macKeyCode) % 3
            }
            pools[index].play(volume: volume * 0.8)
        }
    }

    func stop() {
        playbackGeneration += 1
        SoundOutput.shared.stop()
    }

}

final class KeyboardMonitor {
    typealias Handler = (_ keyCode: CGKeyCode, _ isRepeat: Bool, _ flags: CGEventFlags, _ kind: KeyboardEventKind) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let handler: Handler
    var onReset: () -> Void = {}

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    var isActive: Bool { eventTap != nil }

    @discardableResult
    func start(requestPermission: Bool) -> Bool {
        stop()
        if !CGPreflightListenEventAccess() && requestPermission {
            _ = CGRequestListenEventAccess()
        }

        let eventMask = (CGEventMask(1) << CGEventType.keyDown.rawValue) | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                monitor.onReset()
                if let tap = monitor.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown || type == .flagsChanged else { return Unmanaged.passUnretained(event) }
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            monitor.handler(keyCode, isRepeat, event.flags, type == .flagsChanged ? .flagsChanged : .keyDown)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        runLoopSource = nil
        eventTap = nil
    }
}

final class LaunchAtLoginManager {
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    func enable() throws { try SMAppService.mainApp.register() }
    func disable() throws { try SMAppService.mainApp.unregister() }

    func migrateLegacyItem() throws {
        #if !APP_STORE
        let oldPlist = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.seandegan.typingsounds.plist")
        guard FileManager.default.fileExists(atPath: oldPlist.path) else { return }
        // Preserve the previous opt-in before removing its path-specific launcher.
        try enable()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootout", "gui/\(getuid())/com.seandegan.typingsounds"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        try FileManager.default.removeItem(at: oldPlist)
        #endif
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let preferences = Preferences.shared
    private let launchAtLogin = LaunchAtLoginManager()
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var monitor: KeyboardMonitor!
    private var audio: TypingAudioEngine?
    private var audioError: Error?

    private var enabledItem: NSMenuItem!
    private var soundParentItem: NSMenuItem!
    private var presetItems: [SoundPreset: [NSMenuItem]] = [:]
    private var repeatItem: NSMenuItem!
    private var permissionItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!
    private var volumeItems: [NSMenuItem] = []
    private var volumeSlider: NSSlider!
    private var volumeLabel: NSTextField!
    private var libraryItems: [SoundPreset: NSMenuItem] = [:]
    private var iconItems: [MenuIconStyle: NSMenuItem] = [:]
    private var currentConfiguration = SoundConfiguration()
    private var keyRouter = KeyEventRouter()
    private var previewRouter = KeyEventRouter()
    private var settingsController: SettingsWindowController?
    private var floatingPicker: FloatingSoundPickerController?
    private var profileParent: NSMenuItem?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var powerObserver: NSObjectProtocol?
    private var sleeping = false
    private var inactiveSession = false
    private var frontAppID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
    private var frontAppName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "this app"
    private var pauseReason: String? {
        if !preferences.enabled { return "Paused" }
        if sleeping || inactiveSession { return "Paused while the Mac is inactive" }
        if currentConfiguration.muteInLowPowerMode && ProcessInfo.processInfo.isLowPowerModeEnabled {
            return "Paused in Low Power Mode"
        }
        if currentConfiguration.excludedBundleIDs.contains(frontAppID) { return "Paused in " + frontAppName }
        return nil
    }
    private lazy var typewriterTemplateSource: NSImage? = {
        guard let url = Bundle.main.url(
            forResource: "TypewriterTemplate",
            withExtension: "png"
        ) else { return nil }
        return NSImage(contentsOf: url)
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupApplicationMenu()
        setupStatusItem()
        do {
            try launchAtLogin.migrateLegacyItem()
        } catch {
            showAlert(title: "Open at Login", message: error.localizedDescription)
        }

        do {
            audio = try TypingAudioEngine()
        } catch {
            audioError = error
        }

        monitor = KeyboardMonitor { [weak self] keyCode, isRepeat, flags, kind in
            self?.handleKeyDown(keyCode: keyCode, isRepeat: isRepeat, flags: flags, kind: kind)
        }
        monitor.onReset = { [weak self] in self?.keyRouter.reset() }

        observeEnvironment()
        updateMenuState()
        if !CGPreflightListenEventAccess() {
            showSettings()
            settingsController?.tabView.selectTabViewItem(at: 2)
        }

        if let audioError {
            showAlert(
                title: "Typing Sounds could not start audio",
                message: audioError.localizedDescription
            )
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        audio?.stop()
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        if let powerObserver { NotificationCenter.default.removeObserver(powerObserver) }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        updateMenuState()
    }

    private func observeEnvironment() {
        let center = NSWorkspace.shared.notificationCenter
        func observe(_ name: Notification.Name, _ block: @escaping (Notification) -> Void) {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main, using: block))
        }
        observe(NSWorkspace.didActivateApplicationNotification) { [weak self] note in
            guard let self, let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self.frontAppID = app.bundleIdentifier ?? ""
            self.frontAppName = app.localizedName ?? "this app"
            self.keyRouter.reset(); self.previewRouter.reset(); self.updateMenuState()
        }
        observe(NSWorkspace.willSleepNotification) { [weak self] _ in self?.sleeping = true; self?.updateMenuState() }
        observe(NSWorkspace.didWakeNotification) { [weak self] _ in self?.sleeping = false; self?.updateMenuState() }
        observe(NSWorkspace.sessionDidResignActiveNotification) { [weak self] _ in self?.inactiveSession = true; self?.updateMenuState() }
        observe(NSWorkspace.sessionDidBecomeActiveNotification) { [weak self] _ in self?.inactiveSession = false; self?.updateMenuState() }
        powerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in self?.updateMenuState() }
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuState()
    }

    private func setupApplicationMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Typing Sounds")
        appMenu.addItem(withTitle: "About Typing Sounds…", action: #selector(showAbout), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.addItem(withTitle: "Floating Sound Picker…", action: #selector(showFloatingPicker), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Typing Sounds", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Typing Sounds", action: #selector(quit), keyEquivalent: "q").target = self
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = makeStatusIcon(style: preferences.menuIconStyle)
            button.toolTip = "Typing Sounds"
        }

        menu = NSMenu(title: "Typing Sounds")
        menu.delegate = self
        statusItem.menu = menu

        enabledItem = menu.addItem(withTitle: "Typing Sounds", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Floating Sound Picker…", action: #selector(showFloatingPicker), keyEquivalent: "").target = self
        let profiles = NSMenuItem(title: "Profiles", action: nil, keyEquivalent: "")
        profileParent = profiles; menu.addItem(profiles); rebuildProfileMenu()

        menu.addItem(.separator())
        soundParentItem = NSMenuItem(title: "Sound", action: nil, keyEquivalent: "")
        menu.addItem(soundParentItem)
        rebuildSoundMenu()

        let volumeMenu = NSMenu(title: "Volume")
        let volumeView = NSView(frame: NSRect(x: 0, y: 0, width: 230, height: 58))
        volumeLabel = NSTextField(labelWithString: "Volume: 45%")
        volumeLabel.frame = NSRect(x: 16, y: 33, width: 195, height: 17)
        volumeSlider = NSSlider(value: preferences.volume * 100, minValue: 0, maxValue: 100,
                                target: self, action: #selector(adjustMenuVolume(_:)))
        volumeSlider.frame = NSRect(x: 12, y: 8, width: 206, height: 22)
        volumeSlider.isContinuous = true
        volumeSlider.setAccessibilityLabel("Typing sound volume")
        volumeView.addSubview(volumeLabel)
        volumeView.addSubview(volumeSlider)
        let sliderItem = NSMenuItem()
        sliderItem.view = volumeView
        volumeMenu.addItem(sliderItem)
        volumeMenu.addItem(.separator())
        for level in [0.25, 0.45, 0.65, 0.85, 1.0] {
            let percent = Int(level * 100)
            let item = NSMenuItem(title: "\(percent)%", action: #selector(selectVolume(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = level
            volumeMenu.addItem(item)
            volumeItems.append(item)
        }
        let volumeParent = NSMenuItem(title: "Volume", action: nil, keyEquivalent: "")
        volumeParent.submenu = volumeMenu
        menu.addItem(volumeParent)

        let testSoundItem = menu.addItem(withTitle: "Test Current Sound", action: #selector(testCurrentSound), keyEquivalent: "")
        testSoundItem.target = self

        let libraryParent = NSMenuItem(title: "Sounds Shown in Menu", action: nil, keyEquivalent: "")
        let libraryMenu = NSMenu(title: "Sounds Shown in Menu")
        for (category, presets) in SoundCategory.settingsSections {
            let categoryItem = NSMenuItem(title: category.title, action: nil, keyEquivalent: "")
            let categoryMenu = NSMenu(title: category.title)
            for preset in presets where SoundPreset.availableCases.contains(preset) {
                let item = NSMenuItem(title: preset.title, action: #selector(toggleLibraryProfile(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = preset.rawValue
                categoryMenu.addItem(item)
                libraryItems[preset] = item
            }
            if !categoryMenu.items.isEmpty {
                categoryItem.submenu = categoryMenu
                libraryMenu.addItem(categoryItem)
            }
        }
        libraryMenu.addItem(.separator())
        libraryMenu.addItem(withTitle: "Show All Sounds", action: #selector(showAllPresets), keyEquivalent: "").target = self
        libraryMenu.addItem(withTitle: "Popular Sounds Only", action: #selector(showPopularPresets), keyEquivalent: "").target = self
        libraryParent.submenu = libraryMenu
        menu.addItem(libraryParent)

        repeatItem = menu.addItem(withTitle: "Sound on held-key repeats", action: #selector(toggleRepeats), keyEquivalent: "")
        repeatItem.target = self

        let iconMenu = NSMenu(title: "Menu Bar Icon")
        for style in MenuIconStyle.selectableCases {
            let item = NSMenuItem(title: style.title, action: #selector(selectMenuIcon(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style.rawValue
            item.image = makeStatusIcon(style: style)
            iconMenu.addItem(item)
            iconItems[style] = item
        }
        let iconParent = NSMenuItem(title: "Menu Bar Icon", action: nil, keyEquivalent: "")
        iconParent.submenu = iconMenu
        menu.addItem(iconParent)

        menu.addItem(.separator())
        permissionItem = menu.addItem(withTitle: "Input Monitoring", action: #selector(handlePermissionItem), keyEquivalent: "")
        permissionItem.target = self

        launchAtLoginItem = menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self

        menu.addItem(withTitle: "About Typing Sounds…", action: #selector(showAbout), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Typing Sounds", action: #selector(quit), keyEquivalent: "q").target = self
    }

    private func rebuildSoundMenu() {
        guard soundParentItem != nil else { return }
        let visible = preferences.visiblePresets.intersection(SoundPreset.availableCases)
        let soundMenu = NSMenu(title: "Sounds")
        presetItems.removeAll()

        for category in SoundCategory.allCases {
            let categoryPresets = category.presets.filter { visible.contains($0) }
            guard !categoryPresets.isEmpty else { continue }

            let categoryMenu = NSMenu(title: category.title)
            for section in category.menuSections {
                let presets = section.presets.filter { visible.contains($0) }
                guard !presets.isEmpty else { continue }
                if !section.title.isEmpty {
                    if !categoryMenu.items.isEmpty { categoryMenu.addItem(.separator()) }
                    let heading = NSMenuItem(title: section.title, action: nil, keyEquivalent: "")
                    heading.isEnabled = false
                    categoryMenu.addItem(heading)
                }
                for preset in presets {
                    let item = NSMenuItem(title: preset.title, action: #selector(selectPreset(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = preset.rawValue
                    categoryMenu.addItem(item)
                    presetItems[preset, default: []].append(item)
                }
            }

            let categoryItem = NSMenuItem(title: category.title, action: nil, keyEquivalent: "")
            categoryItem.image = NSImage(
                systemSymbolName: category.symbolName,
                accessibilityDescription: category.title
            )
            categoryItem.submenu = categoryMenu
            soundMenu.addItem(categoryItem)
        }

        soundParentItem.submenu = soundMenu
        soundParentItem.title = "Sound: \(preferences.preset.title)"
    }

    private func soundLibraryDidChange() {
        let visible = preferences.visiblePresets.intersection(SoundPreset.availableCases)
        if !visible.contains(preferences.preset),
           let replacement = SoundPreset.allCases.first(where: visible.contains) {
            preferences.preset = replacement
            audio?.play(preset: replacement, macKeyCode: 49)
        }
        rebuildSoundMenu()
        refreshStatusIcon()
        updateMenuState()
    }

    private func resolvedIconStyle(_ style: MenuIconStyle) -> MenuIconStyle {
        guard style == .automatic else { return style }
        switch preferences.preset {
        case .typingCom, .ibmModelM, .ibmModelF, .mxBlue, .holyPanda, .mxBrown,
             .mxBlack, .alpaca, .gateronBlackInk, .developerClick, .nkCream, .boxNavy, .topre, .tealios, .alpsBlue:
            return .commandSound
        case .typingClub, .classicTypewriter, .hardClack, .sharpStrike, .hermesTypewriter,
             .mutedTypewriter, .ribbonTypewriter, .electricTypewriter, .deskTypewriter: return .typewriter
        case .musicBox, .chimes, .drumKit, .feltPiano, .marimba, .pluckedStrings, .glassBells: return .music
        case .bubblePop, .casinoChips, .duckQuacks, .retroClicks, .electricSpark,
             .waterDrops, .woodBlocks, .rubberBounce, .arcadeBlips, .terminalBeeps, .radarPings, .laserTicks: return .waveform
        }
    }

    private func makeStatusIcon(style: MenuIconStyle, active: Bool = false) -> NSImage {
        let resolved = resolvedIconStyle(style)
        if resolved == .commandSound {
            return makeCommandSoundStatusIcon(active: active)
        }
        if resolved == .typewriter {
            return makeTypewriterStatusIcon(active: active)
        }

        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let image: NSImage
        if let symbolName = resolved.symbolName {
            image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: "Typing Sounds"
            )?.withSymbolConfiguration(configuration) ?? NSImage()
        } else {
            image = NSImage()
        }
        image.isTemplate = true
        return image
    }

    private func makeCommandSoundStatusIcon(active: Bool) -> NSImage {
        let commandConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let waveConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = NSImage(size: NSSize(width: 21, height: 18), flipped: false) { _ in
            guard
                let command = NSImage(
                    systemSymbolName: "command",
                    accessibilityDescription: "Typing Sounds"
                )?.withSymbolConfiguration(commandConfiguration),
                let waves = NSImage(
                    systemSymbolName: "wave.3.right",
                    accessibilityDescription: nil
                )?.withSymbolConfiguration(waveConfiguration)
            else { return false }

            command.draw(in: NSRect(x: 0, y: 2.25, width: 13.5, height: 13.5))
            waves.draw(in: NSRect(
                x: active ? 11.1 : 11.4,
                y: active ? 2.8 : 3.1,
                width: active ? 9.8 : 9.2,
                height: active ? 12.4 : 11.8
            ))
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Typing Sounds command symbol with sound waves"
        return image
    }

    private func makeTypewriterStatusIcon(active: Bool) -> NSImage {
        guard let source = typewriterTemplateSource else {
            let fallback = NSImage(
                systemSymbolName: "keyboard.fill",
                accessibilityDescription: "Typing Sounds"
            ) ?? NSImage()
            fallback.isTemplate = true
            return fallback
        }

        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSGraphicsContext.current?.imageInterpolation = .high
            let sourceRect = NSRect(x: 254, y: 330, width: 688, height: 585)
            let destinationRect = NSRect(
                x: 0.55,
                y: active ? 2.15 : 1.70,
                width: 16.90,
                height: 14.38
            )
            source.draw(
                in: destinationRect,
                from: sourceRect,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: false,
                hints: [.interpolation: NSImageInterpolation.high]
            )
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Typing Sounds typewriter"
        return image
    }

    private func refreshStatusIcon(active: Bool = false) {
        statusItem?.button?.image = makeStatusIcon(style: preferences.menuIconStyle, active: active)
    }

    private func handleKeyDown(keyCode: CGKeyCode, isRepeat: Bool, flags: CGEventFlags,
                               kind: KeyboardEventKind) {
        guard settingsController?.isTesting != true, audioError == nil,
              let sound = keyRouter.route(keyCode: keyCode, kind: kind, flags: flags.rawValue,
                                          isRepeat: isRepeat, configuration: currentConfiguration) else { return }
        audio?.play(preset: sound.preset, macKeyCode: sound.keyCode, volume: sound.volume)
    }

    fileprivate func updateMenuState() {
        let configuration = preferences.configuration
        if configuration != currentConfiguration {
            audio?.stop()
            audio?.setVolume(configuration.volume)
            keyRouter.reset()
        }
        currentConfiguration = configuration
        if pauseReason == nil {
            if monitor != nil && !monitor.isActive { monitor.start(requestPermission: false) }
        } else {
            monitor?.stop(); audio?.stop(); keyRouter.reset(); previewRouter.reset()
            currentConfiguration.enabled = false
        }
        if settingsController?.window?.isVisible == true { settingsController?.refresh() }
        if floatingPicker?.window?.isVisible == true { floatingPicker?.refresh() }
        rebuildProfileMenu()
        enabledItem?.state = preferences.enabled ? .on : .off
        enabledItem?.title = preferences.enabled ? "Typing Sounds: On" : "Typing Sounds: Off"
        volumeSlider?.doubleValue = preferences.volume * 100
        volumeLabel?.stringValue = "Volume: \(Int(preferences.volume * 100))%"
        let visiblePresets = preferences.visiblePresets
        libraryItems.forEach { preset, item in
            item.state = visiblePresets.contains(preset) ? .on : .off
        }
        presetItems.forEach { preset, items in
            items.forEach { $0.state = preferences.preset == preset ? .on : .off }
        }
        soundParentItem?.title = "Sound: \(preferences.preset.title)"
        repeatItem?.state = preferences.includeRepeats ? .on : .off
        iconItems.forEach { style, item in
            item.state = preferences.menuIconStyle == style ? .on : .off
        }
        volumeItems.forEach { item in
            guard let level = item.representedObject as? Double else { return }
            item.state = abs(level - preferences.volume) < 0.001 ? .on : .off
        }

        if CGPreflightListenEventAccess() {
            permissionItem?.title = monitor?.isActive == true ? "Input Monitoring: Active" : "Input Monitoring: Allowed"
        } else {
            permissionItem?.title = "Input Monitoring Required…"
        }

        launchAtLoginItem?.state = launchAtLogin.isEnabled ? .on : .off
        launchAtLoginItem?.title = launchAtLogin.needsApproval ? "Launch at Login: Approval Required…" : "Launch at Login"

        statusItem?.button?.appearsDisabled = pauseReason != nil || monitor?.isActive != true
        statusItem?.button?.toolTip = "Typing Sounds · " + (pauseReason ?? "On")
    }

    @objc fileprivate func toggleEnabled() {
        preferences.enabled.toggle()
        if preferences.enabled {
            monitor.start(requestPermission: true)
        } else {
            monitor.stop()
            audio?.stop()
        }
        updateMenuState()
    }

    @objc private func adjustMenuVolume(_ slider: NSSlider) {
        preferences.volume = slider.doubleValue / 100
        audio?.setVolume(preferences.volume)
        updateMenuState()
    }

    @objc private func toggleLibraryProfile(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let preset = SoundPreset(rawValue: rawValue) else { return }
        let visible = preferences.visiblePresets.contains(preset)
        guard !visible || preferences.visiblePresets.count > 1 else { return }
        preferences.setPreset(preset, visible: !visible)
        soundLibraryDidChange()
    }

    @objc private func showAllPresets() {
        preferences.hiddenPresets = []
        soundLibraryDidChange()
    }

    @objc private func showPopularPresets() {
        preferences.hiddenPresets = Set(SoundPreset.availableCases).subtracting(SoundCategory.popular.presets)
        soundLibraryDidChange()
    }

    @objc private func selectPreset(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let preset = SoundPreset(rawValue: rawValue) else { return }
        preferences.preset = preset
        refreshStatusIcon()
        updateMenuState()
        audio?.play(preset: preset, macKeyCode: 49)
    }

    @objc private func selectVolume(_ sender: NSMenuItem) {
        guard let level = sender.representedObject as? Double else { return }
        preferences.volume = level
        audio?.setVolume(level)
        updateMenuState()
    }

    @objc private func toggleRepeats() {
        preferences.includeRepeats.toggle()
        updateMenuState()
    }

    @objc private func selectMenuIcon(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let style = MenuIconStyle(rawValue: rawValue) else { return }
        preferences.menuIconStyle = style
        refreshStatusIcon()
        updateMenuState()
    }

    @objc fileprivate func testCurrentSound() {
        audio?.play(preset: preferences.preset, macKeyCode: 49)
    }

    @objc private func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(
                onChange: { [weak self] in self?.settingsChanged() },
                onPreview: { [weak self] preset in self?.audio?.play(preset: preset, macKeyCode: 49, volume: self?.preferences.volume) },
                onPermission: { [weak self] in self?.handlePermissionItem() },
                onLogin: { [weak self] in self?.toggleLaunchAtLogin() },
                loginEnabled: { [weak self] in self?.launchAtLogin.isEnabled == true || self?.launchAtLogin.needsApproval == true },
                statusText: { [weak self] in
                    if let error = SoundOutput.shared.lastError { return "Audio output: " + error.localizedDescription }
                    return self?.pauseReason ?? "Sounds enabled · audio sleeps when quiet"
                },
                onTestKey: { [weak self] code, repeated, flags, kind in
                    guard let self else { return }
                    var config = self.preferences.configuration
                    config.enabled = true
                    guard let sound = self.previewRouter.route(keyCode: code, kind: kind, flags: flags,
                                                               isRepeat: repeated, configuration: config) else { return }
                    self.audio?.play(preset: sound.preset, macKeyCode: sound.keyCode, volume: sound.volume)
                }, iconImage: { [weak self] style in self?.makeStatusIcon(style: style) },
                onShowPicker: { [weak self] in self?.showFloatingPicker() })
        }
        previewRouter.reset()
        settingsController?.show()
    }

    @objc private func showFloatingPicker() {
        if floatingPicker == nil {
            floatingPicker = FloatingSoundPickerController(
                onChange: { [weak self] in self?.settingsChanged() },
                onPreview: { [weak self] preset in
                    self?.audio?.play(preset: preset, macKeyCode: 0, volume: self?.preferences.volume)
                }, onSettings: { [weak self] in self?.showSettings() })
        }
        floatingPicker?.show()
    }

    private func settingsChanged() {
        rebuildSoundMenu(); refreshStatusIcon(); updateMenuState()
    }

    private func rebuildProfileMenu() {
        guard let profileParent else { return }
        let profiles = NSMenu(title: "Profiles")
        for profile in preferences.profiles {
            let item = NSMenuItem(title: profile.name, action: #selector(selectProfile(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = profile.id
            item.state = preferences.activeProfileID == profile.id ? .on : .off
            profiles.addItem(item)
        }
        profiles.addItem(.separator())
        profiles.addItem(withTitle: "Manage Profiles…", action: #selector(showSettings), keyEquivalent: "").target = self
        profileParent.submenu = profiles
    }

    @objc private func selectProfile(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        preferences.applyProfile(id: id); settingsChanged()
    }

    @objc fileprivate func handlePermissionItem() {
        if monitor.start(requestPermission: true) {
            updateMenuState()
        } else {
            showPermissionExplanation()
        }
    }

    @objc fileprivate func toggleLaunchAtLogin() {
        do {
            if launchAtLogin.needsApproval {
                SMAppService.openSystemSettingsLoginItems()
            } else if launchAtLogin.isEnabled {
                try launchAtLogin.disable()
            } else {
                try launchAtLogin.enable()
            }
        } catch {
            showAlert(title: "Launch at Login", message: error.localizedDescription)
        }
        updateMenuState()
    }

    @objc private func showAbout() {
        showSettings()
        settingsController?.tabView.selectTabViewItem(at: 3)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showPermissionExplanation() {
        let alert = NSAlert()
        alert.messageText = "Allow Input Monitoring"
        alert.informativeText = "Typing Sounds needs Input Monitoring to notice key-down events in other apps. It only uses numeric key codes to choose a sound and never saves or transmits what you type.\n\nEnable “Typing Sounds” in System Settings → Privacy & Security → Input Monitoring, then choose Input Monitoring Required from the menu-bar keyboard icon."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")
        if alert.runModal() == .alertFirstButtonReturn {
            openInputMonitoringSettings()
        }
    }

    private func openInputMonitoringSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ]
        for value in urls {
            if let url = URL(string: value), NSWorkspace.shared.open(url) { return }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

if CommandLine.arguments.contains("--floating-self-test") || CommandLine.arguments.contains("--render-floating") {
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    application.finishLaunching()
    let suite = "TypingSoundsFloatingTest." + UUID().uuidString
    let isolated = UserDefaults(suiteName: suite)!
    let preferences = Preferences(defaults: isolated)
    var changes = 0
    var previews: [SoundPreset] = []
    let controller = FloatingSoundPickerController(preferences: preferences,
        onChange: { changes += 1 }, onPreview: { previews.append($0) })
    func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    let view = controller.window!.contentView!
    if CommandLine.arguments.contains("--floating-self-test") {
        let controls = descendants(view)
        let buttons = controls.compactMap { $0 as? NSButton }
        guard let next = buttons.first(where: { $0.identifier?.rawValue == "nextSound" }),
              let previous = buttons.first(where: { $0.identifier?.rawValue == "previousSound" }),
              let preview = buttons.first(where: { $0.identifier?.rawValue == "previewSound" }),
              let category = controls.compactMap({ $0 as? NSPopUpButton }).first(where: { $0.accessibilityLabel() == "Sound category" }),
              let sound = controls.compactMap({ $0 as? NSPopUpButton }).first(where: { $0.accessibilityLabel() == "Selected sound" }),
              let volume = controls.compactMap({ $0 as? NSSlider }).first else { exit(EXIT_FAILURE) }
        let original = preferences.preset
        next.performClick(nil); precondition(preferences.preset != original && previews.count == 1)
        previous.performClick(nil); precondition(preferences.preset == original && previews.count == 2)
        preview.performClick(nil); precondition(preferences.preset == original && previews.count == 3)
        category.selectItem(at: 1); _ = category.sendAction(category.action, to: category.target)
        sound.selectItem(at: sound.numberOfItems - 1); _ = sound.sendAction(sound.action, to: sound.target)
        next.performClick(nil); precondition(sound.indexOfSelectedItem == 0)
        previous.performClick(nil); precondition(sound.indexOfSelectedItem == sound.numberOfItems - 1)
        let automatic = buttons.first { $0.title == "Preview when switching" }!
        automatic.performClick(nil)
        let previewCount = previews.count
        next.performClick(nil); precondition(previews.count == previewCount)
        volume.doubleValue = 27; _ = volume.sendAction(volume.action, to: volume.target)
        precondition(abs(preferences.volume - 0.27) < 0.001 && changes > 4)
        let enabled = buttons.first { $0.title == "Typing sounds enabled" }!
        enabled.performClick(nil); precondition(!preferences.enabled)
        preferences.preset = .musicBox; controller.refresh()
        precondition(category.indexOfSelectedItem == 0 && sound.titleOfSelectedItem == SoundPreset.musicBox.title)
        precondition(controller.window!.level == .floating && !controller.window!.hidesOnDeactivate)
        precondition(controller.window!.styleMask.contains(.nonactivatingPanel) && !controller.window!.canBecomeKey)
        print("PASS: floating picker, category wrap, selection, preview, volume, pause and isolated persistence")
    }
    if let index = CommandLine.arguments.firstIndex(of: "--render-floating"), CommandLine.arguments.indices.contains(index + 1) {
        let directory = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        controller.show()
        for (appearance, name) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark")] {
            application.appearance = NSAppearance(named: appearance)
            controller.window?.appearance = application.appearance
            view.appearance = application.appearance; view.layoutSubtreeIfNeeded()
            for child in descendants(view) { child.needsDisplay = true }
            controller.window?.display()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(EXIT_FAILURE) }
            view.effectiveAppearance.performAsCurrentDrawingAppearance { view.cacheDisplay(in: view.bounds, to: bitmap) }
            guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(EXIT_FAILURE) }
            try png.write(to: directory.appendingPathComponent("floating-\(name).png"))
        }
        controller.window?.orderOut(nil)
        print("Rendered floating picker in light and dark appearance without screen capture")
    }
    isolated.removePersistentDomain(forName: suite)
    exit(EXIT_SUCCESS)
}

if CommandLine.arguments.contains("--settings-self-test") || CommandLine.arguments.contains("--render-settings") {
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    application.finishLaunching()
    let suite = "TypingSoundsViewTest." + UUID().uuidString
    let isolated = UserDefaults(suiteName: suite)!
    let preferences = Preferences(defaults: isolated)
    var changes = 0
    let controller = SettingsWindowController(preferences: preferences, onChange: { changes += 1 })
    func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(descendants)
    }
    if CommandLine.arguments.contains("--settings-self-test") {
        let controls = controller.tabView.tabViewItems.flatMap { descendants($0.view!) }
        guard controller.tabView.numberOfTabViewItems == 4,
              let custom = controls.compactMap({ $0 as? NSButton }).first(where: { $0.title == "Customize special-key sounds" }),
              let volume = controls.compactMap({ $0 as? NSSlider }).first(where: { $0.accessibilityLabel() == "Typing sound volume" }) else {
            fputs("FAIL: native settings controls are missing\n", stderr); exit(EXIT_FAILURE)
        }
        custom.performClick(nil)
        guard preferences.specialKeysEnabled else { fputs("FAIL: custom key toggle\n", stderr); exit(EXIT_FAILURE) }
        volume.doubleValue = 23
        _ = volume.sendAction(volume.action, to: volume.target)
        guard abs(preferences.volume - 0.23) < 0.001, changes >= 2 else {
            fputs("FAIL: volume settings did not persist\n", stderr); exit(EXIT_FAILURE)
        }
        print("PASS: four native settings panes, special-key toggle, volume and isolated persistence")
    }
    if let index = CommandLine.arguments.firstIndex(of: "--render-settings"),
       CommandLine.arguments.indices.contains(index + 1) {
        let directory = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        controller.window?.orderFront(nil)
        for (appearance, name) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark")] {
            application.appearance = NSAppearance(named: appearance)
            controller.window?.appearance = application.appearance
            for tab in 0..<controller.tabView.numberOfTabViewItems {
                controller.tabView.selectTabViewItem(at: tab)
                let view = controller.window!.contentView!
                view.appearance = application.appearance
                view.layoutSubtreeIfNeeded()
                for child in descendants(view) { child.needsDisplay = true }
                controller.window?.display()
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                    fputs("FAIL: cannot render settings view\n", stderr); exit(EXIT_FAILURE)
                }
                view.effectiveAppearance.performAsCurrentDrawingAppearance {
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                }
                guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(EXIT_FAILURE) }
                try png.write(to: directory.appendingPathComponent("settings-\(tab)-\(name).png"))
            }
        }
        print("Rendered eight settings views without screen capture")
        controller.window?.orderOut(nil)
    }
    isolated.removePersistentDomain(forName: suite)
    exit(EXIT_SUCCESS)
}

if CommandLine.arguments.contains("--self-test") {
    let soundDirectory = Bundle.main.resourceURL?.appendingPathComponent("Sounds")
    var requiredNames: [String] = []
    requiredNames += SoundPreset.designedCases.flatMap { $0.designedResources.map { $0 + ".wav" } }
    if SoundPreset.availableCases.contains(.typingCom) {
        requiredNames += (0..<16).map { String(format: "typing-com-%02d.wav", $0) }
    }
    if SoundPreset.availableCases.contains(.typingClub) { requiredNames += ["typingclub-typewriter.wav"] }
    requiredNames += [
        "typewriter-key.wav", "typewriter-space.wav", "typewriter-backspace.wav",
        "typewriter-carriage.wav", "typewriter-bell.wav",
        "hermes-key.wav", "hermes-space.wav", "hermes-bell.wav",
        "drum-kick.wav", "drum-hat.wav", "drum-snare.wav"
    ]
    requiredNames += (1...8).map { "clacky-\($0).wav" }
    requiredNames += (1...8).map { "sharp-\($0).wav" }
    requiredNames += (1...4).map { "model-m-letter-\($0).wav" }
    requiredNames += (1...4).map { "model-m-number-\($0).wav" }
    requiredNames += ["model-m-space.wav", "model-m-backspace.wav", "model-m-return.wav"]
    requiredNames += (1...4).map { "model-f-letter-\($0).wav" }
    requiredNames += (1...4).map { "model-f-number-\($0).wav" }
    requiredNames += ["model-f-space.wav", "model-f-backspace.wav", "model-f-return.wav"]
    requiredNames += (1...5).map { "bubble-\($0).wav" }
    requiredNames += (1...8).map { "musicbox-\($0).wav" }
    for profile in ["mx-blue", "holy-panda", "mx-brown", "mx-black", "alpaca", "gateron-black-ink", "developer", "nk-cream", "box-navy", "topre", "tealios", "alps-blue"] {
        requiredNames += (1...5).map { "kb-\(profile)-key\($0).wav" }
        requiredNames += ["kb-\(profile)-space.wav", "kb-\(profile)-backspace.wav", "kb-\(profile)-return.wav"]
    }
    requiredNames += (1...3).map { "chime-\($0).wav" }
    requiredNames += (1...7).map { "casino-chip-\($0).wav" }
    requiredNames += (1...5).map { "retro-click-\($0).wav" }
    requiredNames += (1...6).map { "spark-\($0).wav" }
    requiredNames += (1...2).map { "quack-\($0).wav" }
    let missing = requiredNames.filter { name in
        guard let url = soundDirectory?.appendingPathComponent(name) else { return true }
        return !FileManager.default.fileExists(atPath: url.path)
    }
    if missing.isEmpty {
        for name in requiredNames {
            do {
                let file = try AVAudioFile(forReading: soundDirectory!.appendingPathComponent(name))
                guard file.length > 0, file.processingFormat.sampleRate == 48_000,
                      file.processingFormat.channelCount == 2 else {
                    fputs("FAIL: unsupported audio format: \(name)\n", stderr)
                    exit(EXIT_FAILURE)
                }
            } catch {
                fputs("FAIL: cannot decode \(name): \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }
        }
        print("PASS: \(requiredNames.count) bundled sound files")
        exit(EXIT_SUCCESS)
    }
    fputs("FAIL: missing or empty resources: \(missing.joined(separator: ", "))\n", stderr)
    exit(EXIT_FAILURE)
}


if CommandLine.arguments.contains("--benchmark") {
    _ = NSApplication.shared
    let audio = try TypingAudioEngine()
    SoundOutput.shared.silenceForTesting()
    let presetIndex = CommandLine.arguments.firstIndex(of: "--preset")
    let preset = presetIndex.flatMap { index in
        CommandLine.arguments.indices.contains(index + 1)
            ? SoundPreset(rawValue: CommandLine.arguments[index + 1]) : nil
    } ?? .classicTypewriter
    var benchmarkConfiguration = SoundConfiguration()
    benchmarkConfiguration.preset = preset
    benchmarkConfiguration.volume = Preferences.shared.volume
    var benchmarkRouter = KeyEventRouter()
    func cpuSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    }
    func phase(_ name: String, seconds: Double, typing: Bool) {
        let startCPU = cpuSeconds()
        let start = Date()
        let keys: [CGKeyCode] = [0, 1, 2, 3, 49, 4, 5, 6, 7, 51, 18, 36]
        var count = 0
        while Date().timeIntervalSince(start) < seconds {
            if typing {
                if let sound = benchmarkRouter.route(keyCode: keys[count % keys.count], kind: .keyDown,
                    flags: 0, isRepeat: false, configuration: benchmarkConfiguration) {
                    audio.play(preset: sound.preset, macKeyCode: sound.keyCode, volume: sound.volume)
                }
                count += 1
            }
            let deadline = typing ? start.addingTimeInterval(Double(count) / 12)
                                  : Date().addingTimeInterval(1.0 / 12.0)
            RunLoop.main.run(until: deadline)
        }
        let elapsed = Date().timeIntervalSince(start)
        let cpu = (cpuSeconds() - startCPU) / elapsed * 100
        print(String(format: "%@ %@: %.2f%% CPU, %d keys", preset.rawValue, name, cpu, count))
    }
    phase("idle-before", seconds: 4, typing: false)
    phase("typing", seconds: 10, typing: true)
    phase("settle", seconds: 3, typing: false)
    phase("idle-after", seconds: 4, typing: false)
    guard !SoundOutput.shared.isRunning, SoundOutput.shared.lastError == nil else {
        fputs("FAIL: audio did not become idle or could not start\n", stderr)
        exit(EXIT_FAILURE)
    }
    audio.stop()
    exit(EXIT_SUCCESS)
}

if CommandLine.arguments.contains("--audio-test") {
    _ = NSApplication.shared
    let audio = try TypingAudioEngine()
    SoundOutput.shared.silenceForTesting()
    for preset in SoundPreset.availableCases {
        for key: CGKeyCode in [0, 18, 49, 51, 36] {
            audio.play(preset: preset, macKeyCode: key)
            RunLoop.main.run(until: Date().addingTimeInterval(0.04))
        }
        guard SoundOutput.shared.isRunning, SoundOutput.shared.lastError == nil else {
            fputs("FAIL: audio playback for \(preset.rawValue)\n", stderr)
            exit(EXIT_FAILURE)
        }
        audio.stop()
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))
        guard !SoundOutput.shared.isRunning else {
            fputs("FAIL: audio continued after disabling sounds\n", stderr)
            exit(EXIT_FAILURE)
        }
    }
    audio.play(preset: .classicTypewriter, macKeyCode: 0)
    RunLoop.main.run(until: Date().addingTimeInterval(3))
    guard !SoundOutput.shared.isRunning else {
        fputs("FAIL: audio remained active after the final sample\n", stderr)
        exit(EXIT_FAILURE)
    }
    print("PASS: \(SoundPreset.availableCases.count) profiles, overlap, restart, stop and idle shutdown")
    exit(EXIT_SUCCESS)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
