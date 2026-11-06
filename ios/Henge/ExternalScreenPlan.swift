import Foundation

/// Before iOS 27: which connected external screens show the running Mac. A screen not showing
/// it gets no window of ours, so iOS mirrors the phone there. Pure, so every order of session
/// and plug events can be tested; LegacyExternalDisplay carries out the changes it returns.
struct ExternalScreenPlan<Screen: Hashable, Session: Equatable> {
    enum Change: Equatable {
        case showMac(Screen)
        case stopMac(Screen)
    }

    private var session: Session?
    private var screens: [Screen] = []

    mutating func connect(_ screen: Screen) -> [Change] {
        screens.append(screen)
        return session == nil ? [] : [.showMac(screen)]
    }

    mutating func disconnect(_ screen: Screen) -> [Change] {
        guard let at = screens.firstIndex(of: screen) else { return [] }
        screens.remove(at: at)
        return session == nil ? [] : [.stopMac(screen)]
    }

    mutating func begin(_ session: Session) -> [Change] {
        self.session = session
        return screens.map { .showMac($0) }
    }

    /// Only the session that began can end it: a late end from an older one changes nothing.
    mutating func end(_ session: Session) -> [Change] {
        guard self.session == session else { return [] }
        self.session = nil
        return screens.map { .stopMac($0) }
    }
}
