import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Dynamic Island + Lock Screen dose countdown, in PharmEye's paper/maroon palette.
/// (Custom fonts aren't available to widgets, so this uses the rounded system face.)
struct DoseLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DoseActivityAttributes.self) { context in
            LockScreenDoseView(state: context.state)
                .activityBackgroundTint(Palette.paper)
                .activitySystemActionForegroundColor(Palette.mar)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: s.taken ? "checkmark.circle.fill" : "pill.fill")
                        .font(.title2).foregroundStyle(Palette.gold2)
                        .padding(.leading, 4)
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(state: s).font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Palette.gold2)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text("\(s.medicineName) \(s.strength)").font(.headline).foregroundStyle(.white).lineLimit(1)
                        Text("\(s.doseAmount) · \(s.label)").font(.caption).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if s.taken {
                        Text(s.dosesLeftToday == 0 ? "All done for today" : "Logged · \(s.dosesLeftToday) left today")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.gold2)
                    } else {
                        Button(intent: MarkDoseTakenIntent(medicineID: s.medicineID)) {
                            Label("Mark Taken", systemImage: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.gold2)
                        .foregroundStyle(Palette.night)
                    }
                }
            } compactLeading: {
                Image(systemName: s.taken ? "checkmark.circle.fill" : "pill.fill")
                    .foregroundStyle(Palette.gold2)
                    .accessibilityLabel(s.medicineName)
            } compactTrailing: {
                Countdown(state: s).font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Palette.gold2)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "pill.fill").foregroundStyle(Palette.gold2)
                    .accessibilityLabel("Next dose: \(s.medicineName)")
            }
            .keylineTint(Palette.gold2)
        }
    }
}

/// "in 23:14" counting down to the dose, or "Due" once its time has come.
private struct Countdown: View {
    let state: DoseActivityAttributes.ContentState
    var body: some View {
        if state.taken {
            Text("Taken")
        } else if state.dueAt > .now {
            Text(timerInterval: Date.now...state.dueAt, countsDown: true)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel("Due \(state.dueAt.formatted(date: .omitted, time: .shortened))")
        } else {
            Text("Due")
        }
    }
}

private struct LockScreenDoseView: View {
    let state: DoseActivityAttributes.ContentState
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: state.taken ? "checkmark.circle.fill" : "pill.fill")
                .font(.title2).foregroundStyle(Palette.cream)
                .frame(width: 46, height: 46)
                .background(Palette.mar, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(state.taken ? "Dose logged" : "Next dose")
                    .font(.caption.weight(.bold)).foregroundStyle(Palette.rose).textCase(.uppercase)
                Text("\(state.medicineName) \(state.strength)")
                    .font(.headline).foregroundStyle(Palette.ink).lineLimit(1)
                Text("\(state.doseAmount) · \(state.label) · \(state.dueAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(Palette.mar2).lineLimit(1)
            }
            Spacer(minLength: 8)
            if state.taken {
                Text(state.dosesLeftToday == 0 ? "All done" : "\(state.dosesLeftToday) left")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.mar)
            } else {
                Button(intent: MarkDoseTakenIntent(medicineID: state.medicineID)) {
                    Text("Taken").font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.mar)
                .foregroundStyle(Palette.cream)
                .accessibilityLabel("Mark \(state.medicineName) taken")
            }
        }
        .padding(16)
        .accessibilityElement(children: .contain)
    }
}

/// The handful of PharmEye palette colours the widget needs (Theme.swift lives in the app).
private enum Palette {
    static let paper = Color(red: 0xEF / 255, green: 0xE3 / 255, blue: 0xCB / 255)
    static let cream = Color(red: 0xFB / 255, green: 0xF4 / 255, blue: 0xE4 / 255)
    static let ink   = Color(red: 0x3A / 255, green: 0x0F / 255, blue: 0x1A / 255)
    static let mar   = Color(red: 0x6A / 255, green: 0x1B / 255, blue: 0x2D / 255)
    static let mar2  = Color(red: 0x8A / 255, green: 0x2B / 255, blue: 0x3A / 255)
    static let rose  = Color(red: 0x9A / 255, green: 0x39 / 255, blue: 0x33 / 255)
    static let gold2 = Color(red: 0xE6 / 255, green: 0xC1 / 255, blue: 0x6A / 255)
    static let night = Color(red: 0x2A / 255, green: 0x12 / 255, blue: 0x20 / 255)
}
