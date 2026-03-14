import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        MainView(state: appState)
    }
}
