import SwiftUI

/// Smooth filled line chart for revenue overviews.
struct LineChartView: View {
    let values: [Double]
    var color: Color = Brand.purple
    var height: CGFloat = 140

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                // gridlines
                ForEach(0..<4) { i in
                    let y = geo.size.height / 3 * CGFloat(i)
                    Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: geo.size.width, y: y)) }
                        .stroke(Brand.border, lineWidth: 1)
                }
                // fill
                fillPath(pts, in: geo.size)
                    .fill(LinearGradient(colors: [color.opacity(0.22), color.opacity(0.0)],
                                         startPoint: .top, endPoint: .bottom))
                // line
                linePath(pts).stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                // end dot
                if let last = pts.last {
                    Circle().fill(color).frame(width: 8, height: 8).position(last)
                }
            }
        }
        .frame(height: height)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1, let mn = values.min(), let mx = values.max(), mx > mn else {
            return values.enumerated().map { CGPoint(x: size.width * CGFloat($0.offset) / CGFloat(max(1, values.count - 1)), y: size.height / 2) }
        }
        return values.enumerated().map { i, v in
            let x = size.width * CGFloat(i) / CGFloat(values.count - 1)
            let y = size.height * (1 - CGFloat((v - mn) / (mx - mn))) * 0.85 + size.height * 0.075
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(_ pts: [CGPoint]) -> Path {
        Path { p in
            guard let first = pts.first else { return }
            p.move(to: first)
            for pt in pts.dropFirst() { p.addLine(to: pt) }
        }
    }

    private func fillPath(_ pts: [CGPoint], in size: CGSize) -> Path {
        Path { p in
            guard let first = pts.first else { return }
            p.move(to: CGPoint(x: first.x, y: size.height))
            p.addLine(to: first)
            for pt in pts.dropFirst() { p.addLine(to: pt) }
            if let last = pts.last { p.addLine(to: CGPoint(x: last.x, y: size.height)) }
            p.closeSubpath()
        }
    }
}

/// Compact sparkline used inside small stat cards.
struct SparklineView: View {
    let values: [Double]
    var color: Color = Brand.purple

    var body: some View {
        GeometryReader { geo in
            Path { p in
                guard values.count > 1, let mn = values.min(), let mx = values.max(), mx > mn else { return }
                for (i, v) in values.enumerated() {
                    let x = geo.size.width * CGFloat(i) / CGFloat(values.count - 1)
                    let y = geo.size.height * (1 - CGFloat((v - mn) / (mx - mn)))
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Donut chart for category breakdowns.
struct DonutChartView: View {
    let slices: [CategorySlice]
    var size: CGFloat = 150

    var body: some View {
        ZStack {
            ForEach(Array(arcs().enumerated()), id: \.offset) { _, arc in
                Circle()
                    .trim(from: arc.start, to: arc.end)
                    .stroke(Color(hex: arc.color), style: StrokeStyle(lineWidth: 26, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Text("Total").font(.system(size: 11)).foregroundColor(Brand.textSecondary)
                Text("R86,420").font(.system(size: 15, weight: .bold)).foregroundColor(Brand.textPrimary)
            }
        }
        .frame(width: size, height: size)
    }

    private func arcs() -> [(start: CGFloat, end: CGFloat, color: String)] {
        let total = slices.reduce(0) { $0 + $1.percentage }
        guard total > 0 else { return [] }
        var cursor: CGFloat = 0
        return slices.map { s in
            let frac = CGFloat(s.percentage / total)
            let arc = (start: cursor, end: cursor + frac, color: s.colorHex)
            cursor += frac
            return arc
        }
    }
}
