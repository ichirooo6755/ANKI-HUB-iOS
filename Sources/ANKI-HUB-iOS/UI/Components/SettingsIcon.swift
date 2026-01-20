import SwiftUI

struct SettingsIcon: View {
    let icon: String
    let color: Color
    var foregroundColor: Color = .white

    var body: some View {
        Image(systemName: icon)
            .foregroundStyle(foregroundColor)
            .font(.system(size: 16))
            .frame(width: 28, height: 28)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
