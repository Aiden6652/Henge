import Foundation

@main
struct ExternalScreenPlanTests {
    static func main() {
        var plan = ExternalScreenPlan<String, Int>()

        // A monitor plugged in before any session shows nothing of ours: iOS mirrors the phone.
        precondition(plan.connect("monitor") == [])
        // The session begins: the waiting monitor gets the Mac.
        precondition(plan.begin(1) == [.showMac("monitor")])

        // Unplugged while showing the Mac: stop, so the phone gets it back.
        precondition(plan.disconnect("monitor") == [.stopMac("monitor")])
        // A screen the plan never saw changes nothing.
        precondition(plan.disconnect("ghost") == [])

        // Plugged in while the session runs: the Mac goes there at once.
        precondition(plan.connect("monitor") == [.showMac("monitor")])

        // A stale session ending (an old SessionView going away late) leaves the running one alone.
        precondition(plan.end(2) == [])
        // The session ends: every screen showing the Mac goes back to mirroring...
        precondition(plan.end(1) == [.stopMac("monitor")])
        // ...and stays that way for screens plugged in afterwards.
        precondition(plan.connect("second") == [])

        print("External screen plan: all checks passed")
    }
}
