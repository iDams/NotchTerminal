import SwiftUI
import AppKit

struct ContentView: View {
    @State var offset: CGFloat = 0
    var body: some View {
        Canvas { context, size in
            context.addFilter(.alphaThreshold(min: 0.5, color: .black))
            context.addFilter(.blur(radius: 10))
            context.drawLayer { ctx in
                ctx.fill(Path(ellipseIn: CGRect(x: 50, y: 50, width: 100, height: 100)), with: .color(.black))
                ctx.fill(Path(ellipseIn: CGRect(x: 50, y: 50 + offset, width: 100, height: 100)), with: .color(.black))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever()) {
                offset = 120
            }
        }
    }
}
print("Canvas exists")
