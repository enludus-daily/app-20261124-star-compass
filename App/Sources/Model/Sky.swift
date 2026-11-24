import Foundation

/// 空の計算（画面から切り離してテストする）。
/// 星の赤経・赤緯 → その土地・その時刻の高度・方位 → 天頂を中心にした円（半径 1 が地平線）の上の点。
enum Sky {
    /// 2000-01-01 12:00 UT からの日数
    static func daysSinceJ2000(year: Int, month: Int, day: Int, ut: Double) -> Double {
        // グレゴリオ暦の通日（Meeus の式）
        var y = year, m = month
        if m <= 2 { y -= 1; m += 12 }
        let a = y / 100
        let b = 2 - a + a / 4
        let jd0 = floor(365.25 * Double(y + 4716)) + floor(30.6001 * Double(m + 1)) + Double(day) + Double(b) - 1524.5
        return jd0 + ut / 24 - 2_451_545.0
    }

    /// 地方恒星時（時）。ut は世界時（時）、lon は東経（度、西は負）
    static func localSiderealTime(year: Int, month: Int, day: Int, ut: Double, lon: Double) -> Double {
        let d = daysSinceJ2000(year: year, month: month, day: day, ut: ut)
        let gmst = 18.697374558 + 24.06570982441908 * d
        return wrap24(gmst + lon / 15)
    }

    static func wrap24(_ h: Double) -> Double {
        let r = h.truncatingRemainder(dividingBy: 24)
        return r < 0 ? r + 24 : r
    }

    static func wrap360(_ d: Double) -> Double {
        let r = d.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    /// 高度・方位（度）。方位は北から東まわり
    static func horizontal(ra: Double, dec: Double, lat: Double, lst: Double) -> (alt: Double, az: Double) {
        let rad = Double.pi / 180
        let h = (lst - ra) * 15 * rad
        let d = dec * rad, p = lat * rad
        let sinAlt = sin(p) * sin(d) + cos(p) * cos(d) * cos(h)
        let alt = asin(max(-1, min(1, sinAlt)))
        let y = -sin(h) * cos(d)
        let x = cos(p) * sin(d) - sin(p) * cos(d) * cos(h)
        var az = atan2(y, x) / rad
        if az < 0 { az += 360 }
        return (alt / rad, az)
    }

    /// 天頂を中心に、地平線を半径 1 とする円の上の点（見上げた向き：北を上にすると東は左）。
    /// rotation は円の回転（度）。問題ごとに回して、方角を読ませる
    static func dome(alt: Double, az: Double, rotation: Double) -> (x: Double, y: Double) {
        let r = (90 - alt) / 90
        let a = (az + rotation) * .pi / 180
        return (-r * sin(a), -r * cos(a))
    }
}

/// 地球の上の 2 点
enum Earth {
    static let radiusKm = 6371.0

    /// 大円の距離（km）
    static func distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = Double.pi / 180
        let dLat = (lat2 - lat1) * r, dLon = (lon2 - lon1) * r
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * r) * cos(lat2 * r) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radiusKm * asin(min(1, sqrt(a)))
    }

    /// 2 点を結ぶ大円の上の点（t = 0〜1）
    static func interpolate(lat1: Double, lon1: Double, lat2: Double, lon2: Double, t: Double) -> (lat: Double, lon: Double) {
        let r = Double.pi / 180
        let p1 = (cos(lat1 * r) * cos(lon1 * r), cos(lat1 * r) * sin(lon1 * r), sin(lat1 * r))
        let p2 = (cos(lat2 * r) * cos(lon2 * r), cos(lat2 * r) * sin(lon2 * r), sin(lat2 * r))
        let dot = max(-1, min(1, p1.0 * p2.0 + p1.1 * p2.1 + p1.2 * p2.2))
        let w = acos(dot)
        if w < 1e-6 { return (lat1, lon1) }
        let a = sin((1 - t) * w) / sin(w), b = sin(t * w) / sin(w)
        let x = a * p1.0 + b * p2.0, y = a * p1.1 + b * p2.1, z = a * p1.2 + b * p2.2
        return (atan2(z, sqrt(x * x + y * y)) / r, atan2(y, x) / r)
    }

    /// 正射図法（地球儀）。中心 (lat0, lon0) から見た点。見えない側なら nil。半径 1
    static func ortho(lat: Double, lon: Double, lat0: Double, lon0: Double) -> (x: Double, y: Double)? {
        let r = Double.pi / 180
        let p = lat * r, l = lon * r, p0 = lat0 * r, l0 = lon0 * r
        let cosc = sin(p0) * sin(p) + cos(p0) * cos(p) * cos(l - l0)
        guard cosc >= 0 else { return nil }
        let x = cos(p) * sin(l - l0)
        let y = cos(p0) * sin(p) - sin(p0) * cos(p) * cos(l - l0)
        return (x, -y)
    }

    /// 正射図法の逆（画面の点 → 緯度・経度）。円の外なら nil
    static func inverseOrtho(x: Double, y: Double, lat0: Double, lon0: Double) -> (lat: Double, lon: Double)? {
        let yy = -y
        let rho = sqrt(x * x + yy * yy)
        guard rho <= 1 else { return nil }
        let r = Double.pi / 180
        let p0 = lat0 * r, l0 = lon0 * r
        if rho < 1e-9 { return (lat0, lon0) }
        let c = asin(rho)
        let lat = asin(cos(c) * sin(p0) + yy * sin(c) * cos(p0) / rho)
        let lon = l0 + atan2(x * sin(c), rho * cos(p0) * cos(c) - yy * sin(p0) * sin(c))
        var lonDeg = lon / r
        lonDeg = (lonDeg + 540).truncatingRemainder(dividingBy: 360) - 180
        return (lat / r, lonDeg)
    }
}
