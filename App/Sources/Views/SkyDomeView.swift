import SwiftUI

/// 天球：天頂を中心に、地平線までの全天を円で描く。真鍮の縁つき。指で回せる
struct SkyDomeView: View {
    let question: Question
    var turn: Double = 0
    var hints: Set<Hint> = []
    var hard = false
    /// 読み方の札で光らせる星座（線を金で描く）
    var highlight: [String] = []
    var still = false
    var interactive = true
    var onTurn: ((Double) -> Void)?

    @State private var dragAngle: Double?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            TimelineView(.animation(minimumInterval: 1.0 / 12, paused: still)) { tl in
                let t = still ? 0 : tl.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    draw(&ctx, size: size, time: t)
                }
            }
            .frame(width: side, height: side)
            .contentShape(Circle())
            .gesture(interactive ? rotateGesture(side: side) : nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(tr("夜空。指で回せる", "Night sky. Drag to turn it."))
    }

    private func rotateGesture(side: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { v in
                let c = CGPoint(x: side / 2, y: side / 2)
                let a = atan2(v.location.y - c.y, v.location.x - c.x) * 180 / .pi
                if let prev = dragAngle {
                    var d = a - prev
                    if d > 180 { d -= 360 }
                    if d < -180 { d += 360 }
                    onTurn?(-d)
                }
                dragAngle = a
            }
            .onEnded { _ in dragAngle = nil }
    }

    // MARK: - 描く

    private static let warm: Set<String> = ["Ori.a", "Sco.a", "Tau.a", "Boo.a", "Cet.o", "Her.a", "Peg.b", "Cru.g", "Gru.b", "Hya.a"]
    private static let cool: Set<String> = ["Lyr.a", "CMa.a", "Ori.b", "Vir.a", "Cru.a", "Cru.b", "Cen.b", "Eri.a", "Leo.a", "Aqr.a"]

    private func draw(_ ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let side = min(size.width, size.height)
        let bezel = side * 0.055
        let R = side / 2 - bezel
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let rotation = question.rotation + turn
        func point(_ alt: Double, _ az: Double) -> CGPoint {
            let p = Sky.dome(alt: alt, az: az, rotation: rotation)
            return CGPoint(x: c.x + p.x * R, y: c.y + p.y * R)
        }
        let disk = Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: R * 2, height: R * 2))

        // 空の地（天頂は深く、地平線へ向けて少し明るい）
        ctx.fill(disk, with: .radialGradient(Gradient(colors: [Ink.nightDeep, Ink.night, Ink.nightSoft]), center: c, startRadius: 0, endRadius: R))

        var sky = ctx
        sky.clip(to: disk)

        // 高度の目盛り（30°・60°）
        for alt in [30.0, 60.0] {
            let r = R * (90 - alt) / 90
            sky.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Ink.nightLine.opacity(0.55)), style: StrokeStyle(lineWidth: 0.6, dash: [2, 5]))
        }

        // 天の川
        let mw = StarCatalog.milkyWay(step: 4)
        let strong = hints.contains(.milkyWay)
        var band = Path()
        var open = false
        for p in mw {
            let h = question.horizontal(ra: p.ra, dec: p.dec)
            if h.alt > -8 {
                let pt = point(h.alt, h.az)
                if open { band.addLine(to: pt) } else { band.move(to: pt); open = true }
            } else {
                open = false
            }
        }
        sky.drawLayer { layer in
            layer.addFilter(.blur(radius: R * 0.06))
            layer.stroke(band, with: .color(Ink.mist.opacity(strong ? 0.34 : 0.10)), style: StrokeStyle(lineWidth: R * (strong ? 0.2 : 0.15), lineCap: .round, lineJoin: .round))
            layer.stroke(band, with: .color(Ink.starlight.opacity(strong ? 0.22 : 0.05)), style: StrokeStyle(lineWidth: R * 0.06, lineCap: .round, lineJoin: .round))
        }

        // 星座の線
        let showLines = hints.contains(.lines) && !hard
        if showLines || !highlight.isEmpty {
            for con in StarCatalog.constellations {
                let lit = highlight.contains(con.key)
                guard showLines || lit else { continue }
                var path = Path()
                for (a, b) in StarCatalog.lineStars(con) {
                    let ha = question.horizontal(a), hb = question.horizontal(b)
                    guard ha.alt > -2, hb.alt > -2 else { continue }
                    path.move(to: point(ha.alt, ha.az))
                    path.addLine(to: point(hb.alt, hb.az))
                }
                sky.stroke(path, with: .color(lit ? Ink.truth.opacity(0.9) : Ink.brass.opacity(0.5)), lineWidth: lit ? 1.4 : 0.8)
            }
        }

        // 星（等級で大きさと明るさ。ゆっくりまたたく）
        let scale = side / 360
        for (i, s) in StarCatalog.stars.enumerated() {
            if hard && s.mag > 3.0 { continue }
            let h = question.horizontal(s)
            guard h.alt > 0 else { continue }
            let p = point(h.alt, h.az)
            // 地平線の近くは暗く見える
            let ext = h.alt < 12 ? 0.45 + 0.55 * h.alt / 12 : 1
            let twinkle = time == 0 ? 1 : 0.82 + 0.18 * sin(time * (1.3 + Double(i % 7) * 0.21) + Double(i))
            let r = max(0.7, (5.0 - s.mag) * 0.62) * scale
            let a = min(1, max(0.28, (5.6 - s.mag) / 4.2)) * ext * twinkle
            let tint = Self.warm.contains(s.key) ? Color(hex: 0xFFC890) : (Self.cool.contains(s.key) ? Color(hex: 0xCFE2FF) : Ink.starlight)
            if s.mag < 1.6 {
                let g = r * 3.2
                sky.fill(Path(ellipseIn: CGRect(x: p.x - g, y: p.y - g, width: g * 2, height: g * 2)),
                         with: .radialGradient(Gradient(colors: [tint.opacity(0.35 * a), .clear]), center: p, startRadius: 0, endRadius: g))
            }
            sky.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(tint.opacity(a)))
        }

        // 星座の名札（線のヒントのときだけ）
        if showLines {
            for con in StarCatalog.constellations {
                let ctr = StarCatalog.center(con)
                let h = question.horizontal(ra: ctr.ra, dec: ctr.dec)
                guard h.alt > 14 else { continue }
                let p = point(h.alt, h.az)
                let name = Lang.isJapanese ? con.ja.replacingOccurrences(of: "座", with: "").components(separatedBy: "（").first ?? con.ja : con.en.components(separatedBy: " (").first ?? con.en
                sky.draw(Text(name).font(.system(size: max(8, side * 0.026), weight: .medium, design: .serif)).foregroundStyle(Ink.brassLight.opacity(0.85)), at: CGPoint(x: p.x, y: p.y + side * 0.03))
            }
        }

        // 地平線の霞
        sky.stroke(disk, with: .color(Ink.mist.opacity(0.15)), lineWidth: R * 0.08)

        // 真鍮の縁
        let outer = R + bezel
        let ring = Path(ellipseIn: CGRect(x: c.x - outer + bezel / 2, y: c.y - outer + bezel / 2, width: (outer - bezel / 2) * 2, height: (outer - bezel / 2) * 2))
        ctx.stroke(ring, with: .linearGradient(Gradient(colors: [Ink.brassLight, Ink.brass, Ink.brassDeep, Ink.brass]), startPoint: CGPoint(x: c.x - outer, y: c.y - outer), endPoint: CGPoint(x: c.x + outer, y: c.y + outer)), lineWidth: bezel)
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: R * 2, height: R * 2)), with: .color(Ink.brassShadow), lineWidth: 1.2)
        // 縁の目盛り（10° ごと。空と一緒に回る）
        for k in 0..<36 {
            let az = Double(k) * 10
            let a = (az + rotation) * .pi / 180
            let long = k % 9 == 0
            let r1 = R + bezel * 0.15, r2 = R + bezel * (long ? 0.7 : 0.4)
            var tick = Path()
            tick.move(to: CGPoint(x: c.x - r1 * sin(a), y: c.y - r1 * cos(a)))
            tick.addLine(to: CGPoint(x: c.x - r2 * sin(a), y: c.y - r2 * cos(a)))
            ctx.stroke(tick, with: .color(Ink.brassShadow.opacity(0.9)), lineWidth: long ? 1.4 : 0.7)
        }
        // 方角（ヒント）
        if hints.contains(.compass) {
            let labels: [(Double, String)] = Lang.isJapanese ? [(0, "北"), (90, "東"), (180, "南"), (270, "西")] : [(0, "N"), (90, "E"), (180, "S"), (270, "W")]
            for (az, s) in labels {
                let a = (az + rotation) * .pi / 180
                let r = R - side * 0.045
                let p = CGPoint(x: c.x - r * sin(a), y: c.y - r * cos(a))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - side * 0.03, y: p.y - side * 0.03, width: side * 0.06, height: side * 0.06)), with: .color(Ink.nightDeep.opacity(0.8)))
                ctx.draw(Text(s).font(.system(size: side * 0.038, weight: .bold, design: .serif)).foregroundStyle(az == 0 ? Ink.truth : Ink.brassLight), at: p)
            }
        }
    }
}
