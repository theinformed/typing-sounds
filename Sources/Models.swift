// Models.swift -- sound choices, profiles and content-free keyboard routing.
// Created by LT Sean Egan, PhD 2026-11-04
import Foundation
import CoreGraphics

enum KeyGroup: String, CaseIterable, Codable {
    case enter, space, backspace, tab, escape, shift, control, option, command
    case capsLock, function, arrows, forwardDelete

    var title: String {
        switch self {
        case .enter: return "Return / Enter"
        case .space: return "Space"
        case .backspace: return "Backspace"
        case .tab: return "Tab"
        case .escape: return "Escape"
        case .shift: return "Shift"
        case .control: return "Control"
        case .option: return "Option"
        case .command: return "Command"
        case .capsLock: return "Caps Lock"
        case .function: return "Fn / Globe"
        case .arrows: return "Arrow keys"
        case .forwardDelete: return "Forward Delete"
        }
    }

    static func group(for code: CGKeyCode) -> KeyGroup? {
        switch code {
        case 36, 52, 76: return .enter
        case 49: return .space
        case 51: return .backspace
        case 48: return .tab
        case 53: return .escape
        case 56, 60: return .shift
        case 59, 62: return .control
        case 58, 61: return .option
        case 54, 55: return .command
        case 57: return .capsLock
        case 63: return .function
        case 123...126: return .arrows
        case 117: return .forwardDelete
        default: return nil
        }
    }

    var defaultSound: (code: CGKeyCode?, gain: Double) {
        switch self {
        case .shift: return (6, 0.55)
        case .control: return (7, 0.55)
        case .option: return (8, 0.55)
        case .command: return (9, 0.55)
        case .capsLock: return (10, 0.7)
        case .function: return (11, 0.55)
        case .arrows: return (12, 0.75)
        case .escape: return (13, 0.75)
        case .tab, .forwardDelete: return (nil, 0.8)
        case .enter, .space, .backspace: return (nil, 1)
        }
    }
}

enum SoundSelection: Codable, Equatable {
    case `default`, silent, typing
    case preset(SoundPreset)
}

struct KeyMapping: Codable, Equatable {
    var sound: SoundSelection = .default
    var volume: Double = 1
}

struct SoundConfiguration: Codable, Equatable {
    var enabled = true
    var preset: SoundPreset = .mxBrown
    var volume = 0.45
    var includeRepeats = false
    var specialKeysEnabled = false
    var includeShortcuts = false
    var keyMappings: [KeyGroup: KeyMapping] = [:]
    var muteInLowPowerMode = false
    var excludedBundleIDs: [String] = []
    var menuIconStyle: MenuIconStyle = .commandSound

    func sanitized() -> SoundConfiguration {
        var copy = self
        copy.volume = volume.isFinite ? min(1, max(0, volume)) : 0.45
        copy.keyMappings = keyMappings.mapValues { mapping in
            var clean = mapping
            clean.volume = mapping.volume.isFinite ? min(1, max(0, mapping.volume)) : 1
            return clean
        }
        copy.excludedBundleIDs = Array(Set(excludedBundleIDs.filter { !$0.isEmpty })).sorted()
        if !MenuIconStyle.selectableCases.contains(copy.menuIconStyle) { copy.menuIconStyle = .automatic }
        return copy
    }
}

enum KeyboardEventKind { case keyDown, flagsChanged }

struct RoutedKeySound: Equatable {
    let preset: SoundPreset
    let keyCode: CGKeyCode
    let volume: Double
}

struct KeyEventRouter {
    private var pressed: Set<CGKeyCode> = []
    private var capsState: Bool?
    static let ordinaryCodes: Set<CGKeyCode> = Set([
        0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,
        24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,
        45,46,47,48,49,50,51,52,65,67,69,71,75,76,78,81,82,83,84,85,86,
        87,88,89,91,92,117
    ])

    mutating func reset() { pressed.removeAll(keepingCapacity: true); capsState = nil }

    // Side-specific flags distinguish a release while the opposite modifier stays down.
    private static func modifier(_ code: CGKeyCode) -> (UInt64, UInt64, UInt64)? {
        switch code {
        case 56: return (0x20000, 0x2, 0x6)
        case 60: return (0x20000, 0x4, 0x6)
        case 59: return (0x40000, 0x1, 0x2001)
        case 62: return (0x40000, 0x2000, 0x2001)
        case 58: return (0x80000, 0x20, 0x60)
        case 61: return (0x80000, 0x40, 0x60)
        case 55: return (0x100000, 0x8, 0x18)
        case 54: return (0x100000, 0x10, 0x18)
        case 63: return (0x800000, 0, 0)
        default: return nil
        }
    }

    mutating func route(keyCode: CGKeyCode, kind: KeyboardEventKind, flags: UInt64,
                        isRepeat: Bool, configuration c: SoundConfiguration) -> RoutedKeySound? {
        let group = KeyGroup.group(for: keyCode)
        if kind == .flagsChanged {
            if keyCode == 57 {
                let state = flags & 0x10000 != 0
                guard state != capsState else { return nil }
                capsState = state
            } else {
                guard let (aggregate, side, sideGroup) = Self.modifier(keyCode) else { return nil }
                let down: Bool
                if flags & aggregate == 0 { down = false }
                else if side == 0 { down = true }
                else if flags & sideGroup != 0 { down = flags & side != 0 }
                else { down = !pressed.contains(keyCode) }
                if !down { pressed.remove(keyCode); return nil }
                guard pressed.insert(keyCode).inserted else { return nil }
            }
        } else if Self.modifier(keyCode) != nil || keyCode == 57 {
            return nil
        }

        guard c.enabled, c.volume.isFinite, c.volume > 0,
              !isRepeat || c.includeRepeats else { return nil }
        if kind == .keyDown && !c.includeShortcuts && flags & 0x140000 != 0 { return nil }
        guard Self.ordinaryCodes.contains(keyCode) || group != nil else { return nil }

        var preset = c.preset
        var routedCode = group?.defaultSound.code ?? keyCode
        var gain = min(1, c.volume)
        if let group {
            let mapping = c.specialKeysEnabled ? c.keyMappings[group] ?? KeyMapping() : KeyMapping()
            gain *= mapping.volume.isFinite ? min(1, max(0, mapping.volume)) : 1
            switch mapping.sound {
            case .silent: return nil
            case .typing: routedCode = 0
            case .preset(let choice): preset = choice
            case .default: gain *= group.defaultSound.gain
            }
        }
        guard gain > 0 else { return nil }
        // Explicit same-as-typing overrides retain key zero, including on modifiers.
        return RoutedKeySound(preset: preset, keyCode: routedCode, volume: gain)
    }
}

struct SavedProfile: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var configuration: SoundConfiguration
    var isBuiltin: Bool { id.hasPrefix("builtin.") }
}

final class Preferences {
    static let shared = Preferences()
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["enabled": true, "preset": SoundPreset.typingCom.rawValue,
            "volume": 0.45, "includeRepeats": false, "menuIconStyle": MenuIconStyle.commandSound.rawValue])
    }
    var enabled: Bool { get { defaults.bool(forKey: "enabled") } set { defaults.set(newValue, forKey: "enabled") } }
    var preset: SoundPreset {
        get {
            let saved = SoundPreset(rawValue: defaults.string(forKey: "preset") ?? "") ?? .classicTypewriter
            return SoundPreset.availableCases.contains(saved) ? saved : .classicTypewriter
        }
        set { defaults.set(newValue.rawValue, forKey: "preset") }
    }
    var volume: Double {
        get { let v = defaults.double(forKey: "volume"); return v.isFinite ? min(1, max(0, v)) : 0.45 }
        set { defaults.set(newValue.isFinite ? min(1, max(0, newValue)) : 0.45, forKey: "volume") }
    }
    var includeRepeats: Bool { get { defaults.bool(forKey: "includeRepeats") } set { defaults.set(newValue, forKey: "includeRepeats") } }
    var menuIconStyle: MenuIconStyle {
        get {
            let style = MenuIconStyle(rawValue: defaults.string(forKey: "menuIconStyle") ?? "") ?? .commandSound
            return MenuIconStyle.selectableCases.contains(style) ? style : .automatic
        }
        set { defaults.set(newValue.rawValue, forKey: "menuIconStyle") }
    }
    var specialKeysEnabled: Bool { get { defaults.bool(forKey: "specialKeysEnabled") } set { defaults.set(newValue, forKey: "specialKeysEnabled") } }
    var includeShortcuts: Bool { get { defaults.bool(forKey: "includeShortcuts") } set { defaults.set(newValue, forKey: "includeShortcuts") } }
    var muteInLowPowerMode: Bool { get { defaults.bool(forKey: "muteInLowPowerMode") } set { defaults.set(newValue, forKey: "muteInLowPowerMode") } }
    var excludedBundleIDs: [String] {
        get { defaults.stringArray(forKey: "excludedBundleIDs") ?? [] }
        set { defaults.set(Array(Set(newValue)).sorted(), forKey: "excludedBundleIDs") }
    }
    var keyMappings: [KeyGroup: KeyMapping] {
        get {
            guard let data = defaults.data(forKey: "keyMappings"),
                  let result = try? JSONDecoder().decode([KeyGroup: KeyMapping].self, from: data) else { return [:] }
            return result
        }
        set { if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: "keyMappings") } }
    }
    var hiddenPresets: Set<SoundPreset> {
        get { Set((defaults.stringArray(forKey: "hiddenPresets") ?? []).compactMap(SoundPreset.init(rawValue:))) }
        set { defaults.set(newValue.map(\.rawValue).sorted(), forKey: "hiddenPresets") }
    }
    var visiblePresets: Set<SoundPreset> { Set(SoundPreset.availableCases).subtracting(hiddenPresets) }
    func setPreset(_ preset: SoundPreset, visible: Bool) {
        var hidden = hiddenPresets
        if visible { hidden.remove(preset) } else { hidden.insert(preset) }
        hiddenPresets = hidden
    }
    var configuration: SoundConfiguration {
        get {
            var c = SoundConfiguration()
            c.enabled = enabled; c.preset = preset; c.volume = volume; c.includeRepeats = includeRepeats
            c.menuIconStyle = menuIconStyle; c.specialKeysEnabled = specialKeysEnabled
            c.includeShortcuts = includeShortcuts; c.keyMappings = keyMappings
            c.muteInLowPowerMode = muteInLowPowerMode; c.excludedBundleIDs = excludedBundleIDs
            return c.sanitized()
        }
        set {
            let c = newValue.sanitized()
            enabled = c.enabled; preset = c.preset; volume = c.volume; includeRepeats = c.includeRepeats
            menuIconStyle = c.menuIconStyle; specialKeysEnabled = c.specialKeysEnabled
            includeShortcuts = c.includeShortcuts; keyMappings = c.keyMappings
            muteInLowPowerMode = c.muteInLowPowerMode; excludedBundleIDs = c.excludedBundleIDs
        }
    }
    var activeProfileID: String? {
        get { defaults.string(forKey: "activeProfileID") }
        set { defaults.set(newValue, forKey: "activeProfileID") }
    }
    var userProfiles: [SavedProfile] {
        get {
            guard let data = defaults.data(forKey: "savedProfiles"),
                  let profiles = try? JSONDecoder().decode([SavedProfile].self, from: data) else { return [] }
            return profiles.filter { !$0.isBuiltin && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { var p = $0; p.configuration = p.configuration.sanitized(); return p }
        }
        set { if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: "savedProfiles") } }
    }
    static var builtins: [SavedProfile] {
        let specs: [(String, String, SoundPreset, Double, MenuIconStyle)] = [
            ("asmr", "ASMR", .nkCream, 0.42, .headphones),
            ("focus", "Focus", .topre, 0.25, .typingCursor),
            ("vintage", "Vintage", .ibmModelM, 0.45, .typewriter),
            ("playful", "Playful", .bubblePop, 0.35, .waveform)
        ]
        return specs.map { id, name, preset, volume, icon in
            var c = SoundConfiguration(); c.preset = preset; c.volume = volume; c.menuIconStyle = icon
            return SavedProfile(id: "builtin." + id, name: name, configuration: c)
        }
    }
    var profiles: [SavedProfile] { Self.builtins + userProfiles }
    @discardableResult func saveProfile(name: String) -> SavedProfile {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        let p = SavedProfile(id: UUID().uuidString, name: clean.isEmpty ? "My Profile" : clean,
                             configuration: configuration)
        var list = userProfiles; list.append(p); userProfiles = list; activeProfileID = p.id
        return p
    }
    func applyProfile(id: String) {
        guard let profile = profiles.first(where: { $0.id == id }) else { return }
        var c = profile.configuration
        // Playback enablement is a global switch, not a side effect of choosing a profile.
        c.enabled = enabled
        if !SoundPreset.availableCases.contains(c.preset) { c.preset = .mxBrown }
        configuration = c; activeProfileID = id
    }
    func removeProfile(id: String) {
        guard !id.hasPrefix("builtin.") else { return }
        userProfiles = userProfiles.filter { $0.id != id }
        if activeProfileID == id { activeProfileID = nil }
    }
}

enum SoundPreset: String, CaseIterable, Codable {
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
    case nkCream, boxNavy, topre, tealios, alpsBlue
    case mutedTypewriter, ribbonTypewriter, electricTypewriter, deskTypewriter
    case feltPiano, marimba, pluckedStrings, glassBells
    case waterDrops, woodBlocks, rubberBounce
    case arcadeBlips, terminalBeeps, radarPings, laserTicks

    static let designedCases: [SoundPreset] = [
        .mutedTypewriter, .ribbonTypewriter, .electricTypewriter, .deskTypewriter,
        .feltPiano, .marimba, .pluckedStrings, .glassBells, .waterDrops, .woodBlocks,
        .rubberBounce, .arcadeBlips, .terminalBeeps, .radarPings, .laserTicks
    ]
    var designedResources: [String] { (1...5).map { "designed-\(rawValue)-\($0)" } }

    // The two website recordings are optional personal assets, excluded from releases.
    static let availableCases: [SoundPreset] = allCases.filter { preset in
            let name: String
            switch preset {
            case .typingCom: name = "typing-com-04"
            case .typingClub: name = "typingclub-typewriter"
            case .nkCream: name = "kb-nk-cream-key1"
            case .boxNavy: name = "kb-box-navy-key1"
            case .topre: name = "kb-topre-key1"
            case .tealios: name = "kb-tealios-key1"
            case .alpsBlue: name = "kb-alps-blue-key1"
            default: return true
            }
            return Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds") != nil
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
        case .nkCream: return "Mechanical: NovelKeys Cream"
        case .boxNavy: return "Mechanical: Kailh Box Navy"
        case .topre: return "Mechanical: Topre"
        case .tealios: return "Mechanical: Turquoise Tealios"
        case .alpsBlue: return "Vintage: Blue Alps"
        case .mutedTypewriter: return "Typewriter: Felt Desk"
        case .ribbonTypewriter: return "Typewriter: Warm Ribbon"
        case .electricTypewriter: return "Typewriter: Electric Carriage"
        case .deskTypewriter: return "Typewriter: Metal Desk"
        case .feltPiano: return "Felt Piano"
        case .marimba: return "Wooden Marimba"
        case .pluckedStrings: return "Plucked Strings"
        case .glassBells: return "Glass Bells"
        case .waterDrops: return "Water Drops"
        case .woodBlocks: return "Wood Blocks"
        case .rubberBounce: return "Rubber Bounce"
        case .arcadeBlips: return "Arcade Blips"
        case .terminalBeeps: return "Terminal Beeps"
        case .radarPings: return "Radar Pings"
        case .laserTicks: return "Laser Ticks"
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
        case .nkCream: return "Creamy linear switches with a rounded bottom-out"
        case .boxNavy: return "A weighty click bar with a crisp snap"
        case .topre: return "Soft electro-capacitive thock for quiet sessions"
        case .tealios: return "Smooth, low-pitched linear switch recordings"
        case .alpsBlue: return "Distinctive vintage Alps clicks and resonance"
        case .mutedTypewriter: return "Designed · A soft, damped desk-machine tap"
        case .ribbonTypewriter: return "Designed · Warm strikes with a short ribbon rattle"
        case .electricTypewriter: return "Designed · A quick double-strike carriage mechanism"
        case .deskTypewriter: return "Designed · A bright metal-case clatter"
        case .feltPiano: return "Designed · Gentle, rounded piano-like notes"
        case .marimba: return "Designed · Warm wooden-bar percussion"
        case .pluckedStrings: return "Designed · Short, resonant string plucks"
        case .glassBells: return "Designed · Airy, inharmonic glass tones"
        case .waterDrops: return "Designed · Tiny, rising water-like plips"
        case .woodBlocks: return "Designed · Dry, hollow wooden knocks"
        case .rubberBounce: return "Designed · Springy descending boings"
        case .arcadeBlips: return "Designed · Bright square-wave arcade chirps"
        case .terminalBeeps: return "Designed · Short, clean terminal tones"
        case .radarPings: return "Designed · Rounded pings with a soft echo"
        case .laserTicks: return "Designed · Quick downward sci-fi sweeps"
        }
    }
}

enum SoundCategory: String, CaseIterable, Codable {
    case popular
    case keyboards
    case vintageKeyboards
    case typewriters
    case musical
    case fun
    case electronic

    var title: String {
        switch self {
        case .popular: return "Most Popular"
        case .keyboards: return "Mechanical Keyboards"
        case .vintageKeyboards: return "Vintage Keyboards"
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
        case .vintageKeyboards: return "desktopcomputer"
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
                .mxBlue,
                .holyPanda, .mxBrown, .mxBlack, .alpaca, .gateronBlackInk,
                .nkCream, .boxNavy, .topre, .tealios
            ]
        case .vintageKeyboards: return [.ibmModelM, .ibmModelF, .alpsBlue]
        case .typewriters:
            return [.classicTypewriter, .hardClack, .sharpStrike, .hermesTypewriter, .mutedTypewriter, .ribbonTypewriter, .electricTypewriter, .deskTypewriter]
        case .musical:
            return [.musicBox, .chimes, .drumKit, .feltPiano, .marimba, .pluckedStrings, .glassBells]
        case .fun:
            return [.bubblePop, .casinoChips, .duckQuacks, .waterDrops, .woodBlocks, .rubberBounce]
        case .electronic:
            return [.retroClicks, .electricSpark, .developerClick, .arcadeBlips, .terminalBeeps, .radarPings, .laserTicks]
        }
    }

    var menuSections: [(title: String, presets: [SoundPreset])] {
        guard self == .keyboards else { return [("", presets)] }
        return [
            ("Soft & thocky", [.alpaca, .gateronBlackInk, .mxBlack, .nkCream, .topre, .tealios]),
            ("Tactile & balanced", [.holyPanda, .mxBrown]),
            ("Crisp & clicky", [.mxBlue, .boxNavy])
        ]
    }

    static var settingsSections: [(SoundCategory, [SoundPreset])] { allCases.map { ($0, $0.presets) } }
}

enum MenuIconStyle: String, CaseIterable, Codable {
    case automatic
    case commandSound
    case typewriter
    case waveform
    case typingCursor
    case keyboard
    case bubbles
    case music
    case drum
    case headphones, sparkles, moon, leaf, piano, circle, coffee
    case speaker
    // Keep legacy cases decodable while offering only typing and audio symbols.
    static let selectableCases: [MenuIconStyle] = [.automatic, .typingCursor, .keyboard,
        .commandSound, .typewriter, .waveform, .headphones, .speaker, .music]

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
        case .headphones: return "Headphones"
        case .sparkles: return "Sparkles"
        case .moon: return "Moon"
        case .leaf: return "Leaf"
        case .piano: return "Piano Keys"
        case .circle: return "Simple Circle"
        case .coffee: return "Coffee Cup"
        case .speaker: return "Speaker"
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
        case .headphones: return "headphones"
        case .sparkles: return "sparkles"
        case .moon: return "moon.fill"
        case .leaf: return "leaf.fill"
        case .piano: return "pianokeys"
        case .circle: return "circle.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .speaker: return "speaker.wave.2.fill"
        }
    }
}
