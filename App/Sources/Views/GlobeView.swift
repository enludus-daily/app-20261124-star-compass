import SwiftUI

/// 真鍮の地球儀：陸を打った点で描く正射図法。指で回し、軽く触れた所にピンを刺す。
/// 答えのあとは、正解（金の星）と自分の答え（青いピン）の間に大円の弧を引く
struct GlobeView: View {
    let center: GeoPoint
    var pin: GeoPoint?
    var truth: GeoPoint?
    /// 弧の伸び（0〜1）
    var arc: Double = 1
    var interactive = true
    var onTurn: ((GeoPoint) -> Void)?
    var onPin: ((GeoPoint) -> Void)?

    @State private var dragStart: GeoPoint?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Canvas { ctx, size in draw(&ctx, size: size) }
                .frame(width: side, height: side)
                .contentShape(Circle())
                .gesture(interactive ? globeGesture(side: side) : nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(tr("地球儀。回して、触れた所に答えのピンを刺す", "Globe. Spin it and tap to drop your pin."))
        .accessibilityIdentifier("main.globe")
    }

    private func globeGesture(side: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let moved = hypot(v.translation.width, v.translation.height)
                guard moved > 6 else { return }
                let start = dragStart ?? center
                if dragStart == nil { dragStart = center }
                let R = side / 2 * 0.9
                let k = 57.3 / R
                let lat = max(-80, min(80, start.lat + v.translation.height * k))
                let lon = start.lon - v.translation.width * k
                onTurn?(GeoPoint(lat: lat, lon: (lon + 540).truncatingRemainder(dividingBy: 360) - 180))
            }
            .onEnded { v in
                defer { dragStart = nil }
                guard hypot(v.translation.width, v.translation.height) <= 6 else { return }
                let R = side / 2 * 0.9
                let x = (v.location.x - side / 2) / R, y = (v.location.y - side / 2) / R
                if let g = Earth.inverseOrtho(x: x, y: y, lat0: center.lat, lon0: center.lon) {
                    onPin?(GeoPoint(lat: g.lat, lon: g.lon))
                }
            }
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let side = min(size.width, size.height)
        let R = side / 2 * 0.9
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        func pt(_ lat: Double, _ lon: Double) -> CGPoint? {
            guard let p = Earth.ortho(lat: lat, lon: lon, lat0: center.lat, lon0: center.lon) else { return nil }
            return CGPoint(x: c.x + p.x * R, y: c.y + p.y * R)
        }
        // 子午線の輪（地球儀の台の真鍮の半円）
        let stand = R * 1.08
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - stand, y: c.y - stand, width: stand * 2, height: stand * 2)), with: .linearGradient(Gradient(colors: [Ink.brassLight, Ink.brassDeep]), startPoint: CGPoint(x: c.x, y: c.y - stand), endPoint: CGPoint(x: c.x, y: c.y + stand)), lineWidth: R * 0.035)
        for k in 0..<24 {
            let a = Double(k) * .pi / 12
            var tick = Path()
            tick.move(to: CGPoint(x: c.x + (stand - R * 0.02) * cos(a), y: c.y + (stand - R * 0.02) * sin(a)))
            tick.addLine(to: CGPoint(x: c.x + (stand + R * 0.02) * cos(a), y: c.y + (stand + R * 0.02) * sin(a)))
            ctx.stroke(tick, with: .color(Ink.brassShadow), lineWidth: 0.8)
        }

        let disk = Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: R * 2, height: R * 2))
        ctx.fill(disk, with: .radialGradient(Gradient(colors: [Ink.oceanLight, Ink.ocean, Ink.nightDeep]), center: CGPoint(x: c.x - R * 0.3, y: c.y - R * 0.35), startRadius: 0, endRadius: R * 1.35))

        // 経線・緯線（30° ごと）
        var grid = Path()
        for lat in stride(from: -60.0, through: 60, by: 30) {
            var open = false
            for lon in stride(from: -180.0, through: 180, by: 5) {
                if let p = pt(lat, lon) { if open { grid.addLine(to: p) } else { grid.move(to: p); open = true } } else { open = false }
            }
        }
        for lon in stride(from: -180.0, to: 180, by: 30) {
            var open = false
            for lat in stride(from: -90.0, through: 90, by: 5) {
                if let p = pt(lat, lon) { if open { grid.addLine(to: p) } else { grid.move(to: p); open = true } } else { open = false }
            }
        }
        ctx.stroke(grid, with: .color(Ink.brass.opacity(0.22)), lineWidth: 0.6)

        // 陸（真鍮の点。縁ほど暗く）
        let dot = max(1.1, R * 0.021)
        for d in Land.cached {
            guard let p = Earth.ortho(lat: d.lat, lon: d.lon, lat0: center.lat, lon0: center.lon) else { continue }
            let depth = sqrt(max(0, 1 - p.x * p.x - p.y * p.y))
            let q = CGPoint(x: c.x + p.x * R, y: c.y + p.y * R)
            let s = dot * (0.55 + 0.45 * depth)
            ctx.fill(Path(ellipseIn: CGRect(x: q.x - s, y: q.y - s, width: s * 2, height: s * 2)), with: .color(Ink.brassLight.opacity(0.35 + 0.6 * depth)))
        }

        // 光の当たり方（球に見せる）
        ctx.fill(disk, with: .radialGradient(Gradient(colors: [.white.opacity(0.10), .clear, .black.opacity(0.35)]), center: CGPoint(x: c.x - R * 0.35, y: c.y - R * 0.4), startRadius: 0, endRadius: R * 1.5))
        ctx.stroke(disk, with: .color(Ink.brass.opacity(0.8)), lineWidth: 1)

        // 弧
        if let pin, let truth {
            var path = Path()
            var open = false
            let steps = 64
            let upto = Int(Double(steps) * max(0, min(1, arc)))
            if upto > 0 {
                for i in 0...upto {
                    let g = Earth.interpolate(lat1: truth.lat, lon1: truth.lon, lat2: pin.lat, lon2: pin.lon, t: Double(i) / Double(steps))
                    if let p = pt(g.lat, g.lon) { if open { path.addLine(to: p) } else { path.move(to: p); open = true } } else { open = false }
                }
                ctx.stroke(path, with: .color(Ink.truth.opacity(0.95)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4]))
            }
        }
        if let truth, let p = pt(truth.lat, truth.lon) {
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .radialGradient(Gradient(colors: [Ink.truth.opacity(0.7), .clear]), center: p, startRadius: 0, endRadius: 9))
            ctx.fill(star(at: p, r: 6.5), with: .color(Ink.truth))
        }
        if let pin, let p = pt(pin.lat, pin.lon) {
            // ピン：針と頭
            var needle = Path()
            needle.move(to: p)
            needle.addLine(to: CGPoint(x: p.x, y: p.y - 16))
            ctx.stroke(needle, with: .color(Ink.brassLight), lineWidth: 1.5)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 22, width: 12, height: 12)), with: .color(Ink.guess))
            ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 22, width: 12, height: 12)), with: .color(Ink.nightDeep), lineWidth: 1)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(Ink.nightDeep))
        }
    }

    private func star(at p: CGPoint, r: CGFloat) -> Path {
        var path = Path()
        for i in 0..<10 {
            let a = Double(i) * .pi / 5 - .pi / 2
            let rr = i % 2 == 0 ? r : r * 0.45
            let q = CGPoint(x: p.x + rr * cos(a), y: p.y + rr * sin(a))
            if i == 0 { path.move(to: q) } else { path.addLine(to: q) }
        }
        path.closeSubpath()
        return path
    }
}

/// 月の目盛り（真鍮の定規。12 の刻み）
struct MonthDial: View {
    let selected: Int?
    var truth: Int?
    var onPick: ((Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tr("何月の空？", "Which month?"))
                .font(Face.label(12))
                .foregroundStyle(Ink.brassLight)
                .tracking(1.2)
            HStack(spacing: 3) {
                ForEach(1...12, id: \.self) { m in
                    Button { onPick?(m) } label: {
                        VStack(spacing: 2) {
                            Rectangle().fill(m % 3 == 0 ? Ink.brassLight : Ink.brass.opacity(0.7)).frame(width: 1, height: m % 3 == 0 ? 8 : 5)
                            Text(Lang.isJapanese ? "\(m)" : String(Lore.monthShort(m).prefix(1)))
                                .font(Face.engraved(13))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                        .foregroundStyle(selected == m ? Ink.nightDeep : (truth == m ? Ink.truth : Ink.ivory))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selected == m ? AnyShapeStyle(Ink.brassGradient) : AnyShapeStyle(Ink.nightSoft.opacity(0.7)))
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(truth == m ? Ink.truth : Ink.brass.opacity(0.35), lineWidth: truth == m ? 1.5 : 0.5))
                                .allowsHitTesting(false)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(onPick == nil)
                    .accessibilityLabel(Lore.monthName(m))
                    .accessibilityIdentifier("month.\(m)")
                }
            }
            if !Lang.isJapanese, let selected {
                Text(Lore.monthName(selected)).font(Face.label(11)).foregroundStyle(Ink.mist)
            }
        }
    }
}

/// グリニッジの時計（24 時間の文字盤。真鍮）
struct BrassClock: View {
    let hours: Double

    var body: some View {
        Canvas { ctx, size in
            let r = min(size.width, size.height) / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let face = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.fill(face, with: .radialGradient(Gradient(colors: [Ink.nightSoft, Ink.nightDeep]), center: c, startRadius: 0, endRadius: r))
            ctx.stroke(face.strokedPath(StrokeStyle(lineWidth: r * 0.12)), with: .linearGradient(Gradient(colors: [Ink.brassLight, Ink.brassDeep]), startPoint: CGPoint(x: c.x, y: c.y - r), endPoint: CGPoint(x: c.x, y: c.y + r)))
            for h in 0..<24 {
                let a = Double(h) / 24 * 2 * .pi - .pi / 2
                let long = h % 6 == 0
                var t = Path()
                t.move(to: CGPoint(x: c.x + r * 0.8 * cos(a), y: c.y + r * 0.8 * sin(a)))
                t.addLine(to: CGPoint(x: c.x + r * (long ? 0.6 : 0.7) * cos(a), y: c.y + r * (long ? 0.6 : 0.7) * sin(a)))
                ctx.stroke(t, with: .color(Ink.brassLight.opacity(long ? 1 : 0.6)), lineWidth: long ? 1.4 : 0.7)
            }
            // 24 時間で 1 周（上が 0 時）
            let a = hours / 24 * 2 * .pi - .pi / 2
            var hand = Path()
            hand.move(to: c)
            hand.addLine(to: CGPoint(x: c.x + r * 0.66 * cos(a), y: c.y + r * 0.66 * sin(a)))
            ctx.stroke(hand, with: .color(Ink.truth), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 2.5, y: c.y - 2.5, width: 5, height: 5)), with: .color(Ink.brassLight))
        }
        .accessibilityHidden(true)
    }
}
