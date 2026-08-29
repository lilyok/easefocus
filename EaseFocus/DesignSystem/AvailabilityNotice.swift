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
            if availability.canOpenAppleIntelligenceSettings, let url = AppleIntelligenceSettingsURL.make() {
                Link("Open Apple Intelligence & Siri", destination: url)
                    .font(FocusTypography.body)
                    .accessibilityIdentifier("openAppleIntelligenceSettings")
            }
        }
        .frame(minHeight: FocusSpacing.minimumTapTarget, alignment: .leading)
        .accessibilityElement(children: availability.canOpenAppleIntelligenceSettings ? .contain : .combine)
    }
}

#Preview("Turned off") {
    AvailabilityNotice(availability: .unavailable(.appleIntelligenceNotEnabled))
        .padding()
}

#Preview("Ineligible") {
    AvailabilityNotice(availability: .unavailable(.deviceNotEligible))
        .padding()
}
