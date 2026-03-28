import SwiftUI

struct SlapHelloWorldView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Hello World!")
                .font(.title.bold())

            Text("slap.helloWorld.message".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(width: 360, height: 200)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Slap Hello World") {
    SlapHelloWorldView()
}
