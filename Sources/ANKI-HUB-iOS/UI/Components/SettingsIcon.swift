import SwiftUI

struct SettingsIcon: View {
    let icon: String
    let color: Color
    var foregroundColor: Color = .white

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return Image(systemName: icon)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(foregroundColor)
            .font(.callout.weight(.semibold))
            .frame(width: 30, height: 30)
            .background(
                Group {
                    shape.fill(.thinMaterial)
                }
            )
            .background(color.opacity(0.9))
            .clipShape(shape)
            .overlay(
                shape
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
    }
}
