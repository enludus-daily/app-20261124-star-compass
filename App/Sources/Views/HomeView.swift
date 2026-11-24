import SwiftUI

/// 天文台（ホーム）：今日の 5 問・連続日数・練習・読み方の札・記録
struct HomeView: View {
    @Environment(AppModel.self) private var model

    /// 飾りの空（毎日の問題を明かさないよう、決まった空：11 月のレイキャビク）
    private static let showcase = Question(cityID: "reykjavik", year: 2026, month: 11, day: 24, localTime: 22, rotation: 0)

    var body: some View {
        ZStack {
            Ink.nightGradient.ignoresSafeArea().allowsHitTesting(false)
            StarDust(count: 160, seed: 11).ignoresSafeArea()
            // 主なボタンをスクロールの外に置く（小さい画面では天球が縮む）
            VStack(spacing: Space.m) {
                topBar
                dome
                todayPlate
                tools
                proRow
            }
            .padding(.horizontal, Space.m)
            .padding(.bottom, Space.s)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button { model.startDaily() } label: { Text(dailyLabel) }
                .buttonStyle(BrassButtonStyle())
                .accessibilityIdentifier("main.daily")
                .padding(.horizontal, Space.m)
                .padding(.vertical, Space.s)
                .background(Ink.nightDeep.opacity(0.9).ignoresSafeArea().allowsHitTesting(false))
        }
    }

    private var dailyLabel: String {
        let n = model.progress.days[model.todayKey]?.count ?? 0
        if n >= Puzzle.perDay { return tr("今日の結果を見る", "See today's result") }
        if n > 0 { return trf("続きから（%d/5）", "Continue (%d/5)", n) }
        return tr("今日の 5 問をはじめる", "Start today's five skies")
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("ほしよみ天文台", "Star Compass"))
                    .font(Face.title(30)).foregroundStyle(Ink.ivory)
                Text(tr("夜空から、地球のどこの何月かを当てる", "Read a night sky. Guess where on Earth, and when."))
                    .font(Face.body(13)).foregroundStyle(Ink.mist)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button { model.press(); model.activeSheet = .settings } label: { Image(systemName: "gearshape") }
                .buttonStyle(BrassIconStyle())
                .accessibilityLabel(tr("設定", "Settings"))
                .accessibilityIdentifier("main.settings")
        }
        .padding(.top, Space.s)
    }

    private var dome: some View {
        ZStack(alignment: .bottom) {
            SkyDomeView(question: Self.showcase, hints: [.lines], still: model.still || model.reduceMotion, interactive: false)
                .frame(maxWidth: 300, maxHeight: .infinity)
            // 天文台の台座
            Capsule()
                .fill(Ink.brassGradient)
                .frame(width: 140, height: 8)
                .offset(y: 6)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private var todayPlate: some View {
        let key = model.todayKey
        let answers = model.progress.days[key] ?? []
        return VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text(tr("今日の 5 問", "Today's five skies")).font(Face.heading(18)).foregroundStyle(Ink.ivory)
                Spacer()
                Text(key.replacingOccurrences(of: "-", with: "/")).font(Face.engraved(13)).foregroundStyle(Ink.brassLight)
            }
            HStack(spacing: Space.s) {
                ForEach(0..<Puzzle.perDay, id: \.self) { i in
                    ZStack {
                        Circle().strokeBorder(Ink.brass.opacity(0.6), lineWidth: 1)
                        if i < answers.count { Text(Scoring.moon(answers[i].score)).font(.system(size: 20)) }
                    }
                    .frame(width: 36, height: 36)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(dayCount(model.streak)).font(Face.engraved(20)).foregroundStyle(Ink.brassLight)
                    Text(tr("連続", "Streak")).font(Face.label(11)).foregroundStyle(Ink.mist)
                }
            }
            Text(answers.count >= Puzzle.perDay
                 ? trf("今日は %@ 点。明日も新しい空が来る", "Today: %@ points. New skies tomorrow.", model.progress.total(key).formatted())
                 : tr("世界のみんなと同じ 5 つの空。月の満ち欠けで結果を共有できる", "Everyone gets the same five skies. Share your moons."))
                .font(Face.body(13)).foregroundStyle(Ink.mist)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.m)
        .brassPlate()
    }

    private var tools: some View {
        HStack(spacing: Space.s) {
            tool(icon: "scope", title: tr("練習", "Practice"),
                 value: model.isPro ? tr("無制限", "Unlimited") : trf("残り %d", "%d left", model.practiceLeft),
                 id: "main.practice") { model.startPractice() }
            tool(icon: "rectangle.stack", title: tr("読み方の札", "Lore cards"),
                 value: "\(model.progress.lore.count)/\(Lore.allCases.count)", id: "main.lore") { model.press(); model.activeSheet = .lore }
            tool(icon: "chart.xyaxis.line", title: tr("記録", "Records"),
                 value: model.progress.samples.isEmpty ? "—" : averageText, id: "main.stats") { model.press(); model.activeSheet = .stats }
        }
    }

    private var averageText: String {
        let s = model.progress.samples.suffix(10)
        let avg = s.reduce(0) { $0 + $1.distanceKm } / Double(max(1, s.count))
        return "\(Int(avg.rounded()).formatted()) km"
    }

    private func tool(icon: String, title: String, value: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18, weight: .light)).foregroundStyle(Ink.brassLight)
                Text(title).font(Face.label(12)).foregroundStyle(Ink.ivory).lineLimit(1).minimumScaleFactor(0.7)
                Text(value).font(Face.engraved(13)).foregroundStyle(Ink.brassLight).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .brassPlate()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private var proRow: some View {
        HStack(spacing: Space.s) {
            proTool(icon: "moon.haze", title: tr("難しい空", "Hard skies"), note: tr("街あかり・線なし", "City glow, no lines"), id: "main.hard") { model.startHard() }
            proTool(icon: "calendar", title: tr("過去の問題", "Past skies"), note: tr("30 日分", "Last 30 days"), id: "main.archive") {
                model.press()
                model.activeSheet = model.isPro ? .archive : .paywall
            }
        }
    }

    private func proTool(icon: String, title: String, note: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.s) {
                Image(systemName: icon).font(.system(size: 18, weight: .light)).foregroundStyle(Ink.brassLight)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Face.label(13)).foregroundStyle(Ink.ivory)
                    Text(note).font(Face.body(11)).foregroundStyle(Ink.mist).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                if !model.isPro {
                    Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(Ink.brass)
                }
            }
            .padding(Space.m)
            .frame(maxWidth: .infinity, minHeight: 60)
            .brassPlate(fill: Ink.nightSoft.opacity(0.6))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

/// はじめての案内（3 ページ）
struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    private static let demoNorth = Question(cityID: "paris", year: 2026, month: 1, day: 15, localTime: 22, rotation: 0)
    private static let demoSouth = Question(cityID: "sydney", year: 2026, month: 7, day: 15, localTime: 22, rotation: 0)

    var body: some View {
        let page = model.onboardingPage
        ZStack {
            Ink.nightGradient.ignoresSafeArea().allowsHitTesting(false)
            StarDust(count: 120, seed: 5).ignoresSafeArea()
            VStack(spacing: Space.l) {
                Spacer(minLength: Space.s)
                Group {
                    switch page {
                    case 0:
                        SkyDomeView(question: Self.demoNorth, hints: [.lines], still: model.still || model.reduceMotion, interactive: false)
                    case 1:
                        SkyDomeView(question: Self.demoSouth, hints: [.compass], highlight: ["Cru", "Sco"], still: true, interactive: false)
                    default:
                        GlobeView(center: GeoPoint(lat: 10, lon: 140), pin: GeoPoint(lat: -30, lon: 145), truth: GeoPoint(lat: -33.87, lon: 151.21), interactive: false, axID: "onboard.globe")
                    }
                }
                .frame(maxWidth: 300, maxHeight: 300)
                .padding(.horizontal, Space.l)
                VStack(spacing: Space.s) {
                    Text(title(page)).font(Face.title(26)).foregroundStyle(Ink.ivory).multilineTextAlignment(.center)
                    Text(text(page)).font(Face.body(15)).foregroundStyle(Ink.mist).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Space.l)
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().fill(i == page ? Ink.brassLight : Ink.brass.opacity(0.35)).frame(width: 7, height: 7)
                    }
                }
                Spacer(minLength: Space.s)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if page < 2 {
                    Button {
                        model.press()
                        withAnimation(.easeInOut(duration: 0.35)) { model.onboardingPage += 1 }
                    } label: { Text(tr("次へ", "Next")) }
                    .buttonStyle(BrassButtonStyle())
                    .accessibilityIdentifier("main.onboardNext")
                } else {
                    Button { model.setOnboarded() } label: { Text(tr("天文台に入る", "Enter the observatory")) }
                        .buttonStyle(BrassButtonStyle())
                        .accessibilityIdentifier("main.onboardStart")
                }
            }
            .padding(.horizontal, Space.m)
            .padding(.vertical, Space.s)
        }
    }

    private func title(_ p: Int) -> String {
        switch p {
        case 0: tr("この夜空は、どこの空？", "Whose night sky is this?")
        case 1: tr("星が、場所と季節を教える", "The stars tell place and season")
        default: tr("地球儀に刺して、月を選ぶ", "Pin the globe, pick the month")
        }
    }

    private func text(_ p: Int) -> String {
        switch p {
        case 0: tr("地球のどこかの、ある月の夜 10 時の全天。毎日 5 つ、世界のみんなと同じ空が届く。", "A whole sky at 10 p.m., somewhere on Earth, in some month. Five new skies every day, the same for everyone.")
        case 1: tr("北極星の高さは緯度。南十字が見えたら南の国。南北の線にある星座で月が分かる。時計の差は経度。", "Polaris's height is your latitude. The Southern Cross means south. What sits on the meridian gives the month. The clock gap gives longitude.")
        default: tr("近いほど点が高い（1 問 5,000 点）。答えのあとに「この空の読み方」の札が 1 枚ずつ集まる。", "Closer means more points (5,000 per sky). After each answer, you collect a card on how to read that sky.")
        }
    }
}
