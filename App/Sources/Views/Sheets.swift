import StoreKit
import SwiftUI

struct SheetContent: View {
    let sheet: ActiveSheet

    var body: some View {
        switch sheet {
        case .lore: LoreSheet()
        case .stats: StatsSheet()
        case .settings: SettingsSheet()
        case .paywall: PaywallSheet()
        case .archive: ArchiveSheet()
        }
    }
}

/// シートの見出し（閉じるボタンつき）
struct SheetHeader: View {
    @Environment(AppModel.self) private var model
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Face.title(26)).foregroundStyle(Ink.ivory)
                if let subtitle {
                    Text(subtitle).font(Face.body(13)).foregroundStyle(Ink.mist).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Button { model.press(); model.activeSheet = nil } label: { Image(systemName: "xmark") }
                .buttonStyle(BrassIconStyle())
                .accessibilityLabel(tr("閉じる", "Close"))
                .accessibilityIdentifier("main.close")
        }
        .padding(.top, Space.l)
    }
}

// MARK: - 読み方の札

struct LoreSheet: View {
    @Environment(AppModel.self) private var model
    private static let sample = Question(cityID: "capetown", year: 2026, month: 7, day: 15, localTime: 22, rotation: 0)
    private static let north = Question(cityID: "tokyo", year: 2026, month: 1, day: 15, localTime: 22, rotation: 0)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                SheetHeader(title: tr("読み方の札", "Lore cards"),
                            subtitle: trf("%d / %d 枚。答えのあとに、その空に当てはまる札が 1 枚ずつ集まる", "%d of %d. After each answer you earn the card that fits that sky.", model.progress.lore.count, Lore.allCases.count))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.s), GridItem(.flexible(), spacing: Space.s)], spacing: Space.s) {
                    ForEach(Lore.allCases) { lore in
                        card(lore, owned: model.progress.lore.contains(lore))
                    }
                }
            }
            .padding(.horizontal, Space.m)
            .padding(.bottom, Space.xl)
        }
        .scrollIndicators(.hidden)
    }

    private func card(_ lore: Lore, owned: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if owned {
                    SkyDomeView(question: [.crux, .southPole, .canopus, .scorpius].contains(lore) ? Self.sample : Self.north,
                                hints: [], highlight: lore.constellations, still: true, interactive: false)
                } else {
                    Circle().strokeBorder(Ink.brass.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    Image(systemName: "lock").foregroundStyle(Ink.brass.opacity(0.6))
                }
            }
            .frame(height: 96)
            .frame(maxWidth: .infinity)
            Text(owned ? lore.title : tr("まだ見ていない空", "Not yet seen"))
                .font(Face.heading(14)).foregroundStyle(owned ? Ink.ivory : Ink.mist)
                .lineLimit(2).minimumScaleFactor(0.8)
            if owned {
                Text(lore.rule).font(Face.body(11)).foregroundStyle(Ink.mist).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Space.s)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .brassPlate(radius: Radius.small, fill: Ink.night.opacity(owned ? 0.9 : 0.5))
    }
}

// MARK: - 記録

struct StatsSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let p = model.progress
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                SheetHeader(title: tr("観測の記録", "Records"), subtitle: tr("読み方を覚えるほど、当たる距離が縮む", "The more you can read, the closer you land"))
                if p.samples.isEmpty {
                    empty
                } else {
                    HStack(spacing: Space.s) {
                        big(tr("最高（毎日）", "Best day"), p.bestDaily.formatted())
                        big(tr("連続", "Streak"), trf("%d 日", "%d days", model.streak))
                        big(tr("答えた空", "Skies"), "\(p.samples.count)")
                    }
                    if let t = p.trend() {
                        trendPlate(t)
                    }
                    continents(p)
                }
            }
            .padding(.horizontal, Space.m)
            .padding(.bottom, Space.xl)
        }
        .scrollIndicators(.hidden)
    }

    private var empty: some View {
        VStack(spacing: Space.s) {
            Image(systemName: "scope").font(.system(size: 30, weight: .light)).foregroundStyle(Ink.brass)
            Text(tr("まだ記録がない", "No records yet")).font(Face.heading(17)).foregroundStyle(Ink.ivory)
            Text(tr("今日の 5 問を答えると、距離と点がここにたまる", "Answer today's five skies and your distances will gather here"))
                .font(Face.body(13)).foregroundStyle(Ink.mist).multilineTextAlignment(.center)
            Button { model.activeSheet = nil; model.startDaily() } label: { Text(tr("今日の 5 問へ", "Go to today's skies")) }
                .buttonStyle(BrassButtonStyle())
                .padding(.top, Space.s)
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity)
        .brassPlate()
    }

    private func big(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Face.engraved(20)).foregroundStyle(Ink.brassLight).lineLimit(1).minimumScaleFactor(0.6)
            Text(title).font(Face.label(11)).foregroundStyle(Ink.mist)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .brassPlate()
    }

    private func trendPlate(_ t: (recent: Double, before: Double)) -> some View {
        let better = t.recent < t.before
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("最近 10 問の平均距離", "Average distance, last 10")).font(Face.label(12)).foregroundStyle(Ink.mist)
                Text("\(Int(t.recent.rounded()).formatted()) km").font(Face.engraved(24)).foregroundStyle(Ink.ivory)
            }
            Spacer()
            Text(better ? trf("%@ km 縮んだ", "%@ km closer", Int((t.before - t.recent).rounded()).formatted()) : tr("次の札で縮む", "Next card will help"))
                .font(Face.label(12)).foregroundStyle(better ? Ink.truth : Ink.mist)
        }
        .padding(Space.m)
        .brassPlate()
    }

    private func continents(_ p: Logbook) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text(tr("大陸ごとの平均距離", "Average distance by continent")).font(Face.heading(16)).foregroundStyle(Ink.ivory)
                Spacer()
                if !model.isPro { Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(Ink.brass) }
            }
            let rows = p.averageDistance()
            let maxKm = max(1, rows.map(\.1).max() ?? 1)
            ForEach(rows, id: \.0) { row in
                let (c, km, n) = row
                HStack(spacing: Space.s) {
                    Text(c.title).font(Face.body(13)).foregroundStyle(Ink.ivory).frame(width: 104, alignment: .leading).lineLimit(1).minimumScaleFactor(0.7)
                    GeometryReader { g in
                        Capsule().fill(Ink.brassGradient).frame(width: max(4, g.size.width * km / maxKm))
                    }
                    .frame(height: 8)
                    Text(model.isPro ? "\(Int(km.rounded()).formatted()) km" : "— km").font(Face.engraved(12)).foregroundStyle(Ink.brassLight).frame(width: 72, alignment: .trailing)
                }
                .blur(radius: model.isPro ? 0 : 3)
                .accessibilityLabel("\(c.title) \(n)")
            }
            if !model.isPro {
                Button { model.press(); model.activeSheet = .paywall } label: { Text(tr("Pro で大陸ごとの苦手を見る", "See weak continents with Pro")) }
                    .buttonStyle(BrassButtonStyle(prominent: false))
            }
        }
        .padding(Space.m)
        .brassPlate()
    }
}

// MARK: - 設定

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                SheetHeader(title: tr("設定", "Settings"))
                VStack(spacing: 0) {
                    Toggle(tr("音", "Sound"), isOn: Binding(get: { model.soundOn }, set: { model.setSound($0) }))
                        .padding(.vertical, Space.s)
                    Rectangle().fill(Ink.brass.opacity(0.25)).frame(height: 0.5)
                    Toggle(tr("振動", "Haptics"), isOn: Binding(get: { model.hapticsOn }, set: { model.setHaptics($0) }))
                        .padding(.vertical, Space.s)
                }
                .tint(Ink.brass)
                .font(Face.body(15))
                .foregroundStyle(Ink.ivory)
                .padding(.horizontal, Space.m)
                .brassPlate()

                VStack(alignment: .leading, spacing: Space.s) {
                    Text(model.isPro ? tr("Pro を使っています", "You have Pro") : tr("Pro（買い切り）", "Pro (one-time)"))
                        .font(Face.heading(17)).foregroundStyle(Ink.ivory)
                    Text(tr("練習を無制限・過去 30 日の空・難しい空・南米/アフリカ/極地の都市・大陸ごとの記録", "Unlimited practice, the last 30 days, hard skies, extra cities in South America, Africa and the poles, and continent records"))
                        .font(Face.body(13)).foregroundStyle(Ink.mist).fixedSize(horizontal: false, vertical: true)
                    if !model.isPro {
                        Button { model.press(); model.activeSheet = .paywall } label: { Text(tr("Pro を見る", "See Pro")) }
                            .buttonStyle(BrassButtonStyle())
                    }
                    Button { Task { await model.restore() } } label: { Text(tr("購入を復元", "Restore purchase")) }
                        .buttonStyle(BrassButtonStyle(prominent: false))
                }
                .padding(Space.m)
                .brassPlate()

                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("この空について", "About these skies")).font(Face.heading(15)).foregroundStyle(Ink.ivory)
                    Text(trf("明るい星 %d 個（公的な星表の値）と星座 %d 個、都市 %d か所を端末の中に持っている。位置情報もネットも使わない。記録はこの端末の中だけ。", "%d bright stars (from public catalogs), %d constellations and %d cities, all stored on this device. No location access, no network. Your records stay on this device.", StarCatalog.stars.count, StarCatalog.constellations.count, CityBook.all.count))
                        .font(Face.body(12)).foregroundStyle(Ink.mist).fixedSize(horizontal: false, vertical: true)
                }
                .padding(Space.m)
                .brassPlate()
            }
            .padding(.horizontal, Space.m)
            .padding(.bottom, Space.xl)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Pro

struct PaywallSheet: View {
    @Environment(AppModel.self) private var model
    @State private var buying = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                SheetHeader(title: tr("天文台の Pro", "Observatory Pro"), subtitle: tr("一度買えば、ずっと。広告もサブスクもない", "Buy once, keep forever. No ads, no subscription."))
                ForEach(rows, id: \.0) { row in
                    let (icon, title, text) = row
                    HStack(alignment: .top, spacing: Space.m) {
                        Image(systemName: icon).font(.system(size: 20, weight: .light)).foregroundStyle(Ink.brassLight).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(Face.heading(16)).foregroundStyle(Ink.ivory)
                            Text(text).font(Face.body(13)).foregroundStyle(Ink.mist).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, Space.xs)
                Text(tr("毎日の 5 問・ヒント・読み方の札・共有は、ずっと無料。", "Daily skies, hints, lore cards and sharing stay free forever."))
                    .font(Face.body(13)).foregroundStyle(Ink.ivory)
                    .padding(Space.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .brassPlate()
                if model.purchases.loadState == .unavailable {
                    Text(tr("App Store につながらない。電波のある所でもう一度開いてください", "Can't reach the App Store. Try again when you're online."))
                        .font(Face.body(12)).foregroundStyle(Ink.truth)
                }
            }
            .padding(.horizontal, Space.m)
            .padding(.bottom, Space.l)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Space.s) {
                Button {
                    model.press()
                    buying = true
                    Task { await model.buyPro(); buying = false; if model.isPro { model.activeSheet = nil } }
                } label: {
                    Text(model.isPro ? tr("Pro を使っています", "You have Pro") : trf("Pro にする %@", "Get Pro %@", priceText))
                }
                .buttonStyle(BrassButtonStyle())
                .disabled(model.isPro || buying)
                .accessibilityIdentifier("main.buy")
                Button { Task { await model.restore() } } label: { Text(tr("購入を復元", "Restore purchase")).font(Face.label(13)) }
                    .foregroundStyle(Ink.brassLight)
                    .accessibilityIdentifier("main.restore")
            }
            .padding(.horizontal, Space.m)
            .padding(.vertical, Space.s)
            .background(Ink.nightDeep.opacity(0.95).ignoresSafeArea().allowsHitTesting(false))
        }
    }

    private var priceText: String {
        model.purchases.products.first?.displayPrice ?? (Lang.isJapanese ? "¥480" : "$2.99")
    }

    private var rows: [(String, String, String)] {
        [
            ("scope", tr("練習を無制限", "Unlimited practice"), tr("無料は 1 日 3 回。読み方を覚えたいときに、何度でも", "Free is 3 a day. Practice as much as you like.")),
            ("calendar", tr("過去 30 日の空", "The last 30 days"), tr("見逃した日の 5 問を、あとから遊べる", "Play the daily skies you missed")),
            ("moon.haze", tr("難しい空", "Hard skies"), tr("街あかりで暗い星が消え、星座の線も使えない", "City glow hides faint stars, and lines are off")),
            ("globe.americas", tr("16 の都市を追加", "16 more cities"), tr("南米・アフリカ・極地（マクマード基地・ロングイェールビーン）", "South America, Africa and the poles (McMurdo, Longyearbyen)")),
            ("chart.bar.xaxis", tr("大陸ごとの記録", "Continent records"), tr("どこの空が苦手か、平均距離で分かる", "See which skies you misread, by average distance")),
        ]
    }
}

// MARK: - 過去の問題

struct ArchiveSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                SheetHeader(title: tr("過去の空", "Past skies"), subtitle: tr("見逃した日の 5 問。終えた日は点が残る", "Daily skies you missed. Finished days keep their score."))
                VStack(spacing: 0) {
                    ForEach(Array(model.archiveKeys.enumerated()), id: \.offset) { i, key in
                        Button { model.startArchive(key) } label: {
                            HStack {
                                Text(key.replacingOccurrences(of: "-", with: "/")).font(Face.engraved(15)).foregroundStyle(Ink.ivory)
                                Spacer()
                                if let total = model.progress.days[key].map({ $0.reduce(0) { $0 + $1.score } }) ?? model.progress.archive[key] {
                                    Text(total.formatted()).font(Face.engraved(14)).foregroundStyle(Ink.brassLight)
                                } else {
                                    Text(tr("未挑戦", "New")).font(Face.label(12)).foregroundStyle(Ink.mist)
                                }
                                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Ink.brass)
                            }
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(i == 0 ? "main.archiveFirst" : "archive.\(key)")
                        if i < model.archiveKeys.count - 1 { Rectangle().fill(Ink.brass.opacity(0.2)).frame(height: 0.5) }
                    }
                }
                .padding(.horizontal, Space.m)
                .brassPlate()
            }
            .padding(.horizontal, Space.m)
            .padding(.bottom, Space.xl)
        }
        .scrollIndicators(.hidden)
    }
}
