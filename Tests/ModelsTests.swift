// ModelsTests.swift -- exercise routing and profile persistence without observing real keys.
// Created by LT Sean Egan, PhD 2026-11-04
import Foundation
import CoreGraphics

@main struct ModelTests {
    static func main() {
        var count = 0
        func check(_ value: Bool, _ name: String) {
            guard value else { fatalError("FAIL: " + name) }
            count += 1
        }
        var router = KeyEventRouter()
        var config = SoundConfiguration()
        func key(_ code: CGKeyCode, _ flags: UInt64 = 0, repeat repeated: Bool = false) -> RoutedKeySound? {
            router.route(keyCode: code, kind: .keyDown, flags: flags, isRepeat: repeated, configuration: config)
        }
        func modifier(_ code: CGKeyCode, _ flags: UInt64) -> RoutedKeySound? {
            router.route(keyCode: code, kind: .flagsChanged, flags: flags, isRepeat: false, configuration: config)
        }
        check(key(0)?.keyCode == 0, "letters preserve their virtual code")
        check(key(36)?.keyCode == 36 && key(49)?.keyCode == 49 && key(51)?.keyCode == 51,
              "return, space and backspace keep the profile's samples")
        check(key(48) != nil, "legacy Tab remains available")
        check(key(0, 0x100000) == nil && key(0, 0x40000) == nil, "shortcuts stay quiet")
        check(key(0, repeat: true) == nil, "held-key repeats default to quiet")
        config.includeRepeats = true
        check(key(0, repeat: true) != nil, "repeat opt-in")
        let defaultShift = modifier(56, 0x20002)
        check(defaultShift != nil && defaultShift!.volume < config.volume && defaultShift!.preset == config.preset,
              "default modifier uses a softer click from the selected pack")
        _ = modifier(56, 0)
        let rightShift = modifier(60, 0x20004)
        check(rightShift?.keyCode == defaultShift?.keyCode, "left and right Shift share their default sound")
        _ = modifier(60, 0)
        for (code, flags): (CGKeyCode, UInt64) in [(59,0x40001),(62,0x42000),(58,0x80020),
                                                   (61,0x80040),(55,0x100008),(54,0x100010),(63,0x800000)] {
            let sound = modifier(code, flags)
            check(sound != nil && sound!.volume < config.volume, "soft default modifier press \(code)")
            check(modifier(code, 0) == nil, "default modifier release remains silent \(code)")
        }
        config.specialKeysEnabled = true
        check(modifier(56, 0x20002) != nil, "left Shift press")
        check(modifier(56, 0x20002) == nil, "duplicate modifier suppressed")
        check(modifier(60, 0x20006) != nil, "right Shift while left is held")
        check(modifier(56, 0x20004) == nil, "left Shift release while right is held")
        check(modifier(60, 0) == nil, "right Shift release")
        check(modifier(56, 0x20002) != nil, "next left Shift press")
        _ = modifier(56, 0)
        for (code, flags): (CGKeyCode, UInt64) in [(59,0x40001),(62,0x42000),(58,0x80020),
                                                   (61,0x80040),(55,0x100008),(54,0x100010),(63,0x800000)] {
            check(modifier(code, flags) != nil, "optional modifier press \(code)")
            check(modifier(code, 0) == nil, "optional modifier release \(code)")
        }
        check(modifier(57, 0x10000) != nil && modifier(57, 0) != nil, "Caps Lock toggles both ways")
        check(modifier(57, 0) == nil, "duplicate Caps event")
        config.keyMappings[.shift] = KeyMapping(sound: .silent, volume: 1)
        check(modifier(56, 0x20002) == nil, "explicit modifier silence")
        _ = modifier(56, 0)
        config.keyMappings[.shift] = KeyMapping(sound: .typing, volume: 1)
        check(modifier(56, 0x20002)?.keyCode == 0, "modifier same-as-typing preserves its explicit override")
        _ = modifier(56, 0)
        config.keyMappings[.tab] = KeyMapping(sound: .preset(.duckQuacks), volume: 0.5)
        config.volume = 0.4
        check(key(48)?.preset == .duckQuacks && abs((key(48)?.volume ?? 0) - 0.2) < 0.0001,
              "per-key pack and gain")
        config.keyMappings[.space] = KeyMapping(sound: .typing, volume: 1)
        check(key(49)?.keyCode == 0, "same-as-typing override")
        config.keyMappings[.enter] = KeyMapping(sound: .silent, volume: 1)
        check(key(36) == nil && key(76) == nil, "both Return and keypad Enter use the override")
        config.includeShortcuts = true
        check(key(0, 0x100000) != nil, "shortcut opt-in")
        check(key(53) != nil && key(123) != nil && key(126) != nil, "Escape and arrows have default clicks")
        check(key(122) == nil, "unconfigured function/media keys stay quiet")
        config.enabled = false
        check(key(0) == nil, "disabled means no sound")
        config.enabled = true; config.volume = 0
        check(key(0) == nil, "zero gain never starts audio")
        config.volume = .nan
        check(key(0) == nil, "non-finite gain cannot reach audio")
        check(config.sanitized().volume.isFinite, "configuration sanitizes bad gain")
        let sections = SoundCategory.keyboards.menuSections
        let grouped = sections.flatMap(\.presets)
        check(sections.count == 3 && sections.allSatisfy { !$0.title.isEmpty }, "keyboard feel groups have headings")
        check(Set(grouped) == Set(SoundCategory.keyboards.presets) && grouped.count == Set(grouped).count,
              "keyboard feel groups cover every pack exactly once")
        check(!SoundCategory.keyboards.presets.contains(.ibmModelM) && SoundCategory.vintageKeyboards.presets.contains(.ibmModelM),
              "mechanical and vintage keyboards have separate menus")
        for category: SoundCategory in [.typewriters, .musical, .fun, .electronic] {
            check(category.presets.count >= 6, "expanded category \(category.title)")
        }
        check(SoundPreset.designedCases.count == 15 && Set(SoundPreset.designedCases.flatMap(\.designedResources)).count == 75,
              "original designs have distinct resource names")
        check(MenuIconStyle.selectableCases.contains(.typingCursor) && !MenuIconStyle.selectableCases.contains(.coffee),
              "icon choices communicate typing or sound")

        let suite = "TypingSoundsTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(0.31, forKey: "volume")
        defaults.set(SoundPreset.mxBlue.rawValue, forKey: "preset")
        let preferences = Preferences(defaults: defaults)
        check(preferences.volume == 0.31 && preferences.preset == .mxBlue, "legacy settings migrate")
        var saved = preferences.configuration
        saved.specialKeysEnabled = true; saved.includeShortcuts = true
        saved.keyMappings[.tab] = KeyMapping(sound: .preset(.bubblePop), volume: 0.3)
        saved.excludedBundleIDs = ["com.example.editor", "com.example.editor"]
        saved.muteInLowPowerMode = true
        preferences.configuration = saved
        let profile = preferences.saveProfile(name: "  My Quiet Desk  ")
        preferences.volume = 0.9
        preferences.keyMappings = [:]
        preferences.applyProfile(id: profile.id)
        check(preferences.volume == 0.31 && preferences.keyMappings[.tab]?.sound == .preset(.bubblePop),
              "profile restores key overrides and volume")
        check(preferences.userProfiles.count == 1 && profile.name == "My Quiet Desk", "profile name and identity")
        check(preferences.excludedBundleIDs.count == 1, "deduplicate exclusions")
        check(preferences.muteInLowPowerMode, "profile preserves behavior settings")
        check(Preferences(defaults: defaults).userProfiles == preferences.userProfiles, "relaunch persistence")
        preferences.enabled = false
        preferences.applyProfile(id: "builtin.focus")
        check(!preferences.enabled, "choosing a profile does not enable playback")
        preferences.removeProfile(id: "builtin.focus")
        check(preferences.profiles.contains { $0.id == "builtin.focus" }, "builtins cannot be deleted")
        preferences.removeProfile(id: profile.id)
        check(preferences.userProfiles.isEmpty, "delete user profile")
        defaults.set(Data("corrupt".utf8), forKey: "savedProfiles")
        defaults.set(Data("corrupt".utf8), forKey: "keyMappings")
        defaults.set(-100, forKey: "volume")
        check(preferences.userProfiles.isEmpty && preferences.keyMappings.isEmpty && preferences.volume == 0,
              "corrupt persisted values are contained")
        defaults.set(MenuIconStyle.leaf.rawValue, forKey: "menuIconStyle")
        check(preferences.menuIconStyle == .automatic, "legacy decorative icons decode to a relevant default")
        print("PASS: \(count) routing, boundary and profile checks")
    }
}
