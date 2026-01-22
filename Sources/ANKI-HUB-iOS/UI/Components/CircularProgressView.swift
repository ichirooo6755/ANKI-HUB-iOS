import SwiftUI

struct CircularProgressView: View {
    let progress: Double
    var color: Color = .blue
    var lineWidth: CGFloat = 5
    var accessibilityLabel: String = "進捗"
    
    var body: some View {
        let clamped = min(max(progress, 0), 1)
        Gauge(value: clamped) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .gaugeStyle(.accessoryCircular)
        .tint(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityValue(Text("\(Int(clamped * 100))%"))
    }
}
