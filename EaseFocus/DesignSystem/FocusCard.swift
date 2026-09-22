import SwiftUI

extension View {
    func focusCard() -> some View {
        padding(FocusSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.focusSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    func focusScreen() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.focusBackground)
    }

    func focusField() -> some View {
        textFieldStyle(.plain)
            .font(FocusTypography.body)
            .foregroundStyle(Color.focusPrimary)
            .padding(.vertical, 4)
    }

    func focusCapsuleFill(_ fill: Color = Color.focusAccent, enabled: Bool = true) -> some View {
        font(.footnote.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: FocusSpacing.minimumTapTarget)
            .background {
                Capsule()
                    .fill(FocusChrome.gradient(matching: fill, enabled: enabled))
            }
            .contentShape(Capsule())
    }

    func focusListRow() -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(
                top: FocusSpacing.small,
                leading: FocusSpacing.medium,
                bottom: FocusSpacing.small,
                trailing: FocusSpacing.medium
            ))
    }
}

enum FocusChrome {
    enum Kind {
        case accent
        case destructive
    }

    static let accentStart = Color(red: 0.98, green: 0.80, blue: 0.22)
    static let accentEnd = Color(red: 0.90, green: 0.42, blue: 0.08)
    static let destructiveStart = Color(red: 0.96, green: 0.45, blue: 0.28)
    static let destructiveEnd = Color(red: 0.68, green: 0.10, blue: 0.16)

    static func kind(for fill: Color) -> Kind {
        fill == Color.focusError ? .destructive : .accent
    }

    static func gradient(for kind: Kind, enabled: Bool = true) -> LinearGradient {
        let colors: [Color]
        switch kind {
        case .accent:
            colors = [accentStart, accentEnd]
        case .destructive:
            colors = [destructiveStart, destructiveEnd]
        }
        return LinearGradient(
            colors: colors.map { $0.opacity(enabled ? 1 : 0.4) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func gradient(matching fill: Color, enabled: Bool = true) -> LinearGradient {
        gradient(for: kind(for: fill), enabled: enabled)
    }
}

struct FocusIconButton: View {
    let title: LocalizedCopy
    let systemImage: String
    var identifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(FocusChrome.gradient(for: .accent))
                .frame(width: FocusSpacing.minimumTapTarget, height: FocusSpacing.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(FocusCapsuleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier ?? "")
    }
}

/// Makes the whole capsule the hit target. On macOS, `.plain` buttons otherwise only
/// register clicks on the label glyphs.
struct FocusCapsuleButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Capsule())
            .onTapGesture(perform: configuration.trigger)
    }
}

struct FocusScreenStack<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FocusSpacing.medium) {
                content()
            }
            .padding(.horizontal, FocusSpacing.medium)
            .padding(.vertical, FocusSpacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .focusScreen()
    }
}

struct FocusSectionHeader: View {
    let title: LocalizedCopy

    var body: some View {
        Text(title)
            .font(FocusTypography.footnote)
            .foregroundStyle(.secondary)
    }
}

struct FocusCapsuleButton: View {
    let title: LocalizedCopy
    var fill: Color = Color.focusAccent
    var enabled: Bool = true
    var identifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .focusCapsuleFill(fill, enabled: enabled)
        }
        .buttonStyle(FocusCapsuleButtonStyle())
        .disabled(!enabled)
        .accessibilityIdentifier(identifier ?? "")
    }
}

struct PlanNameLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(PlanLabelColor.color(for: title), in: Capsule())
            .accessibilityLabel(title)
    }
}

enum PlanLabelColor {
    static let palette: [Color] = [
        Color(red: 0.29, green: 0.40, blue: 0.96),
        Color(red: 0.45, green: 0.32, blue: 0.90),
        Color(red: 0.18, green: 0.52, blue: 0.84),
        Color(red: 0.78, green: 0.28, blue: 0.37),
        Color(red: 0.12, green: 0.56, blue: 0.47),
        Color(red: 0.90, green: 0.45, blue: 0.13),
    ]

    static func color(for title: String) -> Color {
        let key = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let index = key.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[abs(index) % palette.count]
    }
}

enum PomodoroTaskSearch {
    static func matches(_ task: PlanTask, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else {
            return true
        }
        if task.title.localizedCaseInsensitiveContains(needle) {
            return true
        }
        if let planTitle = task.plan?.title, planTitle.localizedCaseInsensitiveContains(needle) {
            return true
        }
        return false
    }
}
