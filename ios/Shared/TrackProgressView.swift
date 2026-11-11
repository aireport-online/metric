import SwiftUI

/// Eén baan van de atletiekbaan: een stadionvorm die begint op de startstreep (links op het
/// rechte stuk onderaan) en linksom loopt, zoals er op een echte baan gelopen wordt.
struct TrackLaneShape: Shape {
    /// Afstand van de buitenrand tot het midden van de baan.
    var inset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = max(rect.height / 2 - inset, 1)
        let leftX = rect.minX + rect.height / 2
        let rightX = max(rect.maxX - rect.height / 2, leftX)
        let midY = rect.midY

        path.move(to: CGPoint(x: leftX, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: rightX, y: rect.maxY - inset))
        // Rechterbocht: van onder, via rechts, naar boven.
        path.addRelativeArc(
            center: CGPoint(x: rightX, y: midY),
            radius: radius,
            startAngle: .degrees(90),
            delta: .degrees(-180)
        )
        path.addLine(to: CGPoint(x: leftX, y: rect.minY + inset))
        // Linkerbocht: van boven, via links, terug naar de streep.
        path.addRelativeArc(
            center: CGPoint(x: leftX, y: midY),
            radius: radius,
            startAngle: .degrees(-90),
            delta: .degrees(-180)
        )
        path.closeSubpath()
        return path
    }
}

/// De start-/finishstreep: een korte dwarsstreep over de banen op het startpunt.
struct FinishMarkShape: Shape {
    /// Gezamenlijke dikte van de banen.
    var depth: CGFloat
    var overhang: CGFloat = 4

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let x = rect.minX + rect.height / 2
        path.move(to: CGPoint(x: x, y: rect.maxY - depth - overhang))
        path.addLine(to: CGPoint(x: x, y: rect.maxY + overhang))
        return path
    }
}

struct TrackLane {
    /// 0…1 is één ronde; boven 1 loopt (op de buitenbaan) een tweede ronde in volt.
    var progress: Double
    var color: Color

    init(progress: Double, color: Color = Theme.tartan) {
        self.progress = progress
        self.color = color
    }
}

/// Voortgang als atletiekbaan: hooguit drie banen rond een stadionvorm, met in het midden
/// ruimte voor het cijfer. De banen lopen vol zodra de view verschijnt of de waarde verandert.
struct TrackProgressView<Center: View>: View {
    private let lanes: [TrackLane]
    private let laneWidth: CGFloat
    private let laneGap: CGFloat
    private let aspect: CGFloat
    private let goalReached: Bool
    private let center: Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = false

    /// - Parameters:
    ///   - lanes: van buiten naar binnen; alleen de eerste drie worden getekend.
    ///   - goalReached: kleurt de finishstreep volt.
    init(
        lanes: [TrackLane],
        laneWidth: CGFloat = 14,
        laneGap: CGFloat = 3,
        aspect: CGFloat = 2,
        goalReached: Bool = false,
        @ViewBuilder center: () -> Center
    ) {
        self.lanes = Array(lanes.prefix(3))
        self.laneWidth = laneWidth
        self.laneGap = laneGap
        self.aspect = aspect
        self.goalReached = goalReached
        self.center = center()
    }

    private var depth: CGFloat {
        CGFloat(lanes.count) * laneWidth + CGFloat(max(lanes.count - 1, 0)) * laneGap
    }

    var body: some View {
        ZStack {
            ForEach(Array(lanes.enumerated()), id: \.offset) { index, lane in
                laneView(index: index, lane: lane)
            }
            FinishMarkShape(depth: depth)
                .stroke(
                    goalReached && started ? Theme.volt : Theme.text,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .animation(reduceMotion ? nil : Theme.Motion.quick.delay(0.9), value: started)
                .animation(reduceMotion ? nil : Theme.Motion.quick, value: goalReached)
            center
                .padding(depth + 8)
        }
        .aspectRatio(aspect, contentMode: .fit)
        .onAppear {
            started = true
        }
    }

    private func laneView(index: Int, lane: TrackLane) -> some View {
        let inset = laneWidth / 2 + CGFloat(index) * (laneWidth + laneGap)
        let progress = started ? max(lane.progress, 0) : 0
        let animation: Animation? = reduceMotion
            ? nil
            : Theme.Motion.lap.delay(Double(index) * Theme.Motion.laneStagger)
        return ZStack {
            TrackLaneShape(inset: inset)
                .stroke(Theme.line, lineWidth: laneWidth)
            TrackLaneShape(inset: inset)
                .trim(from: 0, to: CGFloat(min(progress, 1)))
                .stroke(lane.color, style: StrokeStyle(lineWidth: laneWidth, lineCap: .round))
            if index == 0 {
                // Boven 100% loopt een tweede ronde in volt over de eerste.
                TrackLaneShape(inset: inset)
                    .trim(from: 0, to: CGFloat(min(max(progress - 1, 0), 1)))
                    .stroke(Theme.volt, style: StrokeStyle(lineWidth: laneWidth, lineCap: .round))
            }
        }
        .animation(animation, value: progress)
    }
}

extension TrackProgressView where Center == EmptyView {
    /// Baan zonder inhoud in het midden, bv. als miniatuur in een ranglijst.
    init(
        lanes: [TrackLane],
        laneWidth: CGFloat = 6,
        laneGap: CGFloat = 3,
        aspect: CGFloat = 2.6,
        goalReached: Bool = false
    ) {
        self.init(
            lanes: lanes,
            laneWidth: laneWidth,
            laneGap: laneGap,
            aspect: aspect,
            goalReached: goalReached,
            center: { EmptyView() }
        )
    }
}
