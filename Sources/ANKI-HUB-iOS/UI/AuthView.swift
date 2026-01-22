import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject private var theme = ThemeManager.shared
    
    // Animation states
    @State private var startAnimation = false
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // Liquid Glass Background
            theme.background
            
            // Animated blobs for "liquid" feel
            GeometryReader { proxy in
                let size = proxy.size

                let blobA = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
                let blobB = theme.currentPalette.color(.selection, isDark: theme.effectiveIsDark)
                let blobC = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
                
                Circle()
                    .fill(blobA.opacity(0.3))
                    .blur(radius: 60)
                    .frame(width: 300, height: 300)
                    .offset(x: startAnimation ? -100 : -50, y: startAnimation ? -150 : -200)
                
                Circle()
                    .fill(blobB.opacity(0.3))
                    .blur(radius: 50)
                    .frame(width: 250, height: 250)
                    .offset(x: startAnimation ? size.width - 150 : size.width - 200, y: startAnimation ? size.height - 150 : size.height - 200)
                    
                Circle()
                    .fill(blobC.opacity(0.2))
                    .blur(radius: 40)
                    .frame(width: 200, height: 200)
                    .offset(x: startAnimation ? size.width / 2 : 50, y: startAnimation ? 200 : size.height / 2)
            }
            .ignoresSafeArea()
            
            // Content
            VStack(spacing: 40) {
                Spacer()
                
                // Icon & Title
                VStack(spacing: 20) {
                    Image(systemName: "book.pages.fill")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark),
                                    theme.currentPalette.color(.selection, isDark: theme.effectiveIsDark)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(showContent ? 1 : 0.8)
                        .opacity(showContent ? 1 : 0)
                    
                    VStack(spacing: 8) {
                        Text("ANKI-HUB")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(ThemeManager.shared.primaryText)
                            .accessibilityAddTraits(.isHeader)

                        Text("Your Personal Memory Assistant")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                }
                
                Spacer()
                
                // Card for Login Actions
                VStack(spacing: 24) {
                    if authManager.isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                    } else {
                        // Google Sign In
                        Button {
                            Task {
                                await authManager.signInWithGoogle()
                            }
                        } label: {
                            let bg = theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark)
                            HStack(spacing: 12) {
                                Image(systemName: "globe") // Placeholder for Google Icon
                                    .font(.title2)
                                Text("Sign in with Google")
                                    .font(.headline.weight(.semibold))
                            }
                            .foregroundStyle(theme.onColor(for: bg))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(bg)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        theme.currentPalette.color(.border, isDark: theme.effectiveIsDark)
                                            .opacity(theme.effectiveIsDark ? 0.55 : 0.35),
                                        lineWidth: 1
                                    )
                            )
                        }
                        
                        // Guest Access
                        Button {
                            Task {
                                // Demo login
                                await authManager.signInWithGoogle()
                            }
                        } label: {
                            Text("Continue as Guest")
                                .font(.footnote)
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                        }
                    }
                }
                .padding(30)
                .background(ThemeManager.shared.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 30))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                .offset(y: showContent ? 0 : 50)
                .opacity(showContent ? 1 : 0)
                
                Spacer()
                    .frame(height: 50)
            }
        }
        .onAppear {
            if reduceMotion {
                showContent = true
                startAnimation = false
            } else {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    startAnimation.toggle()
                }
                
                withAnimation(.spring(duration: 0.8).delay(0.2)) {
                    showContent = true
                }
            }
        }
        .onChange(of: authManager.currentUser) { _, newValue in
            if newValue != nil {
                dismiss() // Auto dismiss on login
            }
        }
        .alert(
            "ログインに失敗しました",
            isPresented: Binding(
                get: { authManager.lastAuthErrorMessage != nil },
                set: { newValue in
                    if !newValue {
                        authManager.clearAuthError()
                    }
                }
            )
        ) {
            Button("OK") {
                authManager.clearAuthError()
            }
        } message: {
            Text(authManager.lastAuthErrorMessage ?? "")
        }
        .applyAppTheme()
    }
}
