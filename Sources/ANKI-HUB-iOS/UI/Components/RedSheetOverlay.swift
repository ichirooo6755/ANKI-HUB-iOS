import SwiftUI

struct RedSheetOverlay: View {
    @Binding var isEnabled: Bool

    var body: some View {
        if isEnabled {
            Rectangle()
                .fill(Color(red: 1.0, green: 0.2, blue: 0.2))  // Slightly adjusted red
                .blendMode(.multiply)
                .ignoresSafeArea()
                .allowsHitTesting(false)  // Let touches pass through
                .transition(.opacity)
                .zIndex(999)  // Always on top
        }
    }
}

// Modifier for easy usage
struct RedSheetModifier: ViewModifier {
    @Binding var isEnabled: Bool

    func body(content: Content) -> some View {
        ZStack {
            content
            RedSheetOverlay(isEnabled: $isEnabled)
        }
    }
}

extension View {
    func redSheet(isEnabled: Binding<Bool>) -> some View {
        self.modifier(RedSheetModifier(isEnabled: isEnabled))
    }
}
