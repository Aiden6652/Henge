import Foundation
import QuartzCore

/// What the engine was last told to draw into.
nonisolated(unsafe) var engineLayer: UnsafeMutableRawPointer?

@_cdecl("henge_vm_set_display_layer")
func recordDisplayLayer(_ layer: UnsafeMutableRawPointer?) { engineLayer = layer }

@main
struct DisplayRouterTests {
    @MainActor static func main() {
        let phoneLayer = CAMetalLayer(), monitorLayer = CAMetalLayer()
        let phone = UUID(), monitor = UUID()
        let router = DisplayRouter()
        func engineShows(_ layer: CAMetalLayer) -> Bool { engineLayer == Unmanaged.passUnretained(layer).toOpaque() }

        router.connect(phone, layer: phoneLayer, role: .device)
        router.connect(monitor, layer: monitorLayer, role: .external)
        precondition(engineShows(monitorLayer) && router.isExternal)

        // Unplugging the monitor: iOS may never tear down the view that held its layer, so the
        // display scene releases it, and the phone gets the Mac back at once.
        router.releaseExternal()
        precondition(engineShows(phoneLayer) && !router.isExternal)

        // The view's own late detach afterwards changes nothing.
        router.disconnect(monitor)
        precondition(engineShows(phoneLayer) && !router.isExternal)
        print("Display router: all unplug checks passed")
    }
}
