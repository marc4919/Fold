import SwiftUI
import Playgrounds

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("hello Marc")
            .padding()
    }
}

#Preview {
    ContentView()
}

#Playground {
    _ = 1 + 2
}
