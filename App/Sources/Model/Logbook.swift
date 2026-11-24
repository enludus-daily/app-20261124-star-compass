import Foundation

/// 端末の中だけに残る記録（UserDefaults に JSON で 1 つ）
struct Logbook: Codable, Equatable, Sendable {
    /// 毎日の問題の答え（日付の鍵 → 答えた順）
    var days: [String: [Answer]] = [:]
    /// 過去の問題（Pro）の合計
    var archive: [String: Int] = [:]
    /// 自由練習を使った日と回数（無料は 1 日 3 回）
    var practiceDay = ""
    var practiceUsed = 0
    /// 集めた読み方の札
    var lore: Set<Lore> = []
    /// 距離の記録（統計用。新しい 300 件）
    var samples: [Sample] = []
    var bestDaily = 0
    var paywallOffered = false

    struct Sample: Codable, Equatable, Sendable {
        let continent: Continent
        let distanceKm: Double
        let score: Int
    }

    static let freePractice = 3

    func isDone(_ key: String) -> Bool { (days[key]?.count ?? 0) >= Puzzle.perDay }

    func total(_ key: String) -> Int { days[key]?.reduce(0) { $0 + $1.score } ?? 0 }

    func practiceLeft(today: String) -> Int {
        practiceDay == today ? max(0, Logbook.freePractice - practiceUsed) : Logbook.freePractice
    }

    mutating func usePractice(today: String) {
        if practiceDay != today { practiceDay = today; practiceUsed = 0 }
        practiceUsed += 1
    }

    mutating func record(_ a: Answer) {
        samples.append(Sample(continent: a.question.city.continent, distanceKm: a.distanceKm, score: a.score))
        if samples.count > 300 { samples.removeFirst(samples.count - 300) }
    }

    /// 連続日数：今日か昨日まで、毎日の 5 問を終えた日が続いた数
    func streak(today: Date, calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: today)
        if !isDone(Puzzle.key(day, calendar: calendar)) {
            guard let y = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        var n = 0
        while isDone(Puzzle.key(day, calendar: calendar)) {
            n += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }

    /// 大陸ごとの平均距離（km）。記録のない大陸は入れない
    func averageDistance() -> [(Continent, Double, Int)] {
        Continent.allCases.compactMap { c in
            let s = samples.filter { $0.continent == c }
            guard !s.isEmpty else { return nil }
            return (c, s.reduce(0) { $0 + $1.distanceKm } / Double(s.count), s.count)
        }
    }

    /// 最近 10 問と、その前の 10 問の平均距離（上達が見える）
    func trend() -> (recent: Double, before: Double)? {
        guard samples.count >= 12 else { return nil }
        let recent = samples.suffix(10)
        let before = samples.dropLast(10).suffix(10)
        func avg<S: Collection>(_ s: S) -> Double where S.Element == Sample { s.reduce(0) { $0 + $1.distanceKm } / Double(s.count) }
        return (avg(recent), avg(before))
    }

    /// 共有の文（点と月の満ち欠けだけ。場所は書かない）
    static func shareText(key: String, answers: [Answer], streak: Int) -> String {
        let moons = answers.map { Scoring.moon($0.score) }.joined()
        let total = answers.reduce(0) { $0 + $1.score }
        let date = key.replacingOccurrences(of: "-", with: "/")
        let head = tr("ほしよみ天文台", "Star Compass")
        let streakText = streak > 1 ? trf(" ・%d 日連続", " · %d-day streak", streak) : ""
        return "\(head) \(date)\n\(moons)  \(total.formatted()) / 25,000\(streakText)"
    }
}
