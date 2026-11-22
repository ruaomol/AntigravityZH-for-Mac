import AppKit
import SwiftUI

// MARK: - Adaptive Porcelain Light × Obsidian Dark Design System

enum StudioTheme {
    private static func dynamic(
        light: (CGFloat, CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat, CGFloat)
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(calibratedRed: c.0, green: c.1, blue: c.2, alpha: c.3)
        })
    }

    // Pure porcelain white in Light Mode; deep cosmic obsidian in Dark Mode (NEVER muddy gray!)
    static let canvas = dynamic(
        light: (0.976, 0.980, 0.988, 1.0),    // #F9FAFC
        dark:  (0.016, 0.018, 0.024, 1.0)     // #040406
    )
    static let canvasUpper = dynamic(
        light: (0.996, 0.998, 1.000, 1.0),    // #FEFFFF
        dark:  (0.032, 0.035, 0.046, 1.0)     // #08090C
    )
    static let surface = dynamic(
        light: (1.000, 1.000, 1.000, 0.92),   // Pure elevated white card
        dark:  (0.062, 0.066, 0.082, 1.0)     // #101115
    )
    static let surfaceOverlay = dynamic(
        light: (0.988, 0.990, 0.996, 0.97),   // Frosted porcelain overlay
        dark:  (0.052, 0.056, 0.070, 0.97)    // Frosted obsidian overlay
    )
    static let surfaceDeep = dynamic(
        light: (0.945, 0.953, 0.968, 0.90),   // Crisp light console
        dark:  (0.024, 0.026, 0.034, 0.94)    // Deep obsidian console
    )
    static let scrim = dynamic(
        light: (0.060, 0.080, 0.140, 0.20),
        dark:  (0.000, 0.000, 0.000, 0.66)
    )

    // Architectural hairlines
    static let hairline = dynamic(
        light: (0.06, 0.08, 0.14, 0.09),
        dark:  (1.00, 1.00, 1.00, 0.085)
    )
    static let hairlineTop = dynamic(
        light: (0.06, 0.08, 0.14, 0.07),
        dark:  (1.00, 1.00, 1.00, 0.14)
    )
    static let hairlineBottom = dynamic(
        light: (0.06, 0.08, 0.14, 0.11),
        dark:  (1.00, 1.00, 1.00, 0.045)
    )
    static let hoverFill = dynamic(
        light: (0.06, 0.08, 0.14, 0.055),
        dark:  (1.00, 1.00, 1.00, 0.065)
    )
    static let controlTrack = dynamic(
        light: (0.06, 0.08, 0.14, 0.075),
        dark:  (1.00, 1.00, 1.00, 0.085)
    )

    // Editorial typography hierarchy
    static let textPrimary = dynamic(
        light: (0.067, 0.075, 0.098, 1.0),    // #111319
        dark:  (0.965, 0.969, 0.980, 1.0)     // #F6F7FA
    )
    static let textSecondary = dynamic(
        light: (0.376, 0.404, 0.463, 1.0),    // #606776
        dark:  (0.545, 0.569, 0.620, 1.0)     // #8B919E
    )
    static let textTertiary = dynamic(
        light: (0.545, 0.573, 0.627, 1.0),    // #8B92A0
        dark:  (0.365, 0.388, 0.435, 1.0)     // #5D636F
    )
    static let onPrimaryButton = dynamic(
        light: (0.988, 0.992, 1.000, 1.0),    // Pure white text on black pill in Light mode
        dark:  (0.016, 0.018, 0.024, 1.0)     // Pure obsidian text on white pill in Dark mode
    )

    // Authentic Antigravity 4-color prismatic spectrum
    static let prismBlue = dynamic(
        light: (0.145, 0.435, 0.935, 1.0),
        dark:  (0.259, 0.545, 0.988, 1.0)
    )
    static let prismGreen = dynamic(
        light: (0.118, 0.608, 0.322, 1.0),
        dark:  (0.227, 0.722, 0.420, 1.0)
    )
    static let prismYellow = dynamic(
        light: (0.878, 0.588, 0.024, 1.0),
        dark:  (0.984, 0.765, 0.196, 1.0)
    )
    static let prismRed = dynamic(
        light: (0.855, 0.220, 0.180, 1.0),
        dark:  (0.933, 0.325, 0.267, 1.0)
    )

    // Semantic accents
    static let ready = dynamic(
        light: (0.090, 0.580, 0.350, 1.0),
        dark:  (0.310, 0.824, 0.569, 1.0)
    )
    static let attention = dynamic(
        light: (0.788, 0.490, 0.039, 1.0),
        dark:  (0.953, 0.729, 0.318, 1.0)
    )
    static let error = dynamic(
        light: (0.820, 0.196, 0.196, 1.0),
        dark:  (0.945, 0.416, 0.400, 1.0)
    )

    static func windowNSColor(for scheme: AppAppearanceMode) -> NSColor {
        let isDark: Bool = {
            switch scheme {
            case .dark: return true
            case .light: return false
            case .system:
                return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            }
        }()
        return isDark
            ? NSColor(calibratedRed: 0.016, green: 0.018, blue: 0.024, alpha: 1.0)
            : NSColor(calibratedRed: 0.976, green: 0.980, blue: 0.988, alpha: 1.0)
    }
}

typealias GeminiPalette = StudioTheme

// MARK: - Native macOS Haptics

enum MacHaptics {
    static func tap() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    static func confirm() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    static func step() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}

// MARK: - Architectural Glass Panel Surface

struct StudioPanelModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var fill: Color = StudioTheme.surface
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [StudioTheme.hairlineTop, StudioTheme.hairlineBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.7
                    )
            )
            .shadow(
                color: colorScheme == .dark ? Color.clear : Color.black.opacity(0.045),
                radius: 8,
                x: 0,
                y: 2
            )
    }
}

extension View {
    func studioPanel(cornerRadius: CGFloat = 12, fill: Color = StudioTheme.surface) -> some View {
        modifier(StudioPanelModifier(cornerRadius: cornerRadius, fill: fill))
    }
}

// MARK: - Custom Monochrome Toggle Switch (Adaptive Light & Dark)

struct StudioSwitch: View {
    @Binding var isOn: Bool
    var disabled: Bool = false
    @State private var isHovered = false

    var body: some View {
        Button {
            guard !disabled else { return }
            MacHaptics.tap()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(isOn ? StudioTheme.textPrimary : StudioTheme.controlTrack)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                isOn ? StudioTheme.hairline : StudioTheme.hairlineBottom,
                                lineWidth: 0.6
                            )
                    )
                    .frame(width: 34, height: 19)

                Circle()
                    .fill(isOn ? StudioTheme.onPrimaryButton : StudioTheme.textSecondary)
                    .frame(width: 14, height: 14)
                    .shadow(color: Color.black.opacity(0.22), radius: 2, x: 0, y: 1)
                    .padding(.horizontal, 2.5)
            }
            .brightness(isHovered && !disabled ? 0.03 : 0.0)
            .opacity(disabled ? 0.45 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Animated Sliding-Pill Segmented Control (Adaptive Light & Dark)

struct StudioSegmentedControl<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    var disabled: Bool = false

    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options) { option in
                let isSelected = option == selection
                Button {
                    guard !disabled, !isSelected else { return }
                    MacHaptics.tap()
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                        selection = option
                    }
                } label: {
                    Text(title(option))
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? StudioTheme.onPrimaryButton : StudioTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 27)
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(StudioTheme.textPrimary)
                                    .matchedGeometryEffect(id: "StudioSegmentPill", in: pillNamespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(disabled)
            }
        }
        .padding(3)
        .background(
            Capsule(style: .continuous)
                .fill(StudioTheme.controlTrack)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(StudioTheme.hairline, lineWidth: 0.6)
        )
        .opacity(disabled ? 0.5 : 1.0)
    }
}

// MARK: - Hover-Lit Architectural Action Row (Spring Chevron Nudge)

struct StudioActionRow: View {
    let title: String
    var detail: String? = nil
    var symbol: String? = nil
    var tint: Color = StudioTheme.textPrimary
    var enabled: Bool = true
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            guard enabled else { return }
            MacHaptics.tap()
            action()
        } label: {
            HStack(spacing: 9) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(enabled ? (tint == StudioTheme.textPrimary ? StudioTheme.textSecondary : tint) : StudioTheme.textTertiary.opacity(0.4))
                        .frame(width: 16)
                }

                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(enabled ? tint : StudioTheme.textTertiary.opacity(0.45))

                Spacer(minLength: 6)

                if let detail {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(StudioTheme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(enabled ? (isHovered ? StudioTheme.textSecondary : StudioTheme.textTertiary) : StudioTheme.textTertiary.opacity(0.28))
                    .offset(x: isHovered && enabled ? 2.0 : 0.0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9.5)
            .background(isHovered && enabled ? StudioTheme.hoverFill : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Flagship Monochrome Hero Pill Button (White on Dark / Black on Light)

struct StudioPrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13.5, weight: .semibold))
            .tracking(0.1)
            .foregroundStyle(StudioTheme.onPrimaryButton.opacity(isDisabled ? 0.55 : 0.98))
            .frame(width: 224, height: 40)
            .background(
                ZStack {
                    Capsule(style: .continuous)
                        .fill(
                            StudioTheme.textPrimary.opacity(
                                isDisabled ? 0.24 : (configuration.isPressed ? 0.84 : (isHovered ? 1.0 : 0.94))
                            )
                        )

                    if isHovered && !isDisabled {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        StudioTheme.prismBlue.opacity(0.50),
                                        StudioTheme.prismGreen.opacity(0.35),
                                        StudioTheme.prismYellow.opacity(0.35),
                                        StudioTheme.prismRed.opacity(0.40),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.0
                            )
                    }
                }
            )
            .shadow(
                color: colorScheme == .dark
                    ? Color.white.opacity(isHovered && !isDisabled ? 0.14 : 0.05)
                    : Color.black.opacity(isHovered && !isDisabled ? 0.20 : 0.10),
                radius: isHovered ? 16 : 8,
                x: 0,
                y: colorScheme == .dark ? 2 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.976 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.16), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Quiet Minimal Ghost Text Button

struct StudioGhostTextButtonStyle: ButtonStyle {
    var tint: Color = StudioTheme.textTertiary
    var hoverTint: Color = StudioTheme.textPrimary
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(
                !isEnabled
                    ? StudioTheme.textTertiary.opacity(0.35)
                    : (isHovered ? hoverTint : tint)
            )
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(isHovered && isEnabled ? StudioTheme.hoverFill : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.14), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Titlebar Chrome Icon Button

struct ChromeIconButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isHovered ? StudioTheme.textPrimary : StudioTheme.textTertiary)
            .frame(width: 26, height: 26)
            .background(
                Circle()
                    .fill(configuration.isPressed ? StudioTheme.controlTrack : (isHovered ? StudioTheme.hoverFill : Color.clear))
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.14), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
