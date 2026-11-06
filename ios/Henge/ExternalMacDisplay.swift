import SwiftUI

/// A running Mac as an external display shows it: the session's router and the Mac's screen
/// shape. Two presentations are the same when they share the router.
struct MacPresentation: Equatable {
    let display: DisplayRouter
    let aspect: CGFloat

    static func == (a: MacPresentation, b: MacPresentation) -> Bool { a.display === b.display }
}

/// The accessory only presents the existing Mac's pixels. It never owns or
/// starts a VM, and hardware input continues through the phone's SessionView.
struct ExternalMacDisplay: View {
    let presentation: MacPresentation

    var body: some View {
        GeometryReader { geometry in
            let aspect = presentation.aspect
            let width = min(geometry.size.width, geometry.size.height * aspect)
            BootDisplay(display: presentation.display, role: .external)
                .frame(width: width, height: width / aspect)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.black)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .preferredColorScheme(.dark)
    }
}

/// Puts the session's Mac on an external display. iOS 27 delivers that scene only to this
/// accessory; earlier iOS offers it to the app delegate (LegacyExternalDisplay), which is told
/// about the session either way and acts only where iOS offers it scenes.
struct ExternalMacDisplayModifier: ViewModifier {
    let presentation: MacPresentation

    @ViewBuilder
    func body(content: Content) -> some View {
        let session = content
            .onAppear { LegacyExternalDisplay.shared.begin(presentation) }
            .onDisappear { LegacyExternalDisplay.shared.end(presentation) }
        if #available(iOS 27.0, *) { // the compiler's gate for the accessory API
            session.sceneAccessory {
                ExternalNonInteractiveAccessory {
                    ExternalMacDisplay(presentation: presentation)
                }
            }
        } else {
            session
        }
    }
}
