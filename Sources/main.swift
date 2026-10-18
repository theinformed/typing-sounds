// main.swift -- native menu-bar typing sounds with an audio engine that sleeps when quiet.
// Created by LT Sean Egan, PhD 2026-08-19
// Modified: SDE 2026-10-18 shared audio, native login items and application settings.
import AppKit
import AVFoundation
import ServiceManagement
import Carbon
import CoreGraphics
import Darwin

enum SoundPreset: String, CaseIterable {
    case typingCom
    case typingClub
    case classicTypewriter
    case hardClack
    case sharpStrike
    case hermesTypewriter
    case ibmModelM
    case ibmModelF
    case mxBlue
    case holyPanda
    case mxBrown
    case mxBlack
    case alpaca
    case gateronBlackInk
    case developerClick
    case bubblePop
    case musicBox
    case chimes
    case drumKit
    case casinoChips
    case retroClicks
    case electricSpark
    case duckQuacks

    // The two website recordings are optional personal assets, excluded from releases.
    static var availableCases: [SoundPreset] {
        allCases.filter { preset in
            let name: String
            switch preset {
            case .typingCom: name = "typing-com-04"
            case .typingClub: name = "typingclub-typewriter"
            default: return true
            }
            return Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds") != nil
        }
    }

    var title: String {
        switch self {
        case .typingCom: return "Typing.com"
        case .typingClub: return "TypingClub"
        case .classicTypewriter: return "Classic Typewriter"
        case .hardClack: return "Typewriter: Hard Clack"
        case .sharpStrike: return "Typewriter: Sharp Strike"
        case .hermesTypewriter: return "Typewriter: Hermes 305"
        case .ibmModelM: return "Vintage PC: IBM Model M"
        case .ibmModelF: return "Vintage Terminal: IBM Model F"
        case .mxBlue: return "Mechanical: MX Blue"
        case .holyPanda: return "Mechanical: Holy Panda"
        case .mxBrown: return "Mechanical: MX Brown"
        case .mxBlack: return "Mechanical: MX Black"
        case .alpaca: return "Mechanical: Alpaca"
        case .gateronBlackInk: return "Mechanical: Gateron Black Ink"
        case .developerClick: return "Developer Click"
        case .bubblePop: return "Bubble Pop"
        case .musicBox: return "Music Box"
        case .chimes: return "Bright Chimes"
        case .drumKit: return "Drum Kit"
        case .casinoChips: return "Casino Chips"
        case .retroClicks: return "Retro UI Clicks"
        case .electricSpark: return "Electric Sparks"
        case .duckQuacks: return "Duck Quacks"
        }
    }

    var detail: String {
        switch self {
        case .typingCom: return "The crisp, varied Typing.com test sound"
        case .typingClub: return "TypingClub's compact typewriter tick"
        case .classicTypewriter: return "Keys, backspace, space and carriage return"
        case .hardClack: return "A weightier, slower mechanical strike"
        case .sharpStrike: return "The hardest and fastest typewriter profile"
        case .hermesTypewriter: return "A bright Hermes Precisa 305 recording"
        case .ibmModelM: return "Loud 1986 buckling-spring PC keyboard"
        case .ibmModelF: return "Metallic 1984 terminal buckling springs"
        case .mxBlue: return "Classic clicky mechanical switches"
        case .holyPanda: return "Rounded, tactile mechanical thock"
        case .mxBrown: return "Balanced tactile mechanical switches"
        case .mxBlack: return "Deep linear mechanical switches"
        case .alpaca: return "Soft, smooth linear mechanical switches"
        case .gateronBlackInk: return "Low, substantial linear switch sound"
        case .developerClick: return "Short code-editor clicks with special keys"
        case .bubblePop: return "Five light, bouncy pops"
        case .musicBox: return "A playful eight-note melody"
        case .chimes: return "Clear, higher musical tones"
        case .drumKit: return "Kick, hi-hat and snare rhythm"
        case .casinoChips: return "Bright chips landing and colliding"
        case .retroClicks: return "Tiny old-school interface blips"
        case .electricSpark: return "Fast electronic crackles"
        case .duckQuacks: return "Completely unserious quacking"
        }
    }
}

enum SoundCategory: String, CaseIterable {
    case popular
    case keyboards
    case typewriters
    case musical
    case fun
    case electronic

    var title: String {
        switch self {
        case .popular: return "Most Popular"
        case .keyboards: return "Keyboards"
        case .typewriters: return "Typewriters"
        case .musical: return "Musical"
        case .fun: return "Fun"
        case .electronic: return "Electronic & Retro"
        }
    }

    var symbolName: String {
        switch self {
        case .popular: return "star.fill"
        case .keyboards: return "keyboard.fill"
        case .typewriters: return "textformat"
        case .musical: return "music.note.list"
        case .fun: return "party.popper.fill"
        case .electronic: return "bolt.fill"
        }
    }

    var presets: [SoundPreset] {
        switch self {
        case .popular:
            return [.typingCom, .typingClub, .classicTypewriter, .ibmModelM, .ibmModelF]
        case .keyboards:
            return [
                .typingCom, .typingClub, .ibmModelM, .ibmModelF, .mxBlue,
                .holyPanda, .mxBrown, .mxBlack, .alpaca, .gateronBlackInk,
                .developerClick
            ]
        case .typewriters:
            return [.classicTypewriter, .hardClack, .sharpStrike, .hermesTypewriter]
        case .musical:
            return [.musicBox, .chimes, .drumKit]
        case .fun:
            return [.bubblePop, .casinoChips, .duckQuacks]
        case .electronic:
            return [.retroClicks, .electricSpark]
        }
    }

    static let settingsSections: [(SoundCategory, [SoundPreset])] = [
        (.popular, [.typingCom, .typingClub, .classicTypewriter, .ibmModelM, .ibmModelF]),
        (.keyboards, [.mxBlue, .holyPanda, .mxBrown, .mxBlack, .alpaca, .gateronBlackInk, .developerClick]),
        (.typewriters, [.hardClack, .sharpStrike, .hermesTypewriter]),
        (.musical, [.musicBox, .chimes, .drumKit]),
        (.fun, [.bubblePop, .casinoChips, .duckQuacks]),
        (.electronic, [.retroClicks, .electricSpark])
    ]
}

enum MenuIconStyle: String, CaseIterable {
    case automatic
    case commandSound
    case typewriter
    case waveform
    case typingCursor
    case keyboard
    case bubbles
    case music
    case drum

    var title: String {
        switch self {
        case .automatic: return "Automatic by Sound"
        case .commandSound: return "Command + Sound"
        case .typewriter: return "Typewriter"
        case .waveform: return "Waveform"
        case .typingCursor: return "Typing Cursor"
        case .keyboard: return "Keyboard"
        case .bubbles: return "Bubbles"
        case .music: return "Music Note"
        case .drum: return "Drum"
        }
    }

    var symbolName: String? {
        switch self {
        case .automatic, .commandSound, .typewriter: return nil
        case .waveform: return "waveform"
        case .typingCursor: return "character.cursor.ibeam"
        case .keyboard: return "keyboard.fill"
        case .bubbles: return "circle.grid.2x2.fill"
        case .music: return "music.note"
        case .drum: return "drum.fill"
        }
    }
}

final class Preferences {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let enabled = "enabled"
        static let preset = "preset"
        static let volume = "volume"
        static let includeRepeats = "includeRepeats"
        static let menuIconStyle = "menuIconStyle"
        static let hiddenPresets = "hiddenPresets"
    }

    private init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.preset: SoundPreset.typingCom.rawValue,
            Key.volume: 0.45,
            Key.includeRepeats: false,
            Key.menuIconStyle: MenuIconStyle.commandSound.rawValue
        ])
    }

    var enabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    var preset: SoundPreset {
        get {
            let saved = SoundPreset(rawValue: defaults.string(forKey: Key.preset) ?? "") ?? .classicTypewriter
            return SoundPreset.availableCases.contains(saved) ? saved : .classicTypewriter
        }
        set { defaults.set(newValue.rawValue, forKey: Key.preset) }
    }

    var volume: Double {
        get { defaults.double(forKey: Key.volume) }
        set { defaults.set(newValue, forKey: Key.volume) }
    }

    var includeRepeats: Bool {
        get { defaults.bool(forKey: Key.includeRepeats) }
        set { defaults.set(newValue, forKey: Key.includeRepeats) }
    }

    var menuIconStyle: MenuIconStyle {
        get { MenuIconStyle(rawValue: defaults.string(forKey: Key.menuIconStyle) ?? "") ?? .commandSound }
        set { defaults.set(newValue.rawValue, forKey: Key.menuIconStyle) }
    }

    var hiddenPresets: Set<SoundPreset> {
        get {
            let rawValues = defaults.stringArray(forKey: Key.hiddenPresets) ?? []
            return Set(rawValues.compactMap(SoundPreset.init(rawValue:)))
        }
        set {
            defaults.set(newValue.map(\.rawValue).sorted(), forKey: Key.hiddenPresets)
        }
    }

    var visiblePresets: Set<SoundPreset> {
        Set(SoundPreset.availableCases).subtracting(hiddenPresets)
    }

    func setPreset(_ preset: SoundPreset, visible: Bool) {
        var hidden = hiddenPresets
        if visible {
            hidden.remove(preset)
        } else {
            hidden.insert(preset)
        }
        hiddenPresets = hidden
    }
}

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
    private var availableAt: [Date] = []
    private var nextPlayer = 0
    private var idleTimer: Timer?
    private var quietAfter = Date.distantPast
    private var buffers: [URL: AVAudioPCMBuffer] = [:]
    private(set) var lastError: Error?

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
            availableAt.append(.distantPast)
        }
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
        let now = Date()
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
        availableAt[index] = now.addingTimeInterval(duration)
        quietAfter = (availableAt.max() ?? now).addingTimeInterval(0.2)
        if let timer = idleTimer {
            timer.fireDate = quietAfter
        } else {
            let timer = Timer(fire: quietAfter, interval: 0, repeats: false) { [weak self] _ in
                self?.stop()
            }
            idleTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        idleTimer?.invalidate()
        idleTimer = nil
        players.forEach { $0.stop() }
        engine.stop()
        availableAt = Array(repeating: .distantPast, count: players.count)
        quietAfter = .distantPast
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
        keyboardSets = [
            .mxBlue: try keyboardSet("mx-blue"),
            .holyPanda: try keyboardSet("holy-panda"),
            .mxBrown: try keyboardSet("mx-brown"),
            .mxBlack: try keyboardSet("mx-black"),
            .alpaca: try keyboardSet("alpaca"),
            .gateronBlackInk: try keyboardSet("gateron-black-ink"),
            .developerClick: try keyboardSet("developer")
        ]
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self, self.playbackGeneration == generation else { return }
                bellPool.play(volume: self.volume * 0.65)
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

    private func isNumberKey(_ keyCode: CGKeyCode) -> Bool {
        let numberKeys: Set<CGKeyCode> = [18, 19, 20, 21, 22, 23, 25, 26, 28, 29, 65, 67, 69, 75, 76, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92]
        return numberKeys.contains(keyCode)
    }

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

    func play(preset: SoundPreset, macKeyCode: CGKeyCode) {
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
        case .mxBlue, .holyPanda, .mxBrown, .mxBlack, .alpaca, .gateronBlackInk, .developerClick:
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
        }
    }

    func stop() {
        playbackGeneration += 1
        SoundOutput.shared.stop()
    }

}

final class KeyboardMonitor {
    typealias Handler = (_ keyCode: CGKeyCode, _ isRepeat: Bool, _ flags: CGEventFlags) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let handler: Handler

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

        let eventMask = CGEventMask(1) << CGEventType.keyDown.rawValue
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = monitor.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else { return Unmanaged.passUnretained(event) }
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            monitor.handler(keyCode, isRepeat, event.flags)
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
    }
}

final class SoundLibraryWindowController: NSWindowController {
    private let preferences = Preferences.shared
    private let onLibraryChange: () -> Void
    private let onPreview: (SoundPreset) -> Void
    private var checkboxes: [SoundPreset: NSButton] = [:]

    init(onLibraryChange: @escaping () -> Void, onPreview: @escaping (SoundPreset) -> Void) {
        self.onLibraryChange = onLibraryChange
        self.onPreview = onPreview

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 570, height: 660),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sound Library Settings"
        window.minSize = NSSize(width: 500, height: 480)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildInterface()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        refreshCheckboxes()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildInterface() {
        guard let contentView = window?.contentView else { return }

        let title = NSTextField(labelWithString: "Choose the sounds shown in your menu")
        title.font = .systemFont(ofSize: 20, weight: .semibold)

        let subtitle = NSTextField(wrappingLabelWithString: "Every checked sound appears in its group under the menu-bar icon. Preview anything here without changing your current sound.")
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 2

        let headingStack = NSStackView(views: [title, subtitle])
        headingStack.orientation = .vertical
        headingStack.alignment = .leading
        headingStack.spacing = 6
        headingStack.translatesAutoresizingMaskIntoConstraints = false

        let libraryStack = NSStackView()
        libraryStack.orientation = .vertical
        libraryStack.alignment = .leading
        libraryStack.spacing = 8
        libraryStack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 18, right: 20)
        libraryStack.translatesAutoresizingMaskIntoConstraints = false

        for (category, sectionPresets) in SoundCategory.settingsSections {
            let presets = sectionPresets.filter { SoundPreset.availableCases.contains($0) }
            let symbol = NSImage(
                systemSymbolName: category.symbolName,
                accessibilityDescription: category.title
            )?.withSymbolConfiguration(.init(pointSize: 13, weight: .semibold))
            let categoryIcon = NSImageView(image: symbol ?? NSImage())
            categoryIcon.contentTintColor = .controlAccentColor
            let categoryLabel = NSTextField(labelWithString: category.title)
            categoryLabel.font = .systemFont(ofSize: 14, weight: .semibold)
            let categoryHeader = NSStackView(views: [categoryIcon, categoryLabel])
            categoryHeader.orientation = .horizontal
            categoryHeader.alignment = .centerY
            categoryHeader.spacing = 7
            categoryHeader.setHuggingPriority(.required, for: .horizontal)
            libraryStack.addArrangedSubview(categoryHeader)

            for preset in presets {
                let checkbox = NSButton(
                    checkboxWithTitle: preset.title,
                    target: self,
                    action: #selector(togglePresetVisibility(_:))
                )
                checkbox.identifier = NSUserInterfaceItemIdentifier(preset.rawValue)
                checkbox.font = .systemFont(ofSize: 13, weight: .medium)
                checkboxes[preset] = checkbox

                let detail = NSTextField(labelWithString: preset.detail)
                detail.font = .systemFont(ofSize: 11)
                detail.textColor = .secondaryLabelColor
                let textStack = NSStackView(views: [checkbox, detail])
                textStack.orientation = .vertical
                textStack.alignment = .leading
                textStack.spacing = 1

                let spacer = NSView()
                spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
                let preview = NSButton(
                    image: NSImage(systemSymbolName: "play.circle", accessibilityDescription: "Preview") ?? NSImage(),
                    target: self,
                    action: #selector(previewPreset(_:))
                )
                preview.identifier = NSUserInterfaceItemIdentifier(preset.rawValue)
                preview.bezelStyle = .inline
                preview.toolTip = "Preview \(preset.title)"

                let row = NSStackView(views: [textStack, spacer, preview])
                row.orientation = .horizontal
                row.alignment = .centerY
                row.spacing = 8
                row.translatesAutoresizingMaskIntoConstraints = false
                row.widthAnchor.constraint(equalTo: libraryStack.widthAnchor, constant: -40).isActive = true
                row.edgeInsets = NSEdgeInsets(top: 2, left: 24, bottom: 4, right: 2)
                libraryStack.addArrangedSubview(row)
            }

            let gap = NSView()
            gap.translatesAutoresizingMaskIntoConstraints = false
            gap.heightAnchor.constraint(equalToConstant: 6).isActive = true
            libraryStack.addArrangedSubview(gap)
        }

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(libraryStack)
        NSLayoutConstraint.activate([
            libraryStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            libraryStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            libraryStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            libraryStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor)
        ])

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = documentView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor).isActive = true

        let showAll = NSButton(title: "Show All", target: self, action: #selector(showAllPresets))
        let popularOnly = NSButton(title: "Popular Only", target: self, action: #selector(showPopularPresets))
        let footerSpacer = NSView()
        footerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let done = NSButton(title: "Done", target: self, action: #selector(closeWindow))
        done.keyEquivalent = "\r"
        done.bezelStyle = .rounded
        let footer = NSStackView(views: [showAll, popularOnly, footerSpacer, done])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 10
        footer.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(headingStack)
        contentView.addSubview(scrollView)
        contentView.addSubview(footer)
        NSLayoutConstraint.activate([
            headingStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            headingStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            headingStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.topAnchor.constraint(equalTo: headingStack.bottomAnchor, constant: 16),
            footer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            footer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            footer.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 14),
            footer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        ])
    }

    private func refreshCheckboxes() {
        let visible = preferences.visiblePresets.intersection(SoundPreset.availableCases)
        for (preset, checkbox) in checkboxes {
            checkbox.state = visible.contains(preset) ? .on : .off
        }
    }

    @objc private func togglePresetVisibility(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue,
              let preset = SoundPreset(rawValue: rawValue) else { return }
        let wantsVisible = sender.state == .on
        if !wantsVisible && preferences.visiblePresets.count == 1 {
            NSSound.beep()
            sender.state = .on
            return
        }
        preferences.setPreset(preset, visible: wantsVisible)
        onLibraryChange()
        refreshCheckboxes()
    }

    @objc private func previewPreset(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue,
              let preset = SoundPreset(rawValue: rawValue) else { return }
        onPreview(preset)
    }

    @objc private func showAllPresets() {
        preferences.hiddenPresets = []
        onLibraryChange()
        refreshCheckboxes()
    }

    @objc private func showPopularPresets() {
        preferences.hiddenPresets = Set(SoundPreset.allCases).subtracting(Set(SoundCategory.popular.presets))
        onLibraryChange()
        refreshCheckboxes()
    }

    @objc private func closeWindow() {
        window?.close()
    }
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private weak var appOwner: AppDelegate?
    private let enabled = NSButton(checkboxWithTitle: "Enable typing sounds", target: nil, action: nil)
    private let sound = NSPopUpButton(frame: .zero, pullsDown: false)
    private let volume = NSSlider(value: 45, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let volumeLabel = NSTextField(labelWithString: "45%")
    private let repeats = NSButton(checkboxWithTitle: "Play sounds when a key is held down", target: nil, action: nil)
    private let login = NSButton(checkboxWithTitle: "Open at login", target: nil, action: nil)
    private let permission = NSTextField(wrappingLabelWithString: "")

    init(owner: AppDelegate) {
        self.appOwner = owner
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 570),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "Typing Sounds"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self

        let title = NSTextField(labelWithString: "Typing Sounds")
        title.font = .systemFont(ofSize: 26, weight: .bold)
        let subtitle = NSTextField(wrappingLabelWithString: "Keyboard sounds, wherever you type.\nUse the ⌘ sound icon in the menu bar for quick controls.")
        subtitle.textColor = .secondaryLabelColor
        let soundRow = NSStackView(views: [NSTextField(labelWithString: "Sound"), sound])
        soundRow.spacing = 14
        sound.addItems(withTitles: SoundPreset.availableCases.map(\.title))
        sound.target = self
        sound.action = #selector(selectSound)
        volume.target = self
        volume.action = #selector(adjustVolume)
        volume.isContinuous = true
        volume.widthAnchor.constraint(equalToConstant: 280).isActive = true
        let volumeRow = NSStackView(views: [NSTextField(labelWithString: "Volume"), volume, volumeLabel])
        volumeRow.spacing = 12
        enabled.target = owner
        enabled.action = #selector(AppDelegate.toggleEnabled)
        repeats.target = self
        repeats.action = #selector(adjustRepeats)
        login.target = owner
        login.action = #selector(AppDelegate.toggleLaunchAtLogin)
        let preview = NSButton(title: "Preview Sound", target: owner, action: #selector(AppDelegate.testCurrentSound))
        let library = NSButton(title: "Sound Library…", target: owner, action: #selector(AppDelegate.showSoundLibrary))
        let buttons = NSStackView(views: [preview, library])
        buttons.spacing = 12
        permission.font = .systemFont(ofSize: 12)
        permission.textColor = .secondaryLabelColor
        let allow = NSButton(title: "Input Monitoring…", target: owner, action: #selector(AppDelegate.handlePermissionItem))
        let privacy = NSTextField(wrappingLabelWithString: "No keystroke history, accounts or network access. Audio goes quiet when you stop typing.")
        privacy.font = .systemFont(ofSize: 11)
        privacy.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [title, subtitle, enabled, soundRow, volumeRow,
                                       buttons, repeats, login, permission, allow, privacy])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 13
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 26),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: window.contentView!.bottomAnchor, constant: -22)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refresh() {
        guard isWindowLoaded else { return }
        let prefs = Preferences.shared
        enabled.state = prefs.enabled ? .on : .off
        sound.selectItem(withTitle: prefs.preset.title)
        volume.doubleValue = prefs.volume * 100
        volumeLabel.stringValue = "\(Int(prefs.volume * 100))%"
        repeats.state = prefs.includeRepeats ? .on : .off
        let manager = LaunchAtLoginManager()
        login.state = manager.isEnabled || manager.needsApproval ? .on : .off
        login.title = manager.needsApproval ? "Open at login: approve in System Settings…" : "Open at login"
        permission.stringValue = CGPreflightListenEventAccess()
            ? "Input Monitoring is allowed."
            : "Allow Input Monitoring in System Settings to hear sounds in other apps."
    }

    func show() {
        refresh()
        NSApp.setActivationPolicy(.regular)
        if window?.isVisible != true { window?.center() }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    @objc private func selectSound() {
        let index = sound.indexOfSelectedItem
        guard SoundPreset.availableCases.indices.contains(index) else { return }
        appOwner?.changePreset(SoundPreset.availableCases[index])
    }
    @objc private func adjustVolume() { appOwner?.changeVolume(volume.doubleValue / 100) }
    @objc private func adjustRepeats() { appOwner?.changeRepeats(repeats.state == .on) }
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
    private var iconItems: [MenuIconStyle: NSMenuItem] = [:]
    private var currentEnabled = true
    private var currentPreset = SoundPreset.classicTypewriter
    private var currentRepeats = false
    private lazy var settingsWindow = SettingsWindowController(owner: self)
    private lazy var soundLibraryWindow = SoundLibraryWindowController(
        onLibraryChange: { [weak self] in self?.soundLibraryDidChange() },
        onPreview: { [weak self] preset in
            self?.audio?.play(preset: preset, macKeyCode: 49)
        }
    )
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
        let openLibraryOnLaunch = CommandLine.arguments.contains("--open-library")

        do {
            audio = try TypingAudioEngine()
        } catch {
            audioError = error
        }

        monitor = KeyboardMonitor { [weak self] keyCode, isRepeat, flags in
            self?.handleKeyDown(keyCode: keyCode, isRepeat: isRepeat, flags: flags)
        }

        if preferences.enabled { monitor.start(requestPermission: true) }
        updateMenuState()

        let loginLaunch = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if openLibraryOnLaunch {
            soundLibraryWindow.show()
        } else if !loginLaunch {
            showSettings()
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
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if preferences.enabled, monitor != nil, !monitor.isActive, CGPreflightListenEventAccess() {
            monitor.start(requestPermission: false)
        }
        updateMenuState()
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

        menu.addItem(.separator())
        soundParentItem = NSMenuItem(title: "Sound", action: nil, keyEquivalent: "")
        menu.addItem(soundParentItem)
        rebuildSoundMenu()

        let volumeMenu = NSMenu(title: "Volume")
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

        let libraryItem = menu.addItem(withTitle: "Sound Library Settings…", action: #selector(showSoundLibrary), keyEquivalent: "")
        libraryItem.target = self

        repeatItem = menu.addItem(withTitle: "Sound on held-key repeats", action: #selector(toggleRepeats), keyEquivalent: "")
        repeatItem.target = self

        let iconMenu = NSMenu(title: "Menu Bar Icon")
        for style in MenuIconStyle.allCases {
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
            for preset in categoryPresets {
                let item = NSMenuItem(title: preset.title, action: #selector(selectPreset(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = preset.rawValue
                categoryMenu.addItem(item)
                presetItems[preset, default: []].append(item)
            }

            let categoryItem = NSMenuItem(title: category.title, action: nil, keyEquivalent: "")
            categoryItem.image = NSImage(
                systemSymbolName: category.symbolName,
                accessibilityDescription: category.title
            )
            categoryItem.submenu = categoryMenu
            soundMenu.addItem(categoryItem)
        }

        soundMenu.addItem(.separator())
        let customize = NSMenuItem(title: "Customize Sound Library…", action: #selector(showSoundLibrary), keyEquivalent: "")
        customize.target = self
        soundMenu.addItem(customize)
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
             .mxBlack, .alpaca, .gateronBlackInk, .developerClick:
            return .commandSound
        case .typingClub, .classicTypewriter, .hardClack, .sharpStrike, .hermesTypewriter: return .typewriter
        case .bubblePop, .casinoChips, .duckQuacks: return .bubbles
        case .musicBox, .chimes: return .music
        case .drumKit: return .drum
        case .retroClicks, .electricSpark: return .waveform
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

    private func handleKeyDown(keyCode: CGKeyCode, isRepeat: Bool, flags: CGEventFlags) {
        guard currentEnabled,
              audioError == nil,
              TypingAudioEngine.soundableKeyCodes.contains(keyCode),
              currentRepeats || !isRepeat,
              !flags.contains(.maskCommand),
              !flags.contains(.maskControl) else { return }

        audio?.play(preset: currentPreset, macKeyCode: keyCode)
    }

    fileprivate func updateMenuState() {
        currentEnabled = preferences.enabled
        currentPreset = preferences.preset
        currentRepeats = preferences.includeRepeats
        settingsWindow.refresh()
        enabledItem?.state = preferences.enabled ? .on : .off
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

        if monitor?.isActive == true {
            permissionItem?.title = "Input Monitoring: Active"
        } else {
            permissionItem?.title = "Input Monitoring Required…"
        }

        launchAtLoginItem?.state = launchAtLogin.isEnabled ? .on : .off
        launchAtLoginItem?.title = launchAtLogin.needsApproval ? "Launch at Login: Approval Required…" : "Launch at Login"

        statusItem?.button?.appearsDisabled = !preferences.enabled || monitor?.isActive != true
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

    fileprivate func changePreset(_ preset: SoundPreset) {
        preferences.preset = preset
        audio?.play(preset: preset, macKeyCode: 49)
        refreshStatusIcon()
        updateMenuState()
    }

    fileprivate func changeVolume(_ volume: Double) {
        preferences.volume = volume
        audio?.setVolume(volume)
        updateMenuState()
    }

    fileprivate func changeRepeats(_ enabled: Bool) {
        preferences.includeRepeats = enabled
        updateMenuState()
    }

    @objc private func selectPreset(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let preset = SoundPreset(rawValue: rawValue) else { return }
        preferences.preset = preset
        audio?.play(preset: preset, macKeyCode: 49)
        refreshStatusIcon()
        updateMenuState()
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

    @objc fileprivate func showSettings() {
        settingsWindow.show()
    }

    @objc fileprivate func showSoundLibrary() {
        soundLibraryWindow.show()
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
        let alert = NSAlert()
        alert.messageText = "Typing Sounds"
        alert.informativeText = "A local-only menu-bar app. It observes key-down codes solely to play audio; it does not store typed content or use the network.\n\nIncludes \(SoundPreset.availableCases.count) sound profiles across keyboards, typewriters, music, fun and retro effects. Third-party notices are bundled with the app."
        alert.addButton(withTitle: "OK")
        alert.runModal()
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

if CommandLine.arguments.contains("--self-test") {
    let soundDirectory = Bundle.main.resourceURL?.appendingPathComponent("Sounds")
    var requiredNames: [String] = []
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
    for profile in ["mx-blue", "holy-panda", "mx-brown", "mx-black", "alpaca", "gateron-black-ink", "developer"] {
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
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else { return true }
        return size.intValue <= 44
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
                audio.play(preset: preset, macKeyCode: keys[count % keys.count])
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
