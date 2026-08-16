import SwiftUI

struct ContentView: View {
    var body: some View {
        GamesHomeView()
            .overlay(alignment: .bottom) {
                KeyCountdownFooter()
                    .allowsHitTesting(false)
            }
    }
}
