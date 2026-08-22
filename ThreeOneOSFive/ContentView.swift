import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var supportToastModel: SupportStatusToastModel

    var body: some View {
        GamesHomeView()
            .overlay(alignment: .bottom) {
                KeyCountdownFooter()
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                SupportStatusToast(model: supportToastModel, autoDismissAfter: 6.0)
            }
    }
}
