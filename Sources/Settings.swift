// Settings.swift -- native preferences and a private, transient keyboard preview.
// Created by LT Sean Egan, PhD 2026-11-04
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

private final class SettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

private final class SettingsRootView: NSView {
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        NSColor.controlAccentColor.withAlphaComponent(0.035).setFill()
        bounds.fill()
    }
}

private final class SettingsCard: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 14, yRadius: 14)
        NSColor.controlBackgroundColor.setFill(); shape.fill()
        NSColor.separatorColor.withAlphaComponent(0.45).setStroke(); shape.stroke()
    }
}

private final class SoundLibraryRow: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        NSColor.controlAccentColor.withAlphaComponent(0.14).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 0), xRadius: 8, yRadius: 8).fill()
    }
}

private final class SoundLibraryItem: NSObject {
    let title: String
    let symbol: String
    let preset: SoundPreset?
    let children: [SoundLibraryItem]
    init(title: String, symbol: String, presets: [SoundPreset]) {
        self.title = title; self.symbol = symbol; preset = nil
        children = presets.filter { SoundPreset.availableCases.contains($0) }.map { SoundLibraryItem(preset: $0) }
    }
    init(preset: SoundPreset) {
        title = preset.title; symbol = "waveform"; self.preset = preset; children = []
    }
}

private final class SoundPreviewButton: NSButton {
    var representedPreset: SoundPreset?
}

final class KeyboardPreviewView: NSView {
    var onKey: (CGKeyCode, Bool, UInt64, KeyboardEventKind) -> Void = { _,_,_,_ in }
    private var lastKey = "Click to try your keyboard"
    private var activeKey: CGKeyCode?
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self); needsDisplay = true }
    override func keyDown(with event: NSEvent) {
        activeKey = event.keyCode
        lastKey = KeyGroup.group(for: event.keyCode)?.title ?? "Key click"
        onKey(event.keyCode, event.isARepeat, UInt64(event.modifierFlags.rawValue), .keyDown)
        needsDisplay = true
    }
    override func flagsChanged(with event: NSEvent) {
        activeKey = event.keyCode
        lastKey = KeyGroup.group(for: event.keyCode)?.title ?? "Modifier"
        onKey(event.keyCode, false, UInt64(event.modifierFlags.rawValue), .flagsChanged)
        needsDisplay = true
    }
    override func resignFirstResponder() -> Bool { lastKey = "Click to try your keyboard"; activeKey = nil; needsDisplay = true; return true }
    override func draw(_ dirtyRect: NSRect) {
        let rows: [[(String, CGKeyCode, CGFloat)]] = [
            [("Q",12,1),("W",13,1),("E",14,1),("R",15,1),("T",17,1),("Y",16,1),("U",32,1),("I",34,1),("O",31,1),("P",35,1),("delete",51,1.8)],
            [("A",0,1),("S",1,1),("D",2,1),("F",3,1),("G",5,1),("H",4,1),("J",38,1),("K",40,1),("L",37,1),("return",36,2.1)],
            [("shift",56,1.8),("Z",6,1),("X",7,1),("C",8,1),("V",9,1),("B",11,1),("N",45,1),("M",46,1),("space",49,3)]
        ]
        let unit: CGFloat = min(45, (bounds.width - 24) / 13.8)
        for (index, keys) in rows.enumerated() {
            let total = keys.reduce(CGFloat(0)) { $0 + $1.2 * unit + 5 } - 5
            var x = (bounds.width - total) / 2
            for (name, code, width) in keys {
                let rect = NSRect(x: x, y: bounds.height - 32 - CGFloat(index) * 35, width: width * unit, height: 29)
                let selected = activeKey == code && window?.firstResponder === self
                let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
                (selected ? NSColor.controlAccentColor : NSColor.quaternaryLabelColor.withAlphaComponent(0.13)).setFill(); path.fill()
                NSColor.separatorColor.withAlphaComponent(0.6).setStroke(); path.stroke()
                let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: name.count > 1 ? 10 : 12, weight: .medium), .foregroundColor: selected ? NSColor.white : NSColor.secondaryLabelColor]
                let size = name.size(withAttributes: attributes)
                name.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: attributes)
                x += width * unit + 5
            }
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.secondaryLabelColor]
        let size = lastKey.size(withAttributes: attributes)
        lastKey.draw(at: NSPoint(x: (bounds.width - size.width)/2, y: 0), withAttributes: attributes)
    }
}

final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate, NSTabViewDelegate {
    let tabView = NSTabView()
    private let preferences: Preferences
    private let onChange: () -> Void
    private let onPreview: (SoundPreset) -> Void
    private let onPermission: () -> Void
    private let onLogin: () -> Void
    private let loginEnabled: () -> Bool
    private let statusText: () -> String
    private let onTestKey: (CGKeyCode, Bool, UInt64, KeyboardEventKind) -> Void
    private let iconImage: (MenuIconStyle) -> NSImage?
    private let soundPopup = NSPopUpButton()
    private let soundSearch = NSSearchField()
    private let soundTable = NSOutlineView()
    private let selectedSound = NSTextField(wrappingLabelWithString: "")
    private let libraryCount = NSTextField(labelWithString: "")
    private var filteredSounds = SoundPreset.availableCases
    private var updatingLibrary = false
    private let libraryRoots: [SoundLibraryItem] = [
        SoundLibraryItem(title: "Mechanical keyboards", symbol: "keyboard", presets: [.mxBlue, .holyPanda, .mxBrown, .mxBlack, .alpaca, .gateronBlackInk, .nkCream, .boxNavy, .topre, .tealios]),
        SoundLibraryItem(title: "Vintage keyboards", symbol: "desktopcomputer", presets: [.ibmModelM, .ibmModelF, .alpsBlue]),
        SoundLibraryItem(title: "Typewriters", symbol: "textformat", presets: [.classicTypewriter, .hardClack, .sharpStrike, .hermesTypewriter]),
        SoundLibraryItem(title: "Musical", symbol: "music.note", presets: [.musicBox, .chimes, .drumKit]),
        SoundLibraryItem(title: "Playful", symbol: "sparkles", presets: [.bubblePop, .casinoChips, .duckQuacks]),
        SoundLibraryItem(title: "Electronic & retro", symbol: "bolt", presets: [.developerClick, .retroClicks, .electricSpark]),
        SoundLibraryItem(title: "Online classics", symbol: "globe", presets: [.typingCom, .typingClub])
    ].filter { !$0.children.isEmpty }
    private var visibleRoots: [SoundLibraryItem] = []
    private var expandedCategories: Set<String> = []
    private var libraryQuery = ""
    private var displayedPreset: SoundPreset?
    private let profilePopup = NSPopUpButton()
    private let soundDescription = NSTextField(wrappingLabelWithString: "")
    private let status = NSTextField(labelWithString: "")
    private let volume = NSSlider(value: 45, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let volumeText = NSTextField(labelWithString: "45%")
    private let enabled = NSButton(checkboxWithTitle: "Enable typing sounds", target: nil, action: nil)
    private let customKeys = NSButton(checkboxWithTitle: "Customize special-key sounds", target: nil, action: nil)
    private let repeats = NSButton(checkboxWithTitle: "Play sounds when a key is held down", target: nil, action: nil)
    private let shortcuts = NSButton(checkboxWithTitle: "Play letter sounds during Command / Control shortcuts", target: nil, action: nil)
    private let lowPower = NSButton(checkboxWithTitle: "Pause automatically in Low Power Mode", target: nil, action: nil)
    private let login = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let permission = NSTextField(wrappingLabelWithString: "")
    private let iconPopup = NSPopUpButton()
    private let iconPreview = NSImageView()
    private let appTable = NSTableView()
    private let keyboardPreview = KeyboardPreviewView()
    private var keyPopups: [KeyGroup: NSPopUpButton] = [:]
    private var keyVolumes: [KeyGroup: NSSlider] = [:]
    private var keyVolumeText: [KeyGroup: NSTextField] = [:]
    private var deleteProfileButton: NSButton!
    private var navigationButtons: [NSButton] = []
    private var choices: [(String, SoundSelection)] {
        [("Profile default", .default), ("Silent", .silent), ("Same as typing", .typing)]
        + SoundPreset.availableCases.map { ($0.title, .preset($0)) }
    }
    var isTesting: Bool { window?.isKeyWindow == true && window?.firstResponder === keyboardPreview }

    init(preferences: Preferences = .shared, onChange: @escaping () -> Void = {},
         onPreview: @escaping (SoundPreset) -> Void = { _ in }, onPermission: @escaping () -> Void = {},
         onLogin: @escaping () -> Void = {}, loginEnabled: @escaping () -> Bool = { false },
         statusText: @escaping () -> String = { "" },
         onTestKey: @escaping (CGKeyCode, Bool, UInt64, KeyboardEventKind) -> Void = { _,_,_,_ in },
         iconImage: @escaping (MenuIconStyle) -> NSImage? = { _ in nil }) {
        self.preferences = preferences; self.onChange = onChange; self.onPreview = onPreview
        self.onPermission = onPermission; self.onLogin = onLogin; self.loginEnabled = loginEnabled
        self.statusText = statusText; self.onTestKey = onTestKey
        self.iconImage = iconImage
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 800),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Typing Sounds Settings"
        window.contentView = SettingsRootView(frame: NSRect(x: 0, y: 0, width: 960, height: 800))
        window.minSize = NSSize(width: 920, height: 720)
        window.isReleasedWhenClosed = false
        if !CommandLine.arguments.contains("--render-settings") && !CommandLine.arguments.contains("--settings-self-test") {
            window.setFrameAutosaveName("TypingSoundsSettingsV2")
        }
        super.init(window: window)
        build()
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func label(_ text: String, secondary: Bool = false) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: secondary ? 12 : 13)
        label.textColor = secondary ? .secondaryLabelColor : .labelColor
        label.preferredMaxLayoutWidth = 640
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }
    private func section(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        return label
    }
    private func row(_ views: [NSView]) -> NSStackView {
        let row = NSStackView(views: views); row.spacing = 12; row.alignment = .centerY
        return row
    }
    private func button(_ title: String, _ action: Selector) -> NSButton {
        NSButton(title: title, target: self, action: action)
    }
    private func card(_ title: String, subtitle: String? = nil, views: [NSView]) -> NSView {
        var children: [NSView] = [section(title)]
        if let subtitle { children.append(label(subtitle, secondary: true)) }
        children += views
        let stack = NSStackView(views: children)
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        let card = SettingsCard(); card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])
        for view in children where view is NSTextField {
            view.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor).isActive = true
        }
        return card
    }
    private func pane(_ name: String, views: [NSView]) {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let document = SettingsDocumentView(); document.translatesAutoresizingMaskIntoConstraints = false
        for view in views where view is NSTextField {
            view.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor).isActive = true
        }
        for view in views where view is SettingsCard || view is NSStackView {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        document.addSubview(stack)
        let scroll = NSScrollView(); scroll.documentView = document
        scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.drawsBackground = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor)
        ])
        let item = NSTabViewItem(identifier: name); item.label = name; item.view = scroll
        tabView.addTabViewItem(item)
    }
    private func build() {
        guard let content = window?.contentView else { return }
        let title = NSTextField(labelWithString: "Typing Sounds")
        title.font = .systemFont(ofSize: 26, weight: .bold)
        status.textColor = .secondaryLabelColor; status.font = .systemFont(ofSize: 12)
        let heading = NSStackView(views: [title, status]); heading.orientation = .vertical
        heading.alignment = .leading; heading.spacing = 5
        let mark = NSImageView(image: NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: nil)!)
        mark.contentTintColor = .controlAccentColor
        mark.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        mark.widthAnchor.constraint(equalToConstant: 48).isActive = true
        let header = row([mark, heading])
        header.translatesAutoresizingMaskIntoConstraints = false
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.tabViewType = .noTabsNoBorder
        tabView.delegate = self
        let navigation = NSStackView()
        navigation.spacing = 8; navigation.translatesAutoresizingMaskIntoConstraints = false
        for (index, title) in ["Sounds & Profiles", "Key Sounds", "Behavior", "Appearance & About"].enumerated() {
            let control = button(title, #selector(selectPane(_:)))
            control.image = NSImage(systemSymbolName: ["waveform", "keyboard", "slider.horizontal.3", "paintbrush"][index], accessibilityDescription: nil)
            control.imagePosition = .imageLeading; control.bezelStyle = .recessed
            control.controlSize = .large
            control.tag = index; control.setButtonType(.pushOnPushOff)
            navigation.addArrangedSubview(control); navigationButtons.append(control)
        }
        content.addSubview(header); content.addSubview(navigation); content.addSubview(tabView)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 26),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -26),
            navigation.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 18),
            navigation.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 26),
            tabView.topAnchor.constraint(equalTo: navigation.bottomAnchor, constant: 16),
            tabView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            tabView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            tabView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18)
        ])

        for control in [enabled, customKeys, repeats, shortcuts, lowPower] {
            control.target = self; control.action = #selector(changeOptions)
        }
        login.target = self; login.action = #selector(changeLogin)
        soundPopup.addItems(withTitles: SoundPreset.availableCases.map(\.title))
        soundPopup.target = self; soundPopup.action = #selector(changeSound)
        soundPopup.widthAnchor.constraint(equalToConstant: 400).isActive = true
        profilePopup.target = self; profilePopup.action = #selector(changeProfile)
        profilePopup.widthAnchor.constraint(equalToConstant: 260).isActive = true
        deleteProfileButton = button("Delete", #selector(deleteProfile))
        volume.target = self; volume.action = #selector(changeVolume); volume.isContinuous = true
        volume.setAccessibilityLabel("Typing sound volume")
        volume.widthAnchor.constraint(equalToConstant: 220).isActive = true
        keyboardPreview.onKey = onTestKey
        keyboardPreview.translatesAutoresizingMaskIntoConstraints = false
        keyboardPreview.heightAnchor.constraint(equalToConstant: 125).isActive = true
        keyboardPreview.widthAnchor.constraint(equalToConstant: 780).isActive = true
        keyboardPreview.setAccessibilityLabel("Keyboard sound preview. No typed text is saved.")
        soundSearch.placeholderString = "Filter sounds (optional)…"
        soundSearch.target = self; soundSearch.action = #selector(searchSounds)
        soundSearch.sendsSearchStringImmediately = true
        soundSearch.widthAnchor.constraint(equalToConstant: 390).isActive = true
        soundSearch.setAccessibilityLabel("Search sound library")
        soundTable.identifier = NSUserInterfaceItemIdentifier("soundLibrary")
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("sound")); column.width = 382
        soundTable.addTableColumn(column); soundTable.outlineTableColumn = column; soundTable.headerView = nil
        soundTable.indentationPerLevel = 14
        soundTable.rowHeight = 57; soundTable.intercellSpacing = NSSize(width: 0, height: 2)
        soundTable.style = .plain; soundTable.backgroundColor = .clear
        soundTable.delegate = self; soundTable.dataSource = self
        soundTable.setAccessibilityLabel("Sound library")
        let libraryScroll = NSScrollView(); libraryScroll.documentView = soundTable
        libraryScroll.hasVerticalScroller = true; libraryScroll.drawsBackground = false
        libraryScroll.heightAnchor.constraint(equalToConstant: 230).isActive = true
        libraryScroll.widthAnchor.constraint(equalToConstant: 390).isActive = true
        libraryCount.font = .systemFont(ofSize: 11); libraryCount.textColor = .secondaryLabelColor
        let library = card("Sound library", subtitle: "Explore a category. Find your favorite feel.", views: [soundSearch, libraryScroll, libraryCount])
        selectedSound.font = .systemFont(ofSize: 19, weight: .semibold)
        selectedSound.preferredMaxLayoutWidth = 310
        soundDescription.font = .systemFont(ofSize: 12); soundDescription.textColor = .secondaryLabelColor
        soundDescription.preferredMaxLayoutWidth = 310
        let current = card("Your sound", views: [selectedSound, soundDescription,
            row([button("▶  Preview", #selector(previewSound)), enabled]),
            row([label("Volume", secondary: true), volume, volumeText])])
        let profiles = card("Make it yours", views: [profilePopup,
            row([button("Save As…", #selector(saveProfile)), deleteProfileButton]),
            label("Save your sound, key mix, icon and quiet rules together.", secondary: true)])
        let side = NSStackView(views: [current, profiles]); side.orientation = .vertical
        side.alignment = .leading; side.spacing = 16
        for view in [current, profiles] { view.widthAnchor.constraint(equalTo: side.widthAnchor).isActive = true }
        let browser = row([library, side]); browser.alignment = .top; browser.spacing = 18
        library.widthAnchor.constraint(equalToConstant: 426).isActive = true
        side.widthAnchor.constraint(equalTo: browser.widthAnchor, constant: -444).isActive = true
        pane("Sounds & Profiles", views: [browser,
            card("The typing room", views: [keyboardPreview,
            label("Private by design · No text saved · Works here before Input Monitoring is enabled", secondary: true)])])

        var keyViews: [NSView] = [customKeys, label("Keep the pack's defaults, mute individual keys, or mix in another sound. Extra modifier keys are quiet until customization is enabled.", secondary: true)]
        let keyHeading = section("Key"), soundHeading = section("Sound"), levelHeading = section("Relative volume")
        keyHeading.widthAnchor.constraint(equalToConstant: 118).isActive = true
        soundHeading.widthAnchor.constraint(equalToConstant: 330).isActive = true
        keyViews.append(row([keyHeading, soundHeading, levelHeading]))
        for (index, group) in KeyGroup.allCases.enumerated() {
            let name = label(group.title)
            name.widthAnchor.constraint(equalToConstant: 118).isActive = true
            let popup = NSPopUpButton(); popup.addItems(withTitles: choices.map(\.0))
            popup.tag = index; popup.target = self; popup.action = #selector(changeKey(_:))
            popup.widthAnchor.constraint(equalToConstant: 330).isActive = true
            popup.setAccessibilityLabel(group.title + " sound")
            let slider = NSSlider(value: 100, minValue: 0, maxValue: 100, target: self, action: #selector(changeKeyVolume(_:)))
            slider.tag = index; slider.isContinuous = true
            slider.widthAnchor.constraint(equalToConstant: 125).isActive = true
            slider.setAccessibilityLabel(group.title + " relative volume")
            let percentage = label("100%", secondary: true)
            percentage.widthAnchor.constraint(equalToConstant: 40).isActive = true
            keyPopups[group] = popup; keyVolumes[group] = slider
            keyVolumeText[group] = percentage
            keyViews.append(row([name, popup, slider, percentage]))
        }
        keyViews.append(button("Reset Key Sounds to Defaults", #selector(resetKeys)))
        pane("Key Sounds", views: [card("Every key, your way", subtitle: "A softer space bar. A satisfying return. Build your own mix.", views: keyViews)])

        appTable.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app")))
        appTable.tableColumns[0].title = "Quiet in these apps"
        appTable.tableColumns[0].width = 630
        appTable.headerView = nil; appTable.rowHeight = 28
        appTable.delegate = self; appTable.dataSource = self
        let appScroll = NSScrollView(); appScroll.documentView = appTable
        appScroll.hasVerticalScroller = true; appScroll.borderType = .bezelBorder
        appScroll.heightAnchor.constraint(equalToConstant: 135).isActive = true
        appScroll.widthAnchor.constraint(equalToConstant: 640).isActive = true
        permission.textColor = .secondaryLabelColor
        pane("Behavior", views: [
            card("A rhythm that suits you", views: [repeats, shortcuts, lowPower,
            label("Shortcut letters stay quiet by default. Modifier-key clicks are controlled separately in Key Sounds. Audio also pauses while the Mac sleeps or another user session is active.", secondary: true)]),
            card("A little quiet, where you need it", subtitle: "Sounds pause automatically when one of these apps is active.", views: [appScroll,
            row([button("Add App…", #selector(addApp)), button("Remove Selected", #selector(removeApp))])]),
            card("Ready when you are", views: [login, permission,
            button("Input Monitoring Settings…", #selector(permissionSettings)),
            label("Only Input Monitoring is needed for system-wide sounds. No Accessibility, microphone, screen-recording or Full Disk Access permission is requested.", secondary: true)])
        ])

        iconPopup.addItems(withTitles: MenuIconStyle.allCases.map(\.title))
        iconPopup.target = self; iconPopup.action = #selector(changeIcon)
        iconPopup.widthAnchor.constraint(equalToConstant: 300).isActive = true
        iconPreview.frame = NSRect(x: 0, y: 0, width: 32, height: 32)
        iconPreview.widthAnchor.constraint(equalToConstant: 32).isActive = true
        iconPreview.heightAnchor.constraint(equalToConstant: 32).isActive = true
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        var aboutViews: [NSView] = [section("Menu-bar appearance"), row([iconPopup, iconPreview]),
            label("Icons follow the menu bar's light or dark appearance. The app keeps running in the menu bar when this window closes.", secondary: true),
            section("Typing Sounds " + version), label("Created by Sean Egan"),
            label("Keyboard sounds for focus, play and the pleasure of a good key click."),
            row([button("sean.theinformed.org", #selector(openWebsite)), button("Source & Credits", #selector(openSource))])]
        #if !APP_STORE
        if let value = Bundle.main.object(forInfoDictionaryKey: "BuyMeACoffeeURL") as? String,
           let url = URL(string: value), url.scheme == "https", url.host == "buymeacoffee.com" || url.host == "www.buymeacoffee.com" {
            aboutViews.append(button("Buy Me a Coffee", #selector(openCoffee)))
        }
        #endif
        aboutViews += [section("Privacy & power"),
            label("No accounts, analytics or keystroke logs. Key codes choose a sound; typed content is never collected. There are no background network requests. Links you choose to open use your browser.", secondary: true),
            label("Audio goes idle when you stop typing. Pausing sounds also stops keyboard monitoring. Quiet-app and power rules run without background polling.", secondary: true)]
        pane("Appearance & About", views: [card("A small app, with personality", views: Array(aboutViews.prefix(3))),
            card("Made for the joy of typing", views: Array(aboutViews.dropFirst(3)))])
        tabView.selectTabViewItem(at: 0)
    }

    @objc private func selectPane(_ sender: NSButton) { tabView.selectTabViewItem(at: sender.tag) }
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        for button in navigationButtons {
            button.state = button.tag == tabView.indexOfTabViewItem(tabViewItem!) ? .on : .off
        }
    }

    func show() {
        refresh()
        if window?.isVisible != true { window?.center() }
        showWindow(nil); window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func refresh() {
        let c = preferences.configuration
        status.stringValue = statusText().isEmpty ? (c.enabled ? "Sounds enabled" : "Sounds paused") : statusText()
        enabled.state = c.enabled ? .on : .off
        soundPopup.selectItem(withTitle: c.preset.title); soundDescription.stringValue = c.preset.detail
        selectedSound.stringValue = c.preset.title
        reloadLibrary()
        volume.doubleValue = c.volume * 100; volumeText.stringValue = "\(Int(c.volume * 100))%"
        customKeys.state = c.specialKeysEnabled ? .on : .off
        repeats.state = c.includeRepeats ? .on : .off; shortcuts.state = c.includeShortcuts ? .on : .off
        lowPower.state = c.muteInLowPowerMode ? .on : .off; login.state = loginEnabled() ? .on : .off
        permission.stringValue = CGPreflightListenEventAccess() ? "Input Monitoring is allowed." : "Allow Input Monitoring to hear sounds in other apps. The preview works here without it."
        profilePopup.removeAllItems(); profilePopup.addItem(withTitle: "Current Settings")
        let profiles = preferences.profiles
        for profile in profiles {
            profilePopup.addItem(withTitle: profile.name)
            profilePopup.lastItem?.representedObject = profile.id
        }
        if let id = preferences.activeProfileID,
           let index = profiles.firstIndex(where: { $0.id == id }) {
            profilePopup.selectItem(at: index + 1)
            var saved = profiles[index].configuration
            saved.enabled = c.enabled
            if saved != c { profilePopup.selectedItem?.title += " (modified)" }
        }
        deleteProfileButton.isEnabled = preferences.activeProfileID.map { !$0.hasPrefix("builtin.") } ?? false
        for group in KeyGroup.allCases {
            let mapping = c.keyMappings[group] ?? KeyMapping()
            keyPopups[group]?.selectItem(at: choices.firstIndex(where: { $0.1 == mapping.sound }) ?? 0)
            keyPopups[group]?.isEnabled = c.specialKeysEnabled
            keyVolumes[group]?.doubleValue = mapping.volume * 100
            keyVolumes[group]?.isEnabled = c.specialKeysEnabled
            keyVolumeText[group]?.stringValue = "\(Int(mapping.volume * 100))%"
        }
        iconPopup.selectItem(withTitle: c.menuIconStyle.title)
        iconPreview.image = iconImage(c.menuIconStyle)
            ?? NSImage(systemSymbolName: c.menuIconStyle.symbolName ?? "keyboard", accessibilityDescription: c.menuIconStyle.title)
        appTable.reloadData()
    }
    private func changed() { onChange(); refresh() }
    @objc private func changeOptions() {
        var c = preferences.configuration
        c.enabled = enabled.state == .on; c.specialKeysEnabled = customKeys.state == .on
        c.includeRepeats = repeats.state == .on; c.includeShortcuts = shortcuts.state == .on
        c.muteInLowPowerMode = lowPower.state == .on
        preferences.configuration = c; changed()
    }
    @objc private func changeSound() {
        guard let index = soundPopup.selectedItem.map({ soundPopup.index(of: $0) }),
              SoundPreset.availableCases.indices.contains(index) else { return }
        preferences.preset = SoundPreset.availableCases[index]; changed()
    }
    @objc private func previewSound() { onPreview(preferences.preset) }
    @objc private func changeVolume() { preferences.volume = volume.doubleValue / 100; changed() }
    @objc private func changeKey(_ sender: NSPopUpButton) {
        let group = KeyGroup.allCases[sender.tag]
        var mappings = preferences.keyMappings
        var mapping = mappings[group] ?? KeyMapping()
        mapping.sound = choices[sender.indexOfSelectedItem].1; mappings[group] = mapping
        preferences.keyMappings = mappings; changed()
    }
    @objc private func changeKeyVolume(_ sender: NSSlider) {
        let group = KeyGroup.allCases[sender.tag]
        var mappings = preferences.keyMappings; var mapping = mappings[group] ?? KeyMapping()
        mapping.volume = sender.doubleValue / 100; mappings[group] = mapping
        preferences.keyMappings = mappings; changed()
    }
    @objc private func resetKeys() { preferences.keyMappings = [:]; changed() }
    @objc private func changeIcon() {
        preferences.menuIconStyle = MenuIconStyle.allCases[iconPopup.indexOfSelectedItem]; changed()
    }
    @objc private func changeProfile() {
        guard let id = profilePopup.selectedItem?.representedObject as? String else {
            preferences.activeProfileID = nil; changed(); return
        }
        preferences.applyProfile(id: id); changed()
    }
    @objc private func saveProfile() {
        guard let window else { return }
        let alert = NSAlert(); alert.messageText = "Save a Sound Profile"
        alert.informativeText = "Give this combination of sounds and settings a name."
        let name = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        name.placeholderString = "My Profile"; alert.accessoryView = name
        alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            self.preferences.saveProfile(name: name.stringValue); self.changed()
        }
    }
    @objc private func deleteProfile() {
        guard let id = preferences.activeProfileID, !id.hasPrefix("builtin.") else { return }
        preferences.removeProfile(id: id); changed()
    }
    @objc private func changeLogin() { onLogin(); refresh() }
    @objc private func permissionSettings() { onPermission(); refresh() }
    @objc private func addApp() {
        guard let window else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.beginSheetModal(for: window) { [weak self] result in
            guard result == .OK, let self else { return }
            var ids = self.preferences.excludedBundleIDs
            for url in panel.urls { if let id = Bundle(url: url)?.bundleIdentifier { ids.append(id) } }
            self.preferences.excludedBundleIDs = ids; self.changed()
        }
    }
    @objc private func removeApp() {
        let index = appTable.selectedRow
        var ids = preferences.excludedBundleIDs
        guard ids.indices.contains(index) else { return }
        ids.remove(at: index); preferences.excludedBundleIDs = ids; changed()
    }
    @objc private func searchSounds() { reloadLibrary() }
    private func children(of category: SoundLibraryItem) -> [SoundLibraryItem] {
        if libraryQuery.isEmpty || category.title.localizedCaseInsensitiveContains(libraryQuery) { return category.children }
        return category.children.filter {
            ($0.title + " " + ($0.preset?.detail ?? "")).localizedCaseInsensitiveContains(libraryQuery)
        }
    }
    private func reloadLibrary() {
        if libraryQuery.isEmpty && soundTable.numberOfRows > 0 {
            expandedCategories = Set(libraryRoots.filter { soundTable.isItemExpanded($0) }.map(\.title))
        }
        libraryQuery = soundSearch.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        visibleRoots = libraryRoots.filter { !children(of: $0).isEmpty }
        filteredSounds = visibleRoots.flatMap { children(of: $0).compactMap(\.preset) }
        let selectionChanged = displayedPreset != preferences.preset
        if selectionChanged, displayedPreset != nil, libraryQuery.isEmpty,
           let parent = libraryRoots.first(where: { $0.children.contains { $0.preset == preferences.preset } }) {
            expandedCategories.insert(parent.title)
        }
        updatingLibrary = true
        soundTable.reloadData()
        soundTable.collapseItem(nil, collapseChildren: true)
        for root in visibleRoots where !libraryQuery.isEmpty || expandedCategories.contains(root.title) {
            soundTable.expandItem(root)
        }
        if let item = visibleRoots.flatMap({ children(of: $0) }).first(where: { $0.preset == preferences.preset }),
           soundTable.row(forItem: item) >= 0 {
            let index = soundTable.row(forItem: item)
            soundTable.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            if selectionChanged { soundTable.scrollRowToVisible(index) }
        } else { soundTable.deselectAll(nil) }
        displayedPreset = preferences.preset
        updatingLibrary = false
        libraryCount.stringValue = filteredSounds.isEmpty ? "No matches. Try a category or another word." : "\(filteredSounds.count) sounds · Browse ▸ · Preview ▶"
    }
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard notification.object as? NSTableView === soundTable, !updatingLibrary,
              let item = soundTable.item(atRow: soundTable.selectedRow) as? SoundLibraryItem,
              let preset = item.preset else { return }
        preferences.preset = preset; changed()
    }
    @objc private func previewLibrarySound(_ sender: NSButton) {
        guard let preset = (sender as? SoundPreviewButton)?.representedPreset else { return }
        onPreview(preset)
    }
    func numberOfRows(in tableView: NSTableView) -> Int {
        preferences.excludedBundleIDs.count
    }
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? SoundLibraryItem).map { children(of: $0).count } ?? visibleRoots.count
    }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let item = item as? SoundLibraryItem { return children(of: item)[index] }
        return visibleRoots[index]
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? SoundLibraryItem)?.preset == nil
    }
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        (item as? SoundLibraryItem)?.preset != nil
    }
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        (item as? SoundLibraryItem)?.preset == nil ? 28 : 57
    }
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        SoundLibraryRow()
    }
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let item = item as? SoundLibraryItem else { return nil }
        guard let preset = item.preset else {
            let icon = NSImageView(image: NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil)!)
            icon.contentTintColor = .controlAccentColor
            icon.widthAnchor.constraint(equalToConstant: 18).isActive = true
            let name = NSTextField(labelWithString: item.title)
            name.font = .systemFont(ofSize: 12, weight: .semibold)
            let count = label("\(children(of: item).count)", secondary: true)
            let cell = NSView()
            for view in [icon, name, count] { cell.addSubview(view); view.translatesAutoresizingMaskIntoConstraints = false }
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                name.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
                name.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                name.trailingAnchor.constraint(lessThanOrEqualTo: count.leadingAnchor, constant: -8),
                count.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
                count.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell
        }
        return soundCell(preset)
    }
    private func soundCell(_ preset: SoundPreset) -> NSView {
            let shortTitle = preset.title.range(of: ": ").map { String(preset.title[$0.upperBound...]) } ?? preset.title
            let name = NSTextField(labelWithString: shortTitle)
            name.font = .systemFont(ofSize: 13, weight: .semibold)
            let detail = NSTextField(labelWithString: preset.detail)
            detail.font = .systemFont(ofSize: 11); detail.textColor = .secondaryLabelColor
            detail.lineBreakMode = .byTruncatingTail
            let text = NSStackView(views: [name, detail]); text.orientation = .vertical
            text.alignment = .leading; text.spacing = 3
            let preview = SoundPreviewButton(title: "▶", target: self, action: #selector(previewLibrarySound(_:)))
            preview.representedPreset = preset
            preview.bezelStyle = .recessed
            preview.setAccessibilityLabel("Preview " + preset.title)
            let cell = NSView(); cell.addSubview(text); cell.addSubview(preview)
            text.translatesAutoresizingMaskIntoConstraints = false; preview.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                text.trailingAnchor.constraint(equalTo: preview.leadingAnchor, constant: -8),
                preview.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                preview.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                preview.widthAnchor.constraint(equalToConstant: 32)
            ])
            return cell
    }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let ids = preferences.excludedBundleIDs
        guard ids.indices.contains(row) else { return nil }
        let id = ids[row]
        let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)?.deletingPathExtension().lastPathComponent ?? id
        return label(name + "  ·  " + id)
    }
    @objc private func openWebsite() { NSWorkspace.shared.open(URL(string: "https://sean.theinformed.org")!) }
    @objc private func openSource() { NSWorkspace.shared.open(URL(string: "https://github.com/theinformed/typing-sounds")!) }
    @objc private func openCoffee() {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "BuyMeACoffeeURL") as? String,
              let url = URL(string: value), url.scheme == "https",
              url.host == "buymeacoffee.com" || url.host == "www.buymeacoffee.com" else { return }
        NSWorkspace.shared.open(url)
    }
}
