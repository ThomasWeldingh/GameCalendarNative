import SwiftUI

struct AppCommands: Commands {
    @Bindable var state: AppState

    var body: some Commands {
        CommandMenu("Navigasjon") {
            Button("Måned") { state.switchToCalendarMode(.month) }
                .keyboardShortcut("1", modifiers: .command)

            Button("Uke") { state.switchToCalendarMode(.week) }
                .keyboardShortcut("2", modifiers: .command)

            Button("Dag") { state.switchToCalendarMode(.day) }
                .keyboardShortcut("3", modifiers: .command)

            Divider()

            Button("Kommende") { state.switchToSection(.tba) }
                .keyboardShortcut("4", modifiers: .command)

            Button("Ønskeliste") { state.switchToSection(.wishlist) }
                .keyboardShortcut("5", modifiers: .command)

            Button("Lister") { state.switchToSection(.lists) }
                .keyboardShortcut("6", modifiers: .command)

            Button("Nylig lagt til") { state.switchToSection(.new) }
                .keyboardShortcut("7", modifiers: .command)

            Divider()

            Button("I dag") { state.goToToday() }
                .keyboardShortcut("t", modifiers: .command)
        }
    }
}
