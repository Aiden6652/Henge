import SwiftUI

/// The accessory only presents the existing Mac's pixels. It never owns or
/// starts a VM, and hardware input continues through the phone's SessionView.
struct ExternalMacDisplay: View {
    let display: DisplayRouter
    let aspect: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width, geometry.size.height * aspect)
            BootDisplay(display: display, role: .external)
                .frame(width: width, height: width / aspect)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.black)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .preferredColorScheme(.dark)
    }
}

/// iOS 27 delivers a separate noninteractive display scene only when the app
/// registers this accessory. iOS 17–26 offer that scene to the app delegate
/// instead (LegacyExternalDisplay), which this tells about the session.
struct ExternalMacDisplayModifier: ViewModifier {
    let display: DisplayRouter
    let aspect: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 27.0, *) {
            content.sceneAccessory {
                ExternalNonInteractiveAccessory {
                    ExternalMacDisplay(display: display, aspect: aspect)
                }
            }
        } else {
            content
                .onAppear { LegacyExternalDisplay.shared.begin(display, aspect: aspect) }
                .onDisappear { LegacyExternalDisplay.shared.end(display) }
        }
    }
}
