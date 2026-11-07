import SwiftUI

struct ContentView: View {
    @State private var taps = 0

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Built with Apprtur")
                .font(.title.bold())
            Text("Written on Windows, built on a Mac, installed over USB.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Tapped \(taps) times") { taps += 1 }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
