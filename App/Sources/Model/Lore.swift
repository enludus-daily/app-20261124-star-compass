import Foundation

/// 空の読み方の札（12 枚）。問題に当てはまる読み方を、答えのあとに 1 枚見せる。初めて見た札は集まる
enum Lore: String, CaseIterable, Codable, Sendable, Identifiable {
    case clock, polaris, dipper, crux, southPole, canopus, zenith, orion, leo, scorpius, triangle, pegasus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clock: tr("時計の差は経度", "Clock gap = longitude")
        case .polaris: tr("北極星の高さは緯度", "Polaris height = latitude")
        case .dipper: tr("沈まない北斗七星", "The Dipper never sets")
        case .crux: tr("南十字が見えたら南", "See the Cross, go south")
        case .southPole: tr("南十字で天の南極", "Cross points to the pole")
        case .canopus: tr("カノープスは南の印", "Canopus means south")
        case .zenith: tr("頭の上の星は緯度", "Overhead star = latitude")
        case .orion: tr("オリオンは冬の夜", "Orion: Dec–Feb nights")
        case .leo: tr("しし座は春の夜", "Leo: Mar–May nights")
        case .scorpius: tr("さそり座は夏の夜", "Scorpius: Jun–Aug nights")
        case .triangle: tr("大三角は夏の終わり", "Summer Triangle: Aug–Oct")
        case .pegasus: tr("四辺形は秋の夜", "Great Square: Oct–Dec")
        }
    }

    /// どの問題にも言える一言
    var rule: String {
        switch self {
        case .clock: tr("この空はいつもその土地の夜 10 時ごろ。グリニッジの時計との差 1 時間ごとに、経度が 15° ずれる。", "This sky is always about 10 p.m. local time. Each hour of gap from the Greenwich clock is 15° of longitude.")
        case .polaris: tr("北極星は天の北極のすぐそば。地平線からの高さが、そのまま北緯になる。", "Polaris sits by the north celestial pole. Its height above the horizon is your latitude.")
        case .dipper: tr("北斗七星の柄の先まで一晩中沈まないのは、北緯 41° より北。", "If the whole Big Dipper stays above the horizon, you are north of 41°N.")
        case .crux: tr("南十字は北緯 27° より北ではほとんど見えない。見えたら南の国。", "The Southern Cross hides north of about 27°N. Seeing it means you are far south.")
        case .southPole: tr("南十字の長い腕を 4.5 倍のばした所が天の南極。その高さが南緯。", "Extend the Cross's long arm 4.5 times to find the south pole. Its height is your southern latitude.")
        case .canopus: tr("全天で 2 番目に明るいカノープスは、北緯 37° より北では昇らない。", "Canopus, the second-brightest star, never rises north of about 37°N.")
        case .zenith: tr("頭の真上を通る星の赤緯は、その土地の緯度と同じ。", "A star passing straight overhead has a declination equal to your latitude.")
        case .orion: tr("夜 10 時に南北の線にオリオンがあるのは 12〜2 月。", "Orion crosses the north–south line at 10 p.m. in December to February.")
        case .leo: tr("夜 10 時に南北の線にしし座があるのは 3〜5 月。", "Leo crosses the north–south line at 10 p.m. in March to May.")
        case .scorpius: tr("夜 10 時に南北の線にさそり座があるのは 6〜8 月。", "Scorpius crosses the north–south line at 10 p.m. in June to August.")
        case .triangle: tr("ベガ・デネブ・アルタイルの大三角が南北の線にあるのは 8〜10 月。", "Vega, Deneb and Altair cross the north–south line in August to October.")
        case .pegasus: tr("ペガススの四辺形が南北の線にあるのは 10〜12 月。", "The Great Square of Pegasus crosses the north–south line in October to December.")
        }
    }

    /// 札で光らせる星座
    var constellations: [String] {
        switch self {
        case .clock: []
        case .polaris: ["UMi", "UMa"]
        case .dipper: ["UMa"]
        case .crux: ["Cru", "Cen"]
        case .southPole: ["Cru"]
        case .canopus: ["Car"]
        case .zenith: []
        case .orion: ["Ori"]
        case .leo: ["Leo"]
        case .scorpius: ["Sco"]
        case .triangle: ["Lyr", "Cyg", "Aql"]
        case .pegasus: ["Peg"]
        }
    }

    /// 札の飾りの記号（自作の絵の種類）
    var glyph: String {
        switch self {
        case .clock: "clock"
        case .polaris, .southPole, .zenith: "pole"
        default: "stars"
        }
    }

    // MARK: - 問題に当てはまるか

    private static let meridianRA: [Lore: Double] = [.orion: 5.6, .leo: 10.6, .scorpius: 16.8, .triangle: 19.8, .pegasus: 23.6]

    func applies(to q: Question) -> Bool {
        switch self {
        case .clock: return true
        case .polaris: return q.city.lat > 5
        case .dipper: return q.city.lat > 41
        case .crux:
            guard let s = StarCatalog.byKey["Cru.a"] else { return false }
            return q.horizontal(s).alt > 3
        case .southPole: return q.city.lat < -5
        case .canopus:
            guard let s = StarCatalog.byKey["Car.a"] else { return false }
            return q.city.lat > 0 && q.horizontal(s).alt > 1
        case .zenith: return Lore.zenithStar(q) != nil
        case .orion, .leo, .scorpius, .triangle, .pegasus:
            guard let ra = Lore.meridianRA[self] else { return false }
            var gap = abs(ra - q.lst)
            gap = min(gap, 24 - gap)
            return gap < 2.2
        }
    }

    /// その問題の数字を入れた一言
    func detail(for q: Question) -> String {
        let lat = q.city.lat
        switch self {
        case .clock:
            let gap = q.localTime - q.clock
            var g = gap.truncatingRemainder(dividingBy: 24)
            if g > 12 { g -= 24 }
            if g < -12 { g += 24 }
            let lon = Int((g * 15).rounded())
            let hh = Int(q.clock), mm = Int((q.clock - Double(hh)) * 60)
            let clock = String(format: "%02d:%02d", hh, mm)
            return lon >= 0
                ? trf("時計は %@。夜 10 時との差から 東経 約 %d°（正解は %d°）。", "Clock read %@. The gap from 10 p.m. gives about %d°E (answer: %d°).", clock, abs(lon), Int(q.city.lon.rounded()))
                : trf("時計は %@。夜 10 時との差から 西経 約 %d°（正解は %d°）。", "Clock read %@. The gap from 10 p.m. gives about %d°W (answer: %d°).", clock, abs(lon), Int(abs(q.city.lon).rounded()))
        case .polaris:
            let alt = StarCatalog.byKey["UMi.a"].map { q.horizontal($0).alt } ?? lat
            return trf("北極星の高さ %d° → 北緯 約 %d°。", "Polaris stood %d° high → about %d°N.", Int(alt.rounded()), Int(lat.rounded()))
        case .dipper:
            return trf("北緯 %d° なので、北斗七星は一晩中沈まない。", "At %d°N the Big Dipper never sets.", Int(lat.rounded()))
        case .crux:
            let alt = StarCatalog.byKey["Cru.a"].map { q.horizontal($0).alt } ?? 0
            return trf("南十字が高さ %d° に見えた。", "The Southern Cross stood %d° high.", Int(alt.rounded()))
        case .southPole:
            return trf("天の南極の高さ %d° → 南緯 約 %d°。", "The south pole stood %d° high → about %d°S.", Int(abs(lat).rounded()), Int(abs(lat).rounded()))
        case .canopus:
            return trf("カノープスが昇っていた → 北緯 %d° は 37° より南。", "Canopus was up → %d°N is south of 37°.", Int(lat.rounded()))
        case .zenith:
            guard let s = Lore.zenithStar(q) else { return "" }
            return trf("頭の上の星の赤緯 %d° → 緯度 約 %d°。", "The overhead star's declination %d° → latitude about %d°.", Int(s.dec.rounded()), Int(lat.rounded()))
        case .orion, .leo, .scorpius, .triangle, .pegasus:
            return trf("この空は %1$d 月。", "This sky was in %2$@.", q.month, Lore.monthName(q.month))
        }
    }

    /// 天頂から 8° 以内のいちばん明るい星
    static func zenithStar(_ q: Question) -> Star? {
        StarCatalog.stars
            .filter { $0.mag < 2.6 && q.horizontal($0).alt > 82 }
            .min { $0.mag < $1.mag }
    }

    /// 答えのあとに見せる札：まだ持っていない当てはまる札を優先、なければ並びの先
    static func pick(for q: Question, owned: Set<Lore>) -> Lore {
        let order: [Lore] = [.polaris, .southPole, .crux, .canopus, .dipper, .orion, .leo, .scorpius, .triangle, .pegasus, .zenith, .clock]
        let fits = order.filter { $0.applies(to: q) }
        return fits.first { !owned.contains($0) } ?? fits.first ?? .clock
    }

    static func monthName(_ m: Int) -> String {
        let names = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        return names[max(0, min(11, m - 1))]
    }

    static func monthShort(_ m: Int) -> String {
        if Lang.isJapanese { return "\(m)月" }
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return names[max(0, min(11, m - 1))]
    }
}
