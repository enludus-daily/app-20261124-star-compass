import Foundation
import Observation
import SwiftUI

struct GeoPoint: Hashable, Codable, Sendable {
    var lat: Double
    var lon: Double
}

enum Panel: Hashable { case sky, answer, result, summary }

enum ActiveSheet: String, Identifiable {
    case lore, stats, settings, paywall, archive
    var id: String { rawValue }
}

/// 遊んでいる 5 問
struct Session: Equatable {
    var mode: Mode
    var key: String
    var questions: [Question]
    var answers: [Answer] = []
    var index = 0
    var hints: Set<Hint> = []
    var pin: GeoPoint?
    var month: Int?
    var panel: Panel = .sky
    var lore: Lore?
    var newLore = false
    /// 指で回した空の向き（度）
    var skyTurn = 0.0
    /// 地球儀の中心
    var globe = GeoPoint(lat: 20, lon: 20)

    var current: Question { questions[min(index, questions.count - 1)] }
    var total: Int { answers.reduce(0) { $0 + $1.score } }
    var isHard: Bool { mode == .hard }
    var canAnswer: Bool { pin != nil && month != nil }
    var isLast: Bool { index >= questions.count - 1 }
}

@MainActor
@Observable
final class AppModel {
    var progress = Progress()
    var onboarded: Bool
    var onboardingPage = 0
    var session: Session?
    var activeSheet: ActiveSheet?
    var now: Date
    var soundOn: Bool
    var hapticsOn: Bool
    var reduceMotion = false
    /// 撮影：動きを止める
    var still = false
    var proOverride = false
    var shareCopied = false

    // 手応え（振動の引き金）
    var pressTick = 0
    var pinTick = 0
    var nearTick = 0
    var farTick = 0
    var loreTick = 0
    var finishTick = 0
    /// 点の数え上げの始まり（結果の画面）
    var revealAt = Date.distantPast

    @ObservationIgnored let persists: Bool
    @ObservationIgnored let defaults: UserDefaults
    let purchases: PurchaseStore

    static let bundleID = Bundle.main.bundleIdentifier ?? "com.enludus.daily.017"
    static var proID: String { ProductID.pro(bundleID: bundleID) }

    init(persists: Bool = true, now: Date = Date(), defaults: UserDefaults = .standard) {
        self.persists = persists
        self.defaults = defaults
        self.now = now
        purchases = PurchaseStore(productIDs: [AppModel.proID], proProductIDs: [AppModel.proID])
        if persists {
            onboarded = defaults.bool(forKey: "onboarded")
            soundOn = defaults.object(forKey: "sound") as? Bool ?? true
            hapticsOn = defaults.object(forKey: "haptics") as? Bool ?? true
            if let data = defaults.data(forKey: "progress"), let p = try? JSONDecoder().decode(Progress.self, from: data) {
                progress = p
            }
        } else {
            onboarded = false
            soundOn = true
            hapticsOn = true
        }
    }

    var isPro: Bool { proOverride || purchases.entitlements.isPro }
    var todayKey: String { Puzzle.key(now) }
    var streak: Int { progress.streak(today: now) }
    var practiceLeft: Int { isPro ? 99 : progress.practiceLeft(today: todayKey) }

    // MARK: - 保存（1 問ごとと終わりだけ。毎秒は保存しない）

    func save() {
        guard persists, let data = try? JSONEncoder().encode(progress) else { return }
        defaults.set(data, forKey: "progress")
    }

    func setOnboarded() {
        press()
        withAnimation(.easeInOut(duration: 0.4)) { onboarded = true }
        if persists { defaults.set(true, forKey: "onboarded") }
    }

    func setSound(_ on: Bool) {
        soundOn = on
        if persists { defaults.set(on, forKey: "sound") }
    }

    func setHaptics(_ on: Bool) {
        hapticsOn = on
        if persists { defaults.set(on, forKey: "haptics") }
    }

    func play(_ cue: SoundBox.Cue) {
        guard soundOn, !still else { return }
        SoundBox.shared.play(cue)
    }

    func press() {
        pressTick += 1
        play(.tap)
    }

    // MARK: - 始める

    func startDaily() {
        press()
        let key = todayKey
        var s = Session(mode: .daily(key), key: key, questions: Puzzle.daily(key))
        let done = progress.days[key] ?? []
        s.answers = done
        s.index = min(done.count, Puzzle.perDay - 1)
        if done.count >= Puzzle.perDay { s.panel = .summary }
        begin(s)
    }

    func startPractice() {
        press()
        guard isPro || progress.practiceLeft(today: todayKey) > 0 else {
            activeSheet = .paywall
            return
        }
        if !isPro { progress.usePractice(today: todayKey) }
        save()
        let seed = UInt64(now.timeIntervalSince1970 * 1000) ^ 0x5157
        begin(Session(mode: .practice, key: todayKey, questions: Puzzle.practice(seed: seed, year: Puzzle.year(of: todayKey), includeExtra: isPro)))
    }

    func startHard() {
        press()
        guard isPro else { activeSheet = .paywall; return }
        let seed = UInt64(now.timeIntervalSince1970 * 1000) ^ 0xA11
        begin(Session(mode: .hard, key: todayKey, questions: Puzzle.practice(seed: seed, year: Puzzle.year(of: todayKey), includeExtra: true)))
    }

    func startArchive(_ key: String) {
        press()
        guard isPro else { activeSheet = .paywall; return }
        activeSheet = nil
        begin(Session(mode: .archive(key), key: key, questions: Puzzle.daily(key)))
    }

    private func begin(_ s: Session) {
        withAnimation(.easeInOut(duration: 0.35)) { session = s }
    }

    func quit() {
        press()
        let offer = shouldOfferPaywall
        withAnimation(.easeInOut(duration: 0.35)) { session = nil }
        if offer {
            progress.paywallOffered = true
            save()
            activeSheet = .paywall
        }
    }

    /// はじめて毎日の 5 問を終えた直後に 1 回だけ Pro を案内する
    var shouldOfferPaywall: Bool {
        guard let s = session, case .daily = s.mode, s.panel == .summary else { return false }
        return !isPro && !progress.paywallOffered
    }

    // MARK: - 問題の中

    func show(_ panel: Panel) {
        press()
        withAnimation(.easeInOut(duration: 0.3)) { session?.panel = panel }
    }

    func toggleHint(_ h: Hint) {
        guard var s = session, s.panel == .sky || s.panel == .answer else { return }
        if s.isHard && h == .lines { return }
        press()
        if s.hints.contains(h) { s.hints.remove(h) } else { s.hints.insert(h) }
        withAnimation(.easeInOut(duration: 0.3)) { session = s }
    }

    func placePin(lat: Double, lon: Double) {
        guard let panel = session?.panel, panel == .answer || panel == .sky else { return }
        pinTick += 1
        play(.pin)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { session?.pin = GeoPoint(lat: lat, lon: lon) }
    }

    func setMonth(_ m: Int) {
        guard let panel = session?.panel, panel == .answer || panel == .sky else { return }
        press()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { session?.month = m }
    }

    func turnSky(by degrees: Double) { session?.skyTurn += degrees }
    func turnGlobe(lat: Double, lon: Double) { session?.globe = GeoPoint(lat: lat, lon: lon) }

    func submit() {
        guard var s = session, s.panel == .answer || s.panel == .sky, let pin = s.pin, let month = s.month else { return }
        let q = s.current
        let a = Answer(question: q, guessLat: pin.lat, guessLon: pin.lon, guessMonth: month, hints: Hint.allCases.filter { s.hints.contains($0) })
        s.answers.append(a)
        let lore = Lore.pick(for: q, owned: progress.lore)
        s.lore = lore
        s.newLore = !progress.lore.contains(lore)
        progress.lore.insert(lore)
        progress.record(a)
        switch s.mode {
        case .daily(let key):
            progress.days[key] = s.answers
            if s.answers.count >= Puzzle.perDay { progress.bestDaily = max(progress.bestDaily, s.total) }
        case .archive(let key):
            if s.answers.count >= Puzzle.perDay { progress.archive[key] = s.total }
        case .practice, .hard:
            break
        }
        save()
        // 地球儀を、正解と答えの真ん中に向ける
        let mid = Earth.interpolate(lat1: pin.lat, lon1: pin.lon, lat2: q.city.lat, lon2: q.city.lon, t: 0.5)
        s.globe = GeoPoint(lat: max(-60, min(60, mid.lat)), lon: mid.lon)
        s.panel = .result
        revealAt = Date()
        withAnimation(.easeInOut(duration: 0.4)) { session = s }
        if a.score >= 2500 {
            nearTick += 1
            play(.near)
        } else {
            farTick += 1
            play(.far)
        }
        if s.newLore {
            loreTick += 1
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(900))
                self.play(.lore)
            }
        }
    }

    func next() {
        guard var s = session, s.panel == .result else { return }
        press()
        if s.answers.count >= s.questions.count {
            s.panel = .summary
            finishTick += 1
            play(.finish)
            revealAt = Date()
        } else {
            s.index = s.answers.count
            s.hints = []
            s.pin = nil
            s.month = nil
            s.lore = nil
            s.newLore = false
            s.skyTurn = 0
            s.panel = .sky
        }
        withAnimation(.easeInOut(duration: 0.45)) { session = s }
    }

    // MARK: - 共有

    func shareText() -> String {
        guard let s = session else { return "" }
        return Progress.shareText(key: s.key, answers: s.answers, streak: streak)
    }

    // MARK: - 課金

    func syncPro() {}

    func buyPro() async {
        guard let product = purchases.products.first(where: { $0.id == AppModel.proID }) else { return }
        _ = await purchases.purchase(product)
    }

    func restore() async {
        await purchases.restore()
    }

    /// 過去 30 日の鍵（今日を除く、新しい順）
    var archiveKeys: [String] {
        (1...30).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: now) }.map { Puzzle.key($0) }
    }
}
