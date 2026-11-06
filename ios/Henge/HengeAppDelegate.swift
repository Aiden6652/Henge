import UIKit

/// The app's UIKit delegate, for what SwiftUI's App cannot express.
final class HengeAppDelegate: NSObject, UIApplicationDelegate {
    /// Before iOS 27, external display scenes come here; LegacyExternalDisplay shows the Mac on them.
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        if session.role == .windowExternalDisplayNonInteractive, LegacyExternalDisplay.offeredToAppDelegate {
            config.delegateClass = ExternalDisplaySceneDelegate.self
            HengeLog.log("display", "external display scene offered: taking it")
        }
        return config
    }
}
