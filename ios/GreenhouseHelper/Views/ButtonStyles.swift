import SwiftUI

private let appButtonWidth: CGFloat = 238

private struct AppHaloButtonBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let restingTextColor: Color

    var body: some View {
        label
            .font(AppFont.headline())
            .tracking(-0.2)
            .foregroundStyle(isPressed ? AppPalette.white : restingTextColor)
            .frame(width: appButtonWidth)
            .padding(.vertical, 14)
            .background(isPressed ? AppPalette.black : AppPalette.lightGreen.opacity(0.92))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppPalette.lightGreen.opacity(isPressed ? 0.95 : 0.0), lineWidth: 2)
            )
            .shadow(
                color: isPressed ? AppPalette.lightGreen.opacity(0.8) : .clear,
                radius: isPressed ? 14 : 0,
                x: 0,
                y: 0
            )
            .scaleEffect(isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        AppHaloButtonBody(
            label: configuration.label,
            isPressed: configuration.isPressed,
            restingTextColor: AppPalette.black
        )
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        AppHaloButtonBody(
            label: configuration.label,
            isPressed: configuration.isPressed,
            restingTextColor: AppPalette.white
        )
    }
}
