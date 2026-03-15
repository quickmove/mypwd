import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.isSetup {
                SetupView()
            } else if !appState.isUnlocked {
                UnlockView()
            } else {
                MainView()
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
