import SwiftUI

// Bouwstenen van de huisstijl die beide apps gebruiken: knoppen, kaarten en beweging.

// MARK: - Knoppen

/// Primaire knop: tartan (of volt) stadionvorm met inkt-tekst, krimpt bij indrukken.
struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = Theme.tartan
    var fullWidth = true
    var compact = false

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.metricText(compact ? 15 : 16, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.vertical, compact ? 9 : 14)
            .padding(.horizontal, compact ? 16 : 22)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(fill.opacity(isEnabled ? 1 : 0.35), in: Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Theme.Motion.tap, value: configuration.isPressed)
    }
}

/// Secundaire knop: verhoogd vlak met een dunne rand en krijtwitte tekst.
struct SecondaryButtonStyle: ButtonStyle {
    var fullWidth = false
    var compact = true
    var tint: Color = Theme.text

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.metricText(compact ? 15 : 16, weight: .medium))
            .foregroundStyle(tint.opacity(isEnabled ? 1 : 0.4))
            .padding(.vertical, compact ? 9 : 14)
            .padding(.horizontal, compact ? 16 : 22)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Theme.surfaceRaised, in: Capsule())
            .overlay(Capsule().stroke(Theme.lineStrong, lineWidth: 1))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(Theme.Motion.tap, value: configuration.isPressed)
    }
}

/// Voor kaarten en regels die je kunt aantikken: alleen de druk-feedback, verder geen opmaak.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Theme.Motion.tap, value: configuration.isPressed)
    }
}

// MARK: - Kaart

extension View {
    /// Kaart op het Baanvlak met straal 20.
    func metricCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }
}

// MARK: - Binnenkomst

/// Kaarten en lijstregels komen 12 pt omhoog met een fade, 60 ms na elkaar; hooguit zes,
/// de rest staat er direct. Bij "Verminder beweging" alleen een korte fade.
struct EntranceModifier: ViewModifier {
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 12)
            .onAppear {
                guard !shown else { return }
                if index >= Theme.Motion.maxStaggered {
                    shown = true
                } else if reduceMotion {
                    withAnimation(Theme.Motion.reduced) {
                        shown = true
                    }
                } else {
                    withAnimation(Theme.Motion.base.delay(Double(index) * Theme.Motion.listStagger)) {
                        shown = true
                    }
                }
            }
    }
}

extension View {
    func entrance(_ index: Int = 0) -> some View {
        modifier(EntranceModifier(index: index))
    }
}

// MARK: - Optellende cijfers

/// Tekst waarvan de getalswaarde meebeweegt met een animatie.
struct AnimatedNumberText: View, Animatable {
    var value: Double
    let format: (Double) -> String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format(value))
    }
}

/// Cijfer dat optelt naar zijn waarde (800 ms), tegelijk met de baan die volloopt.
/// Bij "Verminder beweging" staat de eindwaarde er direct.
struct CountUp: View {
    let value: Double
    var format: (Double) -> String = { String(Int($0.rounded())) }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    var body: some View {
        AnimatedNumberText(value: shown, format: format)
            .monospacedDigit()
            .onAppear {
                animate(to: value)
            }
            .onChange(of: value) { _, newValue in
                animate(to: newValue)
            }
    }

    private func animate(to target: Double) {
        if reduceMotion {
            shown = target
        } else {
            withAnimation(Theme.Motion.count) {
                shown = target
            }
        }
    }
}

// MARK: - Cijfer met eenheid

/// Groot cursief cijfer met de eenheid klein ernaast.
struct FigureText: View {
    let value: String
    var unit: String?
    var size: CGFloat = 32
    var tint: Color = Theme.text

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.metricNumber(size))
                .monospacedDigit()
                .foregroundStyle(tint)
            if let unit, !unit.isEmpty {
                Text(unit)
                    .font(.metricLabel(max(size * 0.42, 12)))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// Splitst "5,23 km" of "5:48 /km" in het getal en de eenheid.
func splitFigure(_ text: String) -> (value: String, unit: String?) {
    guard let space = text.firstIndex(of: " ") else {
        return (text, nil)
    }
    return (String(text[text.startIndex..<space]), String(text[text.index(after: space)...]))
}

// MARK: - Live-stip

/// De volt live-stip: het enige dat tijdens een opname doorlopend beweegt.
struct LiveDot: View {
    var isLive = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    var body: some View {
        Circle()
            .fill(isLive ? Theme.volt : Theme.textMuted)
            .frame(width: 8, height: 8)
            .opacity(isLive && dimmed ? 0.3 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    dimmed = true
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Startschot

/// 3, 2, 1 als grote baannummers. De aanroeper bepaalt het getal; dit toont alleen het cijfer.
struct CountdownNumber: View {
    let number: Int
    var size: CGFloat = 200

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("\(number)")
            .font(.metricNumber(size))
            .foregroundStyle(number == 1 ? Theme.volt : Theme.text)
            .id(number)
            .transition(transition)
            .accessibilityLabel("Start over \(number)")
    }

    private var transition: AnyTransition {
        if reduceMotion {
            return AnyTransition.opacity
        }
        return AnyTransition.asymmetric(
            insertion: AnyTransition.scale(scale: 1.5).combined(with: AnyTransition.opacity),
            removal: AnyTransition.scale(scale: 0.6).combined(with: AnyTransition.opacity)
        )
    }
}
