import SwiftUI
import UIKit

/// Types into the Mac. Two invisible views take turns holding the keyboard: one that asks for the
/// on-screen keyboard, with a row of the Mac's own keys above it, and one that doesn't, so that a
/// hardware keyboard works whether or not that is open.
struct KeyboardCatcher: UIViewRepresentable {
    @Binding var active: Bool

    func makeUIView(context: Context) -> Holder { Holder() }

    func updateUIView(_ view: Holder, context: Context) {
        view.typer.onHide = { active = false }
        view.typing = active
        DispatchQueue.main.async { view.takeKeyboard() }
    }

    final class Holder: UIView {
        let listener = KeyListener()
        let typer = CatcherView()
        var typing = false
        private var hiding: NSObjectProtocol?

        override init(frame: CGRect) {
            super.init(frame: frame)
            addSubview(listener)
            addSubview(typer)
            hiding = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification,
                                                            object: nil, queue: .main) { [weak self] _ in
                self?.keyboardHid()
            }
        }

        required init?(coder: NSCoder) { fatalError("made in code") }

        deinit {
            if let hiding { NotificationCenter.default.removeObserver(hiding) }
        }

        /// iPadOS's own hide-keyboard key closes the keyboard without asking the app, which then went on
        /// keeping the Mac small, with room for a keyboard that was gone. Stop typing as the row's button does.
        /// A sheet taking the keyboard isn't that: it is handed back when the sheet closes.
        private func keyboardHid() {
            guard typing, let window, window.rootViewController?.presentedViewController == nil else { return }
            typer.onHide()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            takeKeyboard()
        }

        /// Called often, which also takes the keyboard back after a sheet has had it.
        func takeKeyboard() {
            guard let window, window.rootViewController?.presentedViewController == nil else { return }
            let holder: UIView = typing ? typer : listener
            if !holder.isFirstResponder { holder.becomeFirstResponder() }
        }
    }

    /// Whichever view holds the keyboard hears a hardware keyboard's keys here.
    class KeyListener: UIView {
        override var canBecomeFirstResponder: Bool { true }
        /// Three fingers belong to the session (they show its controls), not to iPadOS's undo/copy/paste bar.
        override var editingInteractionConfiguration: UIEditingInteractionConfiguration { .none }

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            let rest = HardwareKeys.send(presses, down: true)
            if !rest.isEmpty { super.pressesBegan(rest, with: event) }
        }

        override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            let rest = HardwareKeys.send(presses, down: false)
            if !rest.isEmpty { super.pressesEnded(rest, with: event) }
        }

        override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            let rest = HardwareKeys.send(presses, down: false)
            if !rest.isEmpty { super.pressesCancelled(rest, with: event) }
        }
    }

    /// Holds the on-screen keyboard.
    ///
    /// UIKeyInput is enough for a US keyboard, but a Chinese (or any IME) keyboard never
    /// becomes active on a responder that implements only UIKeyInput: the system needs
    /// UITextInput's marked-text handling for pinyin, candidates and handwriting. That is
    /// why Chinese could not be typed at all here. The view keeps no document of its own --
    /// committed text is sent straight to the Mac -- but it does keep the text the IME is
    /// composing so the keyboard can work with it.
    final class CatcherView: KeyListener, UITextInput {
        var onHide: () -> Void = {}
        private lazy var row: UIHostingController<ModifierRow> = {
            let host = UIHostingController(rootView: ModifierRow(hide: { [weak self] in self?.onHide() }))
            host.sizingOptions = []
            host.view.backgroundColor = .clear
            host.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 56)
            host.view.autoresizingMask = .flexibleWidth
            return host
        }()

        override var inputAccessoryView: UIView? { row.view }
        var hasText: Bool { true }
        var autocorrectionType: UITextAutocorrectionType = .no
        var autocapitalizationType: UITextAutocapitalizationType = .none
        var spellCheckingType: UITextSpellCheckingType = .no
        var smartQuotesType: UITextSmartQuotesType = .no
        var smartDashesType: UITextSmartDashesType = .no
        weak var inputDelegate: UITextInputDelegate?

        // MARK: - The text the IME is composing

        private var marked = ""
        private lazy var tokenizerObject = UITextInputStringTokenizer(textInput: self)
        var tokenizer: UITextInputTokenizer { tokenizerObject }

        private final class Position: UITextPosition {
            let offset: Int
            init(_ offset: Int) { self.offset = offset }
        }

        private final class Range: UITextRange {
            let from: Int, to: Int
            init(_ from: Int, _ to: Int) { self.from = from; self.to = to }
            override var start: UITextPosition { Position(from) }
            override var end: UITextPosition { Position(to) }
            override var isEmpty: Bool { from == to }
        }

        private func offset(_ p: UITextPosition) -> Int { (p as? Position)?.offset ?? 0 }

        var beginningOfDocument: UITextPosition { Position(0) }
        var endOfDocument: UITextPosition { Position(marked.count) }
        var selectedTextRange: UITextRange? {
            get { Range(marked.count, marked.count) }
            set { }
        }
        var markedTextRange: UITextRange? { marked.isEmpty ? nil : Range(0, marked.count) }
        var markedTextStyle: [NSAttributedString.Key: Any]? {
            get { nil }
            set { }
        }

        func text(in range: UITextRange) -> String? {
            guard let r = range as? Range, r.from >= 0, r.from <= r.to, r.to <= marked.count else { return nil }
            return (marked as NSString).substring(with: NSRange(location: r.from, length: r.to - r.from))
        }

        func replace(_ range: UITextRange, withText text: String) {
            marked = ""
            send(text)
        }

        func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
            marked = markedText ?? ""
        }

        func unmarkText() { marked = "" }

        func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
            Range(offset(fromPosition), offset(toPosition))
        }

        func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
            let p = self.offset(position) + offset
            return p >= 0 && p <= marked.count ? Position(p) : nil
        }

        func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
            let step = direction == .left || direction == .up ? -offset : offset
            return self.position(from: position, offset: step)
        }

        func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
            let a = offset(position), b = offset(other)
            return a < b ? .orderedAscending : a > b ? .orderedDescending : .orderedSame
        }

        func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
            offset(toPosition) - offset(from)
        }

        func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
            guard let r = range as? Range else { return nil }
            return Position(direction == .left || direction == .up ? r.from : r.to)
        }

        func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
            let p = offset(position)
            return direction == .left || direction == .up ? Range(0, p) : Range(p, marked.count)
        }

        func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection { .natural }
        func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) { }
        func firstRect(for range: UITextRange) -> CGRect { .zero }
        func caretRect(for position: UITextPosition) -> CGRect { .zero }
        func selectionRects(for range: UITextRange) -> [UITextSelectionRect] { [] }
        func closestPosition(to point: CGPoint) -> UITextPosition? { endOfDocument }
        func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? { endOfDocument }
        func characterRange(at point: CGPoint) -> UITextRange? { Range(marked.count, marked.count) }
        func shouldChangeText(in range: UITextRange, replacementText text: String) -> Bool { true }

        // MARK: - UIKeyInput

        func insertText(_ text: String) {
            marked = ""
            send(text)
        }

        func deleteBackward() {
            guard !HardwareKeys.keyJustPressed else { return }
            // While composing, the backspace belongs to the IME, not to the Mac.
            if !marked.isEmpty { marked.removeLast(); return }
            Keys.press(Keys.backspace)
            StickyKeys.shared.releaseAll()
        }

        /// ASCII goes to the guest as key codes, as before. Anything else (Chinese, emoji,
        /// accented letters) has no key code at all: Keys.type used to drop it silently, so
        /// it goes through the shared clipboard and is pasted with Command-V instead.
        private func send(_ text: String) {
            guard !HardwareKeys.keyJustPressed, !text.isEmpty else { return }
            if text.unicodeScalars.allSatisfy({ $0.value < 128 }) {
                for c in text { Keys.type(c) }
            } else {
                let batch = text
                Task { @MainActor in UnicodeTyper.shared.send(batch) }
            }
            StickyKeys.shared.releaseAll()
        }
    }
}

/// Linux input key codes, which the Mac's keyboard device takes.
enum Keys {
    static let backspace: UInt16 = 14
    static let shift: UInt16 = 42
    static let escape: UInt16 = 1
    static let tab: UInt16 = 15
    static let control: UInt16 = 29
    static let option: UInt16 = 56
    static let command: UInt16 = 125
    static let up: UInt16 = 103
    static let left: UInt16 = 105
    static let right: UInt16 = 106
    static let down: UInt16 = 108
    private static let letters: [Character: UInt16] = [
        "q": 16, "w": 17, "e": 18, "r": 19, "t": 20, "y": 21, "u": 22, "i": 23, "o": 24, "p": 25,
        "a": 30, "s": 31, "d": 32, "f": 33, "g": 34, "h": 35, "j": 36, "k": 37, "l": 38,
        "z": 44, "x": 45, "c": 46, "v": 47, "b": 48, "n": 49, "m": 50,
    ]
    private static let plain: [Character: UInt16] = [
        "1": 2, "2": 3, "3": 4, "4": 5, "5": 6, "6": 7, "7": 8, "8": 9, "9": 10, "0": 11,
        "-": 12, "=": 13, "\t": 15, "[": 26, "]": 27, "\n": 28, ";": 39, "'": 40, "`": 41, "\\": 43,
        ",": 51, ".": 52, "/": 53, " ": 57,
    ]
    private static let shifted: [Character: UInt16] = [
        "!": 2, "@": 3, "#": 4, "$": 5, "%": 6, "^": 7, "&": 8, "*": 9, "(": 10, ")": 11,
        "_": 12, "+": 13, "{": 26, "}": 27, ":": 39, "\"": 40, "~": 41, "|": 43,
        "<": 51, ">": 52, "?": 53,
    ]

    static func press(_ code: UInt16, shifted: Bool = false) {
        if shifted { henge_vm_key(shift, 1) }
        henge_vm_key(code, 1)
        henge_vm_key(code, 0)
        if shifted { henge_vm_key(shift, 0) }
    }

    /// A letter (or space) with a modifier held.
    static func chord(_ modifier: UInt16, _ c: Character) {
        henge_vm_key(modifier, 1)
        type(c)
        henge_vm_key(modifier, 0)
    }

    /// One character at a time, for what the Mac has to keep up with.
    @MainActor static func typeSlowly(_ text: String) async {
        for c in text {
            type(c)
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
    }

    static func type(_ c: Character) {
        if let code = letters[c] { press(code) }
        else if let lower = c.lowercased().first, let code = letters[lower] { press(code, shifted: true) }
        else if let code = plain[c] { press(code) }
        else if let code = shifted[c] { press(code, shifted: true) }
    }
}

/// ⌃, ⌥ and ⌘ stay down from a tap until the next key or click, so a shortcut takes one finger.
final class StickyKeys: ObservableObject {
    static let shared = StickyKeys()
    @Published private(set) var down: Set<UInt16> = []

    func toggle(_ code: UInt16) {
        if down.contains(code) {
            henge_vm_key(code, 0)
            down.remove(code)
        } else {
            henge_vm_key(code, 1)
            down.insert(code)
        }
    }

    func releaseAll() {
        guard !down.isEmpty else { return }
        for code in down { henge_vm_key(code, 0) }
        down.removeAll()
    }
}

/// The keys an on-screen keyboard doesn't have, in the slot above it.
struct ModifierRow: View {
    let hide: () -> Void
    @ObservedObject private var sticky = StickyKeys.shared

    var body: some View {
        HStack(spacing: 5) {
            HeldKey(label: "esc", code: Keys.escape)
            HeldKey(label: "tab", code: Keys.tab)
            modifier("⌃", Keys.control, "Control")
            modifier("⌥", Keys.option, "Option")
            modifier("⌘", Keys.command, "Command")
            HeldKey(label: "←", code: Keys.left)
            HeldKey(label: "↑", code: Keys.up)
            HeldKey(label: "↓", code: Keys.down)
            HeldKey(label: "→", code: Keys.right)
            Button(action: hide) {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Desk.text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Desk.raised, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .accessibilityLabel("Hide keyboard")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .frame(height: 56)
    }

    private func modifier(_ symbol: String, _ code: UInt16, _ name: String) -> some View {
        let on = sticky.down.contains(code)
        return Button {
            sticky.toggle(code)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(on ? Color.white : Desk.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(on ? Desk.accent : Desk.raised, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .accessibilityLabel(name)
    }
}

/// A key that goes down when touched and up when let go, so holding it repeats as on a Mac.
private struct HeldKey: View {
    let label: String
    let code: UInt16
    @State private var down = false

    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Desk.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(down ? Desk.accent : Desk.raised, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !down else { return }
                        down = true
                        henge_vm_key(code, 1)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .onEnded { _ in
                        down = false
                        henge_vm_key(code, 0)
                        StickyKeys.shared.releaseAll()
                    }
            )
            .accessibilityLabel(label)
    }
}

/// Text with no key code cannot be typed into the Mac one key at a time. Henge's shared
/// clipboard carries any Unicode: put the text there, let the helper inside macOS copy it
/// onto the Mac's clipboard, then press Command-V. Submissions that arrive close together
/// are batched, so a whole phrase is pasted at once instead of one character per second.
@MainActor
final class UnicodeTyper {
    static let shared = UnicodeTyper()
    private var pending = ""
    private var flush: Task<Void, Never>?
    private init() { }

    func send(_ text: String) {
        pending += text
        flush?.cancel()
        flush = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000) // let the IME finish one submission
            guard !Task.isCancelled, !self.pending.isEmpty else { return }
            let batch = self.pending
            self.pending = ""
            await Sharing.deliver(batch)
        }
    }
}
