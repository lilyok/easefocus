import SwiftUI

struct AvailabilityNotice: View {
    let availability: FoundationModelAvailability

    var body: some View {
        VStack(alignment: .leading, spacing: FocusSpacing.small) {
            Text(FoundationModelAvailabilityCopy.title(for: availability))
                .font(FocusTypography.title)
                .foregroundStyle(Color.focusPrimary)
            Text(FoundationModelAvailabilityCopy.message(for: availability))
                .font(FocusTypography.body)
        }
        .frame(minHeight: FocusSpacing.minimumTapTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    AvailabilityNotice(availability: .unavailable(.deviceNotEligible))
        .padding()
}
