import SwiftUI

@main
struct StarCompassApp: App {
    /// アプリ全体で 1 つだけ
    private let model = Launch.shared

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        ZStack {
            if !model.onboarded {
                OnboardingView().transition(.opacity)
            } else if model.session != nil {
                PlayView().transition(.opacity)
            } else {
                HomeView().transition(.opacity)
            }
        }
        .environment(model)
        .modifier(WideOverride(on: Launch.scene == "wide"))
        // 夜の天文台を自前の色で描くので、ダークに固定する
        .preferredColorScheme(.dark)
        .sheet(item: $model.activeSheet) { sheet in
            SheetContent(sheet: sheet)
                .environment(model)
                .environment(\.locale, Lang.locale)
                .presentationCornerRadius(Radius.sheet)
                .presentationBackground(Ink.night)
                .presentationDetents([.large])
        }
        // 手応えの表（README）：押す・ピン・近い・遠い・新しい札・5 問を終える
        .sensoryFeedback(trigger: model.pressTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: model.pinTick) { _, _ in model.hapticsOn ? .impact(flexibility: .rigid, intensity: 0.6) : nil }
        .sensoryFeedback(trigger: model.nearTick) { _, _ in model.hapticsOn ? .success : nil }
        .sensoryFeedback(trigger: model.farTick) { _, _ in model.hapticsOn ? .impact(flexibility: .soft, intensity: 0.4) : nil }
        .sensoryFeedback(trigger: model.loreTick) { _, _ in model.hapticsOn ? .impact(weight: .heavy, intensity: 0.8) : nil }
        .sensoryFeedback(trigger: model.finishTick) { _, _ in model.hapticsOn ? .success : nil }
        .task { await Launch.run(model) }
        .task { await model.purchases.load() }
        .onAppear { model.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, v in model.reduceMotion = v }
        .onChange(of: scenePhase) { _, phase in
            // 日付が変わったら、今日の問題を新しくする（撮影・デモでは決まった日のまま）
            guard phase == .active, !model.still, !Launch.isDemo, Launch.scene == nil, !Launch.isFreshUITest else { return }
            model.now = Date()
        }
        .environment(\.locale, Lang.locale)
    }
}

/// 撮影で、広い画面（Duo の内側・iPad）の並べ方を見せる
struct WideOverride: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on { content.environment(\.horizontalSizeClass, .regular) } else { content }
    }
}

/// 起動の仕方：ふつう・撮影（-screenshotScene <名前>）・デモ（-demo）・UI テスト（-uiTestFresh）。
/// 撮影とデモは見本のデータで動かし、保存されたデータを書き換えない
@MainActor
enum Launch {
    /// 撮る画面の名前。後ろに _ja を付けると日本語で撮る（CI のシミュレータは英語のため）
    static var scene: String? {
        var value = UserDefaults.standard.string(forKey: "screenshotScene") ?? ""
        if value.hasSuffix("_ja") { value = String(value.dropLast(3)) }
        return value.isEmpty || value == "launch" ? nil : value
    }

    static var forcesJapanese: Bool {
        UserDefaults.standard.string(forKey: "screenshotScene")?.hasSuffix("_ja") ?? false
    }

    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    static var isFreshUITest: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestFresh") }

    static let shared: AppModel = makeModel()

    /// 撮影の日（決まった日にして、毎回同じ空にする）
    static func stageDate() -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 22, minute: 10)) ?? Date()
    }

    static func makeModel() -> AppModel {
        Lang.forcedJapanese = forcesJapanese
        if isFreshUITest {
            for key in ["progress", "onboarded", "sound", "haptics"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            let model = AppModel(persists: false, now: stageDate())
            model.soundOn = false
            model.still = true
            return model
        }
        guard isDemo || scene != nil else { return AppModel() }
        let model = AppModel(persists: false, now: stageDate())
        model.still = scene != nil
        let name = scene ?? ""
        model.onboarded = !name.hasPrefix("onboarding")
        model.onboardingPage = name == "onboarding2" ? 1 : (name == "onboarding3" ? 2 : 0)
        if name != "empty" && !name.hasPrefix("onboarding") {
            model.progress = sampleProgress(now: model.now)
        }
        return model
    }

    /// 見本の記録（使って 1 週間くらい）：6 日続けて遊び、札 6 枚
    static func sampleProgress(now: Date) -> Logbook {
        var p = Logbook()
        var rng = SeededRNG(seed: 24)
        let cal = Calendar.current
        for back in 1...6 {
            guard let d = cal.date(byAdding: .day, value: -back, to: now) else { continue }
            let key = Puzzle.key(d)
            let qs = Puzzle.daily(key)
            // 日がたつほど上手くなる（ずれが小さくなる）
            let spread = 4.0 + Double(back) * 2.2
            let answers = qs.map { q -> Answer in
                let lat = q.city.lat + (rng.unit() * 2 - 1) * spread
                let lon = q.city.lon + (rng.unit() * 2 - 1) * spread * 1.6
                let m = ((q.month - 1 + Int(rng.next() % 3) + 11) % 12) + 1
                return Answer(question: q, guessLat: lat, guessLon: lon, guessMonth: m, hints: back > 4 ? [.lines] : [])
            }
            p.days[key] = answers
            p.bestDaily = max(p.bestDaily, answers.reduce(0) { $0 + $1.score })
        }
        for key in p.days.keys.sorted() { for a in p.days[key] ?? [] { p.record(a) } }
        p.lore = [.clock, .polaris, .crux, .orion, .dipper, .scorpius]
        p.practiceDay = Puzzle.key(now)
        p.practiceUsed = 1
        p.paywallOffered = true
        return p
    }

    /// 撮影用の 1 問（決まった空）
    static func stageQuestion(_ city: String, month: Int, rotation: Double = 35) -> Question {
        Question(cityID: city, year: 2026, month: month, day: 15, localTime: 21.9, rotation: rotation)
    }

    static func run(_ model: AppModel) async {
        if isDemo {
            await Demo.play(model)
            return
        }
        guard let scene else { return }
        try? await Task.sleep(for: .milliseconds(150))
        let key = model.todayKey
        func session(_ qs: [Question], mode: Mode = .daily(key)) -> Session {
            Session(mode: mode, key: key, questions: qs)
        }
        let today = Puzzle.daily(key)
        switch scene {
        case "home", "wideHome": break
        case "sky", "hints", "wide", "hard":
            var s = session(scene == "hard" ? [stageQuestion("santiago", month: 4)] + today : [stageQuestion("madrid", month: 1)] + today)
            if scene == "hard" { s.mode = .hard; model.proOverride = true }
            if scene == "hints" { s.hints = [.lines, .compass, .milkyWay] }
            if scene == "wide" { s.pin = GeoPoint(lat: 44, lon: -2); s.month = 2; s.globe = GeoPoint(lat: 35, lon: 0) }
            model.session = s
        case "answer":
            var s = session([stageQuestion("madrid", month: 1)] + today)
            s.panel = .answer
            s.globe = GeoPoint(lat: 35, lon: 5)
            s.pin = GeoPoint(lat: 43.5, lon: -1.5)
            s.month = 2
            model.session = s
        case "result", "result2":
            let q = scene == "result" ? stageQuestion("madrid", month: 1) : stageQuestion("sydney", month: 7, rotation: 200)
            var s = session([q] + today)
            if scene == "result2" { s.answers = [Answer(question: today[0], guessLat: today[0].city.lat + 3, guessLon: today[0].city.lon - 4, guessMonth: today[0].month, hints: [])]; s.questions = [today[0], q] + Array(today.dropFirst().prefix(3)); s.index = 1 }
            s.panel = .answer
            s.pin = scene == "result" ? GeoPoint(lat: 44.2, lon: -1.6) : GeoPoint(lat: -27.5, lon: 153)
            s.month = scene == "result" ? 2 : 7
            if scene == "result" { model.progress.lore.remove(.polaris) } else { model.progress.lore.remove(.southPole); model.progress.lore.remove(.crux) }
            model.session = s
            model.submit()
        case "summary":
            var s = session(today)
            var rng = SeededRNG(seed: 5)
            s.answers = today.map { q in
                Answer(question: q, guessLat: q.city.lat + (rng.unit() * 2 - 1) * 5, guessLon: q.city.lon + (rng.unit() * 2 - 1) * 9, guessMonth: rng.next() % 2 == 0 ? q.month : q.month % 12 + 1, hints: [])
            }
            model.progress.days[key] = s.answers
            s.index = 4
            s.panel = .summary
            model.session = s
        case "lore": model.activeSheet = .lore
        case "stats", "empty": model.activeSheet = .stats
        case "statsPro":
            model.proOverride = true
            model.activeSheet = .stats
        case "settings": model.activeSheet = .settings
        case "paywall": model.activeSheet = .paywall
        case "archive":
            model.proOverride = true
            model.activeSheet = .archive
        default: break
        }
    }
}

/// デモの再生（YouTube の録画用。人の操作なしで約 18 秒）
/// 天文台 → 今日の空 → 星座の線 → 地球儀を回してピン → 月 → 答える（弧と点と読み方の札）→ 夜明けのまとめ
@MainActor
enum Demo {
    static func play(_ model: AppModel) async {
        func wait(_ s: Double) async { try? await Task.sleep(for: .milliseconds(Int(s * 1000))) }
        model.soundOn = true
        model.onboarded = true
        model.progress.lore.remove(.polaris)
        await wait(1.5)
        let key = model.todayKey
        let q = Launch.stageQuestion("paris", month: 1, rotation: 20)
        let rest = Array(Puzzle.daily(key).prefix(4))
        withAnimation(.easeInOut(duration: 0.4)) { model.session = Session(mode: .daily(key), key: key, questions: [q] + rest) }
        await wait(2.0)
        model.toggleHint(.lines)
        await wait(1.2)
        for _ in 0..<14 {
            model.turnSky(by: -1.5)
            await wait(0.05)
        }
        await wait(0.8)
        model.show(.answer)
        await wait(0.8)
        for i in 0...20 {
            let t = Double(i) / 20
            model.turnGlobe(lat: 20 + (45 - 20) * t, lon: 20 + (3 - 20) * t)
            await wait(0.04)
        }
        model.placePin(lat: 47.5, lon: 4.0)
        await wait(0.8)
        model.setMonth(1)
        await wait(0.8)
        model.submit()
        await wait(4.0)
        // 残りの 4 問は見本の答えで埋めて、夜明けのまとめへ
        guard var s = model.session else { return }
        var rng = SeededRNG(seed: 9)
        for q in rest {
            s.answers.append(Answer(question: q, guessLat: q.city.lat + (rng.unit() * 2 - 1) * 6, guessLon: q.city.lon + (rng.unit() * 2 - 1) * 10, guessMonth: q.month, hints: []))
        }
        s.index = s.answers.count - 1
        model.session = s
        model.next()
        await wait(4.0)
    }
}
