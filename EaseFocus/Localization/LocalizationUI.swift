import SwiftUI

extension Text {
    init(_ copy: LocalizedCopy) {
        self.init(copy.resource)
    }
}

extension Button where Label == Text {
    init(_ title: LocalizedCopy, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.init(role: role, action: action) {
            Text(title)
        }
    }
}

extension Button where Label == SwiftUI.Label<Text, Image> {
    init(_ title: LocalizedCopy, systemImage: String, action: @escaping () -> Void) {
        self.init(action: action) {
            SwiftUI.Label(title, systemImage: systemImage)
        }
    }
}

extension Label where Title == Text, Icon == Image {
    init(_ title: LocalizedCopy, systemImage: String) {
        self.init {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

extension View {
    func accessibilityLabel(_ copy: LocalizedCopy) -> some View {
        accessibilityLabel(copy.resource)
    }

    func accessibilityHint(_ copy: LocalizedCopy) -> some View {
        accessibilityHint(copy.resource)
    }

    func accessibilityValue(_ copy: LocalizedCopy) -> some View {
        accessibilityValue(copy.resource)
    }

    func navigationTitle(_ copy: LocalizedCopy) -> some View {
        navigationTitle(Text(copy))
    }
}

extension ProgressView where Label == Text, CurrentValueLabel == EmptyView {
    init(_ title: LocalizedCopy) {
        self.init {
            Text(title)
        }
    }
}

extension Toggle where Label == Text {
    init(_ title: LocalizedCopy, isOn: Binding<Bool>) {
        self.init(isOn: isOn) {
            Text(title)
        }
    }
}

extension TextField where Label == Text {
    init(_ copy: LocalizedCopy, text: Binding<String>, axis: Axis = .horizontal) {
        self.init(text: text, prompt: Text(copy), axis: axis) {
            Text(copy)
        }
    }
}

extension Link where Label == Text {
    init(_ title: LocalizedCopy, destination: URL) {
        self.init(destination: destination) {
            Text(title)
        }
    }
}
