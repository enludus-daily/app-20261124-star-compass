import Foundation

/// 決まった種から同じ並びを出す乱数（毎日の問題を全員同じにする）
struct SeededRNG: RandomNumberGenerator, Sendable {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

/// 1 問：ある都市の、ある日の夜 10 時ごろの空
struct Question: Hashable, Codable, Sendable {
    let cityID: String
    let year: Int
    let month: Int
    let day: Int
    /// その土地の時刻（地方平均時、時）。21.5〜22.5
    let localTime: Double
    /// 空の円の回し方（度）。方角は読ませる
    let rotation: Double

    var city: City { CityBook.byID[cityID] ?? CityBook.all[0] }
    /// 世界時（時）。日をまたいだら 24 を超える・負になることがある（計算ではそのまま使う）
    var ut: Double { localTime - city.lon / 15 }
    /// グリニッジの時計に出す時刻（0〜24）
    var clock: Double { Sky.wrap24(ut) }
    var lst: Double { Sky.localSiderealTime(year: year, month: month, day: day, ut: ut, lon: city.lon) }

    func horizontal(_ s: Star) -> (alt: Double, az: Double) {
        Sky.horizontal(ra: s.ra, dec: s.dec, lat: city.lat, lst: lst)
    }

    func horizontal(ra: Double, dec: Double) -> (alt: Double, az: Double) {
        Sky.horizontal(ra: ra, dec: dec, lat: city.lat, lst: lst)
    }
}

enum Hint: String, CaseIterable, Codable, Sendable {
    case lines, compass, milkyWay

    var title: String {
        switch self {
        case .lines: tr("星座の線", "Lines")
        case .compass: tr("方角", "Compass")
        case .milkyWay: tr("天の川", "Milky Way")
        }
    }
}

enum Scoring {
    static let locationMax = 4000.0
    static let seasonMax = 1000.0
    /// 距離の目盛り（500km で 3,500、2,000km で 1,500 になるように決めた）
    static let scaleKm = 2024.0
    static let power = 1.44
    /// ヒント 1 つで満点から引く割合
    static let hintCost = 0.2

    static func location(distanceKm d: Double) -> Int {
        Int((locationMax * exp(-pow(max(0, d) / scaleKm, power))).rounded())
    }

    /// 月のずれ（循環。12 月と 1 月は 1）
    static func monthGap(_ a: Int, _ b: Int) -> Int {
        let g = abs(a - b) % 12
        return min(g, 12 - g)
    }

    static func season(guess: Int, answer: Int) -> Int {
        switch monthGap(guess, answer) {
        case 0: 1000
        case 1: 667
        case 2: 333
        default: 0
        }
    }

    static func multiplier(hints: Int) -> Double { max(0, 1 - hintCost * Double(hints)) }

    static func maxScore(hints: Int) -> Int { Int((5000 * multiplier(hints: hints)).rounded()) }

    static func total(distanceKm: Double, guessMonth: Int, answerMonth: Int, hints: Int) -> Int {
        let raw = Double(location(distanceKm: distanceKm) + season(guess: guessMonth, answer: answerMonth))
        return Int((raw * multiplier(hints: hints)).rounded())
    }

    /// 共有の格子に使う月の満ち欠け
    static func moon(_ score: Int) -> String {
        switch score {
        case 4000...: "🌕"
        case 2500..<4000: "🌔"
        case 1000..<2500: "🌓"
        case 1..<1000: "🌒"
        default: "🌑"
        }
    }

    static func title(total: Int) -> String {
        switch total {
        case 22_000...: tr("天文台長", "Observatory Director")
        case 17_000..<22_000: tr("航海士", "Navigator")
        case 11_000..<17_000: tr("星読み", "Star Reader")
        case 5_000..<11_000: tr("見習い観測手", "Apprentice Observer")
        default: tr("夜空の旅人", "Night Wanderer")
        }
    }
}

/// 答えの結果
struct Answer: Hashable, Codable, Sendable {
    let question: Question
    let guessLat: Double
    let guessLon: Double
    let guessMonth: Int
    let hints: [Hint]
    let distanceKm: Double
    let score: Int

    init(question: Question, guessLat: Double, guessLon: Double, guessMonth: Int, hints: [Hint]) {
        self.question = question
        self.guessLat = guessLat
        self.guessLon = guessLon
        self.guessMonth = guessMonth
        self.hints = hints
        distanceKm = Earth.distance(lat1: guessLat, lon1: guessLon, lat2: question.city.lat, lon2: question.city.lon)
        score = Scoring.total(distanceKm: distanceKm, guessMonth: guessMonth, answerMonth: question.month, hints: hints.count)
    }
}

enum Mode: Hashable, Codable, Sendable {
    case daily(String)
    case practice
    case hard
    case archive(String)
}

enum Puzzle {
    static let perDay = 5

    /// 日付の鍵（端末の暦・時刻帯での日付）
    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }

    static func seed(_ key: String) -> UInt64 {
        // 文字列から安定した数（FNV-1a）
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in key.utf8 { h = (h ^ UInt64(b)) &* 0x100_0000_01b3 }
        return h
    }

    static func year(of key: String) -> Int { Int(key.prefix(4)) ?? 2026 }

    /// 毎日の 5 問（全員同じ）。南半球を 1 問以上、北半球を 2 問以上入れる
    static func daily(_ key: String) -> [Question] {
        var rng = SeededRNG(seed: seed(key))
        let year = year(of: key)
        var pool = CityBook.all
        var picked: [City] = []
        func take(where ok: (City) -> Bool) {
            let candidates = pool.filter(ok)
            guard !candidates.isEmpty else { return }
            let c = candidates[Int(rng.next() % UInt64(candidates.count))]
            picked.append(c)
            pool.removeAll { $0.id == c.id }
        }
        take { $0.lat < -10 }
        take { $0.lat > 20 }
        take { $0.lat > 20 }
        while picked.count < perDay { take { _ in true } }
        // 並びを混ぜる
        for i in stride(from: picked.count - 1, to: 0, by: -1) {
            picked.swapAt(i, Int(rng.next() % UInt64(i + 1)))
        }
        return picked.map { make(city: $0, year: year, rng: &rng) }
    }

    /// 自由練習の 1 回（5 問）。Pro は追加の都市も出る
    static func practice(seed s: UInt64, year: Int, includeExtra: Bool) -> [Question] {
        var rng = SeededRNG(seed: s)
        var pool = includeExtra ? CityBook.all : CityBook.base
        var out: [Question] = []
        while out.count < perDay, !pool.isEmpty {
            let c = pool.remove(at: Int(rng.next() % UInt64(pool.count)))
            out.append(make(city: c, year: year, rng: &rng))
        }
        return out
    }

    static func make(city: City, year: Int, rng: inout SeededRNG) -> Question {
        let month = Int(rng.next() % 12) + 1
        let day = Int(rng.next() % 28) + 1
        let local = 21.5 + rng.unit()
        let rotation = (rng.unit() * 360).rounded()
        return Question(cityID: city.id, year: year, month: month, day: day, localTime: local, rotation: rotation)
    }
}
