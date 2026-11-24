import Foundation
import Testing
@testable import StarCompass

/// 空の計算
struct SkyTests {
    func q(_ city: String, month: Int, local: Double = 22) -> Question {
        Question(cityID: city, year: 2026, month: month, day: 15, localTime: local, rotation: 0)
    }

    func alt(_ key: String, _ q: Question) -> Double {
        q.horizontal(StarCatalog.byKey[key]!).alt
    }

    @Test func polarisHeightMatchesLatitude() {
        for city in ["tokyo", "london", "reykjavik", "singapore", "mexicocity"] {
            for month in [1, 4, 7, 10] {
                let question = q(city, month: month)
                #expect(abs(alt("UMi.a", question) - question.city.lat) < 1.0, "\(city) \(month)")
            }
        }
    }

    @Test func southernCrossNeverRisesAt35North() {
        for month in 1...12 {
            for local in stride(from: 0.0, to: 24, by: 2) {
                #expect(alt("Cru.a", q("tokyo", month: month, local: local)) < 0)
            }
        }
    }

    @Test func southernCrossIsUpInSydneyWinter() {
        #expect(alt("Cru.a", q("sydney", month: 6, local: 20)) > 30)
    }

    @Test func orionIsHighOnJanuaryNightsInTokyo() {
        #expect(alt("Ori.e", q("tokyo", month: 1)) > 40)
        // 7 月の夜 10 時には沈んでいる
        #expect(alt("Ori.e", q("tokyo", month: 7)) < 0)
    }

    @Test func scorpiusIsUpInJulyNotInJanuary() {
        #expect(alt("Sco.a", q("tokyo", month: 7)) > 15)
        #expect(alt("Sco.a", q("tokyo", month: 1)) < 0)
    }

    @Test func greenwichClockGivesLongitude() {
        let tokyo = q("tokyo", month: 3, local: 22)
        // 東経 139.7° → 22 時 − 9.3 時 ≒ 12:41
        #expect(abs(tokyo.clock - (22 - 139.69 / 15)) < 0.01)
        let ny = q("newyork", month: 3, local: 22)
        #expect(abs(ny.clock - Sky.wrap24(22 + 74.01 / 15)) < 0.01)
    }

    @Test func domeMapsZenithToCenterAndHorizonToEdge() {
        let z = Sky.dome(alt: 90, az: 0, rotation: 0)
        #expect(abs(z.x) < 1e-9 && abs(z.y) < 1e-9)
        let north = Sky.dome(alt: 0, az: 0, rotation: 0)
        #expect(abs(north.y + 1) < 1e-9)
        // 見上げた空：北を上にすると東は左
        let east = Sky.dome(alt: 0, az: 90, rotation: 0)
        #expect(east.x < -0.99)
    }

    @Test func milkyWayPassesNearCygnusAndSagittarius() {
        let band = StarCatalog.milkyWay(step: 2)
        func near(_ key: String) -> Bool {
            let s = StarCatalog.byKey[key]!
            return band.contains { abs($0.dec - s.dec) < 12 && min(abs($0.ra - s.ra), 24 - abs($0.ra - s.ra)) < 1.2 }
        }
        #expect(near("Cyg.g"))
        #expect(near("Sgr.d"))
        #expect(!near("UMa.e"))
    }
}

/// 星表と星座
struct CatalogTests {
    @Test func catalogHasManyBrightStars() {
        #expect(StarCatalog.stars.count >= 300)
        #expect(Set(StarCatalog.stars.map(\.key)).count == StarCatalog.stars.count)
        #expect(StarCatalog.stars.allSatisfy { (0..<24).contains($0.ra) && (-90...90).contains($0.dec) })
    }

    @Test func everyConstellationLineHasBothStars() {
        for c in StarCatalog.constellations {
            for (a, b) in c.lines {
                #expect(StarCatalog.byKey[a] != nil, "\(c.key) \(a)")
                #expect(StarCatalog.byKey[b] != nil, "\(c.key) \(b)")
            }
        }
        #expect(StarCatalog.constellations.count >= 30)
    }

    @Test func citiesSplitIntoFreeAndPro() {
        #expect(CityBook.base.count == 50)
        #expect(CityBook.all.count - CityBook.base.count == 16)
        #expect(Set(CityBook.all.map(\.id)).count == CityBook.all.count)
        for k in Continent.allCases { #expect(CityBook.all.contains { $0.continent == k }) }
    }

    @Test func landMaskKnowsContinentsAndOceans() {
        #expect(Land.isLand(lat: 48.86, lon: 2.35))
        #expect(Land.isLand(lat: -25, lon: 135))
        #expect(Land.isLand(lat: 0, lon: 20))
        #expect(!Land.isLand(lat: 0, lon: -150))
        #expect(!Land.isLand(lat: -40, lon: -20))
    }
}

/// 地球儀
struct EarthTests {
    @Test func tokyoToLondon() {
        let d = Earth.distance(lat1: 35.68, lon1: 139.69, lat2: 51.51, lon2: -0.13)
        #expect(abs(d - 9_560) < 80)
    }

    @Test func orthographicRoundTrip() {
        for (lat, lon) in [(35.0, 139.0), (-33.0, 151.0), (10.0, -170.0)] {
            let c = (lat0: lat - 10, lon0: lon + 15)
            guard let p = Earth.ortho(lat: lat, lon: lon, lat0: c.lat0, lon0: c.lon0),
                  let back = Earth.inverseOrtho(x: p.x, y: p.y, lat0: c.lat0, lon0: c.lon0) else {
                Issue.record("見えるはず")
                continue
            }
            #expect(abs(back.lat - lat) < 1e-6)
            #expect(abs(back.lon - lon) < 1e-6)
        }
        // 裏側は見えない
        #expect(Earth.ortho(lat: -35, lon: -40, lat0: 35, lon0: 140) == nil)
    }

    @Test func arcEndsAtBothPoints() {
        let a = Earth.interpolate(lat1: 10, lon1: 20, lat2: -30, lon2: 150, t: 0)
        let b = Earth.interpolate(lat1: 10, lon1: 20, lat2: -30, lon2: 150, t: 1)
        #expect(abs(a.lat - 10) < 1e-6 && abs(a.lon - 20) < 1e-6)
        #expect(abs(b.lat + 30) < 1e-6 && abs(b.lon - 150) < 1e-6)
    }
}

/// 点の決まり
struct ScoringTests {
    @Test func distanceCurve() {
        #expect(Scoring.location(distanceKm: 0) == 4000)
        #expect(abs(Scoring.location(distanceKm: 500) - 3500) <= 15)
        #expect(abs(Scoring.location(distanceKm: 2000) - 1500) <= 30)
        #expect(Scoring.location(distanceKm: 8000) < 100)
    }

    @Test func monthsWrapAround() {
        #expect(Scoring.monthGap(12, 1) == 1)
        #expect(Scoring.monthGap(1, 7) == 6)
        #expect(Scoring.season(guess: 12, answer: 1) == 667)
        #expect(Scoring.season(guess: 3, answer: 6) == 0)
    }

    /// 怖い：ヒント 3 つで満点 2,000 以下
    @Test func threeHintsCapTheScore() {
        #expect(Scoring.maxScore(hints: 0) == 5000)
        #expect(Scoring.maxScore(hints: 3) <= 2000)
        #expect(Scoring.total(distanceKm: 0, guessMonth: 5, answerMonth: 5, hints: 3) <= 2000)
    }

    @Test func moonsFollowTheScore() {
        #expect(Scoring.moon(4800) == "🌕")
        #expect(Scoring.moon(0) == "🌑")
    }
}

/// 毎日の問題
struct PuzzleTests {
    @Test func sameDaySameSkies() {
        #expect(Puzzle.daily("2026-11-24") == Puzzle.daily("2026-11-24"))
        #expect(Puzzle.daily("2026-11-24") != Puzzle.daily("2026-11-25"))
    }

    @Test func dailyMixesHemispheres() {
        for day in 1...60 {
            let key = String(format: "2026-%02d-%02d", (day - 1) / 28 + 1, (day - 1) % 28 + 1)
            let qs = Puzzle.daily(key)
            #expect(qs.count == 5)
            #expect(Set(qs.map(\.cityID)).count == 5)
            #expect(qs.contains { $0.city.lat < -10 })
            #expect(qs.filter { $0.city.lat > 20 }.count >= 2)
            #expect(qs.allSatisfy { (21.5...22.5).contains($0.localTime) && (1...12).contains($0.month) })
        }
    }

    @Test func freePracticeUsesOnlyBaseCities() {
        for s in 0..<40 {
            let qs = Puzzle.practice(seed: UInt64(s), year: 2026, includeExtra: false)
            #expect(qs.allSatisfy { !$0.city.extra })
        }
    }
}

/// 遊びの核の緊張を数字で確かめる（review.md・監督の指示 #49）
struct TensionTests {
    /// 試す問題（日付の種で 400 問）
    func trials() -> [Question] {
        (1...80).flatMap { i in Puzzle.daily(String(format: "2027-%02d-%02d", (i - 1) / 28 + 1, (i - 1) % 28 + 1)) }
    }

    /// 読み方を全部使う解き手：緯度は極の高さ（±3° の読み違い）、経度は時計（夜 10 時と見なす）、月は南北の線の星（恒星時）
    func expert(_ q: Question, rng: inout SeededRNG) -> Answer {
        let lat = max(-89, min(89, q.city.lat + (rng.unit() * 2 - 1) * 3))
        var gap = 22 - q.clock
        if gap > 12 { gap -= 24 }
        if gap < -12 { gap += 24 }
        let lon = gap * 15
        let month = (1...12).min { a, b in
            func off(_ m: Int) -> Double {
                let l = Sky.localSiderealTime(year: q.year, month: m, day: 15, ut: 22 - lon / 15, lon: lon)
                let d = abs(l - q.lst)
                return min(d, 24 - d)
            }
            return off(a) < off(b)
        } ?? 6
        return Answer(question: q, guessLat: lat, guessLon: lon, guessMonth: month, hints: [])
    }

    /// うれしい：北極星の高さだけで答える解き手が、北半球の問題で緯度 ±10° に入る割合 8 割以上
    @Test func polarisAloneFindsTheLatitude() {
        var rng = SeededRNG(seed: 1)
        let north = trials().filter { $0.city.lat > 5 }
        let hits = north.filter { q in
            let read = q.horizontal(StarCatalog.byKey["UMi.a"]!).alt + (rng.unit() * 2 - 1) * 5  // 目で読むずれ ±5°
            return abs(read - q.city.lat) <= 10
        }
        #expect(Double(hits.count) / Double(north.count) >= 0.8)
    }

    /// 惜しい：何も知らずに真ん中を答えると平均 1,000 点以下、読み方を全部使う解き手は 3,500 以上（3 倍以上の差）
    @Test func readingTheSkyBeatsGuessing() {
        var rng = SeededRNG(seed: 2)
        let qs = trials()
        let naive = qs.map { Answer(question: $0, guessLat: 20, guessLon: 0, guessMonth: 6, hints: []).score }
        let skilled = qs.map { expert($0, rng: &rng).score }
        let n = Double(naive.reduce(0, +)) / Double(qs.count)
        let s = Double(skilled.reduce(0, +)) / Double(qs.count)
        #expect(n <= 1000, "真ん中の平均 \(n)")
        #expect(s >= 3500, "読み方の平均 \(s)")
        #expect(s >= n * 3)
    }

    /// 経度は時計なしでは運：時計を読まずに経度 0° と答えると、緯度と月が完璧でも平均 2,500 点に届かない
    @Test func longitudeNeedsTheClock() {
        var rng = SeededRNG(seed: 3)
        let qs = trials()
        let scores = qs.map { q -> Int in
            let e = expert(q, rng: &rng)
            return Answer(question: q, guessLat: e.guessLat, guessLon: 0, guessMonth: q.month, hints: []).score
        }
        #expect(Double(scores.reduce(0, +)) / Double(qs.count) < 2500)
    }
}

/// 読み方の札
struct LoreTests {
    @Test func clockAlwaysApplies() {
        for q in Puzzle.daily("2026-11-24") { #expect(Lore.clock.applies(to: q)) }
    }

    @Test func hemisphereCards() {
        let sydney = Question(cityID: "sydney", year: 2026, month: 6, day: 15, localTime: 22, rotation: 0)
        let tokyo = Question(cityID: "tokyo", year: 2026, month: 1, day: 15, localTime: 22, rotation: 0)
        #expect(!Lore.polaris.applies(to: sydney))
        #expect(Lore.southPole.applies(to: sydney))
        #expect(Lore.crux.applies(to: sydney))
        #expect(Lore.polaris.applies(to: tokyo))
        #expect(!Lore.crux.applies(to: tokyo))
        #expect(Lore.orion.applies(to: tokyo))
        #expect(!Lore.scorpius.applies(to: tokyo))
    }

    @Test func pickPrefersANewCard() {
        let tokyo = Question(cityID: "tokyo", year: 2026, month: 1, day: 15, localTime: 22, rotation: 0)
        #expect(Lore.pick(for: tokyo, owned: []) == .polaris)
        #expect(Lore.pick(for: tokyo, owned: [.polaris]) != .polaris)
        #expect(Lore.pick(for: tokyo, owned: Set(Lore.allCases)) == .polaris)
    }

    @Test func everyCardHasWordsInBothLanguages() {
        for l in Lore.allCases {
            #expect(!l.title.isEmpty && !l.rule.isEmpty)
        }
        let q = Question(cityID: "paris", year: 2026, month: 1, day: 15, localTime: 22, rotation: 0)
        let d = Lore.orion.detail(for: q)
        #expect(d.contains("1") || d.contains("January"))
    }
}

/// 記録
struct ProgressTests {
    let cal = Calendar(identifier: .gregorian)

    func answers(_ key: String) -> [Answer] {
        Puzzle.daily(key).map { Answer(question: $0, guessLat: $0.city.lat, guessLon: $0.city.lon, guessMonth: $0.month, hints: []) }
    }

    @Test func streakCountsFinishedDays() throws {
        var p = Logbook()
        let today = try #require(cal.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 12)))
        for back in 1...3 {
            let d = try #require(cal.date(byAdding: .day, value: -back, to: today))
            p.days[Puzzle.key(d, calendar: cal)] = answers(Puzzle.key(d, calendar: cal))
        }
        // 今日はまだ → 昨日までの 3 日
        #expect(p.streak(today: today, calendar: cal) == 3)
        p.days[Puzzle.key(today, calendar: cal)] = answers(Puzzle.key(today, calendar: cal))
        #expect(p.streak(today: today, calendar: cal) == 4)
        // 途中までの日は数えない
        p.days[Puzzle.key(today, calendar: cal)] = Array(answers(Puzzle.key(today, calendar: cal)).prefix(3))
        #expect(p.streak(today: today, calendar: cal) == 3)
    }

    @Test func freePracticeIsThreeADay() {
        var p = Logbook()
        #expect(p.practiceLeft(today: "2026-11-24") == 3)
        for _ in 0..<3 { p.usePractice(today: "2026-11-24") }
        #expect(p.practiceLeft(today: "2026-11-24") == 0)
        #expect(p.practiceLeft(today: "2026-11-25") == 3)
    }

    @Test func perfectAnswerScoresFull() {
        for a in answers("2026-11-24") { #expect(a.score == 5000) }
    }

    @Test func shareTextHasNoPlaceNames() {
        let a = answers("2026-11-24")
        let text = Logbook.shareText(key: "2026-11-24", answers: a, streak: 4)
        for x in a {
            #expect(!text.contains(x.question.city.en))
            #expect(!text.contains(x.question.city.ja))
        }
        #expect(text.contains("25,000"))
    }

    @Test func progressSurvivesEncoding() throws {
        var p = Logbook()
        p.days["2026-11-24"] = answers("2026-11-24")
        p.lore = [.clock, .crux]
        p.record(p.days["2026-11-24"]![0])
        let back = try JSONDecoder().decode(Logbook.self, from: JSONEncoder().encode(p))
        #expect(back == p)
    }
}
