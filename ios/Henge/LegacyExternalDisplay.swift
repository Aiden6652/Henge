import SwiftUI
import UIKit

/// Before iOS 27, a connected display (USB-C cable or AirPlay) arrives as a
/// `windowExternalDisplayNonInteractive` scene offered to the app delegate (HengeAppDelegate).
/// This shows the running Mac on those scenes as ExternalScreenPlan decides; a screen not showing
/// it gets no window of ours, so iOS mirrors the phone there. iOS 27 offers the scene only to the
/// accessory ExternalMacDisplayModifier registers, so here it never sees one.
@MainActor
final class LegacyExternalDisplay {
    static let shared = LegacyExternalDisplay()

    /// Whether iOS offers external display scenes to the app delegate.
    nonisolated static var offeredToAppDelegate: Bool {
        if #available(iOS 27.0, *) { return false } else { return true }
    }

    private var plan = ExternalScreenPlan<ObjectIdentifier, MacPresentation>()
    private var presentation: MacPresentation?
    private var scenes: [ObjectIdentifier: ExternalDisplaySceneDelegate] = [:]

    /// A session appeared: its Mac goes to every connected display.
    func begin(_ presentation: MacPresentation) {
        self.presentation = presentation
        apply(plan.begin(presentation))
    }

    /// A session went away: its displays go back to mirroring.
    func end(_ presentation: MacPresentation) {
        apply(plan.end(presentation))
        if self.presentation == presentation { self.presentation = nil }
    }

    fileprivate func connected(_ scene: ExternalDisplaySceneDelegate) {
        scenes[ObjectIdentifier(scene)] = scene
        apply(plan.connect(ObjectIdentifier(scene)))
    }

    fileprivate func disconnected(_ scene: ExternalDisplaySceneDelegate) {
        apply(plan.disconnect(ObjectIdentifier(scene)))
        scenes.removeValue(forKey: ObjectIdentifier(scene))
    }

    private func apply(_ changes: [ExternalScreenPlan<ObjectIdentifier, MacPresentation>.Change]) {
        for change in changes {
            switch change {
            case .showMac(let id):
                if let presentation { scenes[id]?.showMac(presentation) }
            case .stopMac(let id):
                scenes[id]?.stopMac()
                // The external view's own detach may never come once its window is gone.
                presentation?.display.releaseExternal()
            }
        }
    }
}

/// One external display scene (UIResponder makes it main-actor).
final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var windowScene: UIWindowScene?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        windowScene = scene
        let mode = scene.screen.currentMode
        HengeLog.log("display", "external display connected: \(Int(scene.screen.nativeBounds.width))x\(Int(scene.screen.nativeBounds.height)) px, "
                   + "mode \(mode.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "unknown"), "
                   + "scale \(scene.screen.nativeScale), \(scene.screen.maximumFramesPerSecond) Hz")
        LegacyExternalDisplay.shared.connected(self)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        HengeLog.log("display", "external display disconnected")
        LegacyExternalDisplay.shared.disconnected(self)
        windowScene = nil
    }

    fileprivate func showMac(_ presentation: MacPresentation) {
        guard let windowScene else { return }
        let window = self.window ?? UIWindow(windowScene: windowScene)
        window.backgroundColor = .black
        window.rootViewController = UIHostingController(rootView: ExternalMacDisplay(presentation: presentation))
        window.isHidden = false
        self.window = window
        HengeLog.log("display", "the Mac is on the external display")
    }

    /// Takes the Mac off this display: no window of ours, so iOS mirrors the phone (or the display is gone).
    fileprivate func stopMac() {
        guard let window else { return }
        window.rootViewController = nil // lets SwiftUI take the screen view down, which detaches its layer
        window.isHidden = true
        self.window = nil
        HengeLog.log("display", "the Mac left the external display")
    }
}
