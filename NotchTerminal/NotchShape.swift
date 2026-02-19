import SwiftUI

struct NotchShape: Shape {
    var cornerRadius: CGFloat
    var shoulderRadius: CGFloat
    var overshoot: CGFloat = 0

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(cornerRadius, AnimatablePair(shoulderRadius, overshoot)) }
        set {
            cornerRadius = newValue.first
            shoulderRadius = newValue.second.first
            overshoot = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let sr = shoulderRadius
        let cr = cornerRadius
        let topY = overshoot

        var path = Path()

        // Start at top-left
        path.move(to: CGPoint(x: 0, y: 0))

        // Top edge
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        
        // Down to shoulder start
        path.addLine(to: CGPoint(x: rect.width, y: topY))

        // Right concave shoulder: arc from (rect.width, topY) to (rect.width - sr, topY + sr)
        path.addArc(
            center: CGPoint(x: rect.width, y: topY + sr),
            radius: sr,
            startAngle: .degrees(-90),
            endAngle: .degrees(180),
            clockwise: true
        )

        // Right side down to bottom-right corner
        path.addLine(to: CGPoint(x: rect.width - sr, y: rect.height - cr))

        // Bottom-right rounded corner
        path.addArc(
            center: CGPoint(x: rect.width - sr - cr, y: rect.height - cr),
            radius: cr,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: sr + cr, y: rect.height))

        // Bottom-left rounded corner
        path.addArc(
            center: CGPoint(x: sr + cr, y: rect.height - cr),
            radius: cr,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )

        // Left side up to left shoulder
        path.addLine(to: CGPoint(x: sr, y: topY + sr))

        // Left concave shoulder: arc from (sr, topY + sr) to (0, topY)
        path.addArc(
            center: CGPoint(x: 0, y: topY + sr),
            radius: sr,
            startAngle: .degrees(0),
            endAngle: .degrees(-90),
            clockwise: true
        )

        // Up to top-left
        path.addLine(to: CGPoint(x: 0, y: 0))

        path.closeSubpath()
        return path
    }
}
