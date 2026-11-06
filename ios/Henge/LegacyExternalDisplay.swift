import SwiftUI
import UIKit

/// iOS 17–26: a connected display (USB-C cable or AirPlay) arrives as a scene with the
/// `windowExternalDisplayNonInteractive` role, offered to any app that answers for it. The app answers
/// while a Mac session is on screen and shows that session's pixels there (ExternalMacDisplay, the view
/// the iOS 27 accessory uses). With no session, or the scene declined, iOS keeps mirroring the phone.
/// iOS 27 offers the role only to a registered scene accessory, which ExternalMacDisplayModifier does.
final class HengeAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        if #available(iOS 27.0, *) { return config }
        if session.role == .windowExternalDisplayNonInteractive {
            config.delegateClass = LegacyExternalDisplayScene.self
            HengeLog.log("display", "external display scene offered (iOS before 27): taking it")
        }
        return config
    }
}

/// The running session, and the external display scenes waiting for one.
@MainActor
final class LegacyExternalDisplay {
    static let shared = LegacyExternalDisplay()

    private var session: (display: DisplayRouter, aspect: CGFloat)?
    private var scenes: [ObjectIdentifier: LegacyExternalDisplayScene] = [:]

    /// SessionView appeared: its Mac can go to any connected display.
    func begin(_ display: DisplayRouter, aspect: CGFloat) {
        session = (display, aspect)
        scenes.values.forEach { $0.show(session) }
    }

    /// SessionView went away: hand each display back to mirroring.
    func end(_ display: DisplayRouter) {
        guard session?.display === display else { return }
        session = nil
        scenes.values.forEach { $0.show(nil) }
    }

    fileprivate func connected(_ scene: LegacyExternalDisplayScene) {
        scenes[ObjectIdentifier(scene)] = scene
        scene.show(session)
    }

    fileprivate func disconnected(_ scene: LegacyExternalDisplayScene) {
        scenes.removeValue(forKey: ObjectIdentifier(scene))
    }
}

final class LegacyExternalDisplayScene: UIResponder, UIWindowSceneDelegate {
    private var windowScene: UIWindowScene?
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        windowScene = scene
        let mode = scene.screen.currentMode
        HengeLog.log("display", "external display connected: \(Int(scene.screen.nativeBounds.width))x\(Int(scene.screen.nativeBounds.height)) px, "
                   + "mode \(mode.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "unknown"), "
                   + "scale \(scene.screen.nativeScale), \(scene.screen.maximumFramesPerSecond) Hz")
        MainActor.assumeIsolated { LegacyExternalDisplay.shared.connected(self) }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        HengeLog.log("display", "external display disconnected")
        MainActor.assumeIsolated { LegacyExternalDisplay.shared.disconnected(self) }
        window = nil
        windowScene = nil
    }

    /// The session's pixels, or no window at all so iOS mirrors the phone.
    @MainActor
    fileprivate func show(_ session: (display: DisplayRouter, aspect: CGFloat)?) {
        guard let windowScene else { return }
        guard let session else {
            if window != nil { HengeLog.log("display", "no Mac session: the external display mirrors the phone") }
            window?.isHidden = true
            window = nil
            return
        }
        if window == nil {
            let window = UIWindow(windowScene: windowScene)
            window.backgroundColor = .black
            self.window = window
        }
        window?.rootViewController = UIHostingController(rootView: ExternalMacDisplay(display: session.display, aspect: session.aspect))
        window?.isHidden = false
        HengeLog.log("display", "the Mac is on the external display")
    }
}
