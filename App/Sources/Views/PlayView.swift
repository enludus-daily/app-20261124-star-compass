import SwiftUI

/// 5 問を遊ぶ画面：空を見る → 地球儀と月で答える → 結果 →（5 問目のあと）夜明けのまとめ
struct PlayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        if let s = model.session {
            ZStack {
                background(s)
                VStack(spacing: Space.s) {
                    if s.panel != .summary { header(s) }
                    content(s)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, Space.m)
                .padding(.top, Space.s)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar(s)
                    .padding(.horizontal, Space.m)
                    .padding(.top, Space.s)
                    .padding(.bottom, Space.s)
                    .background(Ink.nightDeep.opacity(s.panel == .summary ? 0 : 0.85).ignoresSafeArea().allowsHitTesting(false))
            }
        }
    }

    private var wide: Bool { hSize == .regular }

    @ViewBuilder private func background(_ s: Session) -> some View {
        ZStack {
            Ink.nightGradient
            if s.panel == .result || s.panel == .summary {
                Ink.dawnGradient.opacity(s.panel == .summary ? 1 : 0.55).transition(.opacity)
            }
            StarDust(count: 90, seed: 3).opacity(s.panel == .summary ? 0.4 : 1)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - 上の帯

    private func header(_ s: Session) -> some View {
        VStack(spacing: Space.s) {
            HStack(spacing: Space.s) {
                Button { model.quit() } label: { Image(systemName: "xmark") }
                    .buttonStyle(BrassIconStyle())
                    .accessibilityLabel(tr("やめる", "Quit"))
                    .accessibilityIdentifier("main.quit")
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    ForEach(0..<s.questions.count, id: \.self) { i in
                        let done = i < s.answers.count
                        ZStack {
                            Circle().strokeBorder(i == s.index ? Ink.brassLight : Ink.brass.opacity(0.5), lineWidth: i == s.index ? 1.5 : 0.8)
                            if done { Text(Scoring.moon(s.answers[i].score)).font(.system(size: 13)) }
                        }
                        .frame(width: 24, height: 24)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(trf("%d 問目", "Question %d", s.index + 1))
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(modeTitle(s.mode)).font(Face.label(10)).foregroundStyle(Ink.mist).tracking(1)
                    Text(s.total.formatted()).font(Face.engraved(18)).foregroundStyle(Ink.brassLight)
                        .contentTransition(.numericText())
                }
                .frame(minWidth: 64, alignment: .trailing)
            }
            if s.panel != .result {
                clockPlate(s.current)
            }
        }
    }

    private func modeTitle(_ m: Mode) -> String {
        switch m {
        case .daily: tr("今日", "TODAY")
        case .practice: tr("練習中", "PRACTICE")
        case .hard: tr("難しい空の練習", "HARD SKY")
        case .archive(let k): k.replacingOccurrences(of: "-", with: "/")
        }
    }

    private func clockPlate(_ q: Question) -> some View {
        HStack(spacing: Space.m) {
            BrassClock(hours: q.clock).frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(tr("グリニッジの時計", "Greenwich clock")).font(Face.label(12)).foregroundStyle(Ink.brassLight)
                    Text(clockText(q.clock)).font(Face.engraved(17)).foregroundStyle(Ink.ivory)
                }
                Text(tr("この空は、その土地の夜 10 時ごろ", "This sky is about 10 p.m. local time"))
                    .font(Face.body(12)).foregroundStyle(Ink.mist)
                    .lineLimit(2).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.s)
        .brassPlate()
    }

    private func clockText(_ h: Double) -> String {
        let hh = Int(h), mm = Int((h - Double(hh)) * 60)
        return String(format: "%02d:%02d", hh, mm)
    }

    // MARK: - 中身

    @ViewBuilder private func content(_ s: Session) -> some View {
        switch s.panel {
        case .sky, .answer:
            if wide {
                HStack(spacing: Space.l) {
                    sky(s)
                    answerPanel(s)
                }
            } else if s.panel == .sky {
                sky(s).transition(.opacity)
            } else {
                answerPanel(s).transition(.opacity)
            }
        case .result:
            ResultPanel(session: s)
        case .summary:
            SummaryView(session: s)
        }
    }

    private func sky(_ s: Session) -> some View {
        VStack(spacing: Space.s) {
            SkyDomeView(question: s.current, turn: s.skyTurn, hints: s.hints, hard: s.isHard, still: model.still || model.reduceMotion) { d in
                model.turnSky(by: d)
            }
            Text(tr("指で回せる。北極星・南十字・南北の線の星座を探そう", "Drag to turn. Look for Polaris, the Southern Cross, and what sits on the meridian."))
                .font(Face.body(12))
                .foregroundStyle(Ink.mist)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private func answerPanel(_ s: Session) -> some View {
        VStack(spacing: Space.m) {
            GlobeView(center: s.globe, pin: s.pin, onTurn: { model.turnGlobe(lat: $0.lat, lon: $0.lon) }, onPin: { model.placePin(lat: $0.lat, lon: $0.lon) })
            Text(s.pin == nil ? tr("地球儀を回して、空を見た場所に触れる", "Spin the globe and tap where this sky was seen") : pinText(s.pin))
                .font(Face.body(13))
                .foregroundStyle(s.pin == nil ? Ink.mist : Ink.guess)
                .lineLimit(1).minimumScaleFactor(0.8)
            MonthDial(selected: s.month) { model.setMonth($0) }
                .padding(Space.m)
                .brassPlate()
        }
    }

    private func pinText(_ p: GeoPoint?) -> String {
        guard let p else { return "" }
        let ns = p.lat >= 0 ? tr("北緯", "N") : tr("南緯", "S")
        let ew = p.lon >= 0 ? tr("東経", "E") : tr("西経", "W")
        if Lang.isJapanese {
            return "\(ns) \(Int(abs(p.lat).rounded()))°  \(ew) \(Int(abs(p.lon).rounded()))°"
        }
        return "\(Int(abs(p.lat).rounded()))°\(ns)  \(Int(abs(p.lon).rounded()))°\(ew)"
    }

    // MARK: - 下の帯（主なボタンは画面の下に固定）

    @ViewBuilder private func bottomBar(_ s: Session) -> some View {
        switch s.panel {
        case .sky, .answer:
            VStack(spacing: Space.s) {
                if s.panel == .sky || wide { hintRow(s) }
                HStack(spacing: Space.s) {
                    if wide {
                        submitButton(s)
                    } else if s.panel == .sky {
                        Button { model.show(.answer) } label: {
                            Label(tr("答えを置く", "Place answer"), systemImage: "globe.europe.africa")
                        }
                        .buttonStyle(BrassButtonStyle())
                        .accessibilityIdentifier("main.toAnswer")
                    } else {
                        Button { model.show(.sky) } label: {
                            Label(tr("空", "Sky"), systemImage: "sparkles")
                        }
                        .buttonStyle(BrassButtonStyle(prominent: false))
                        .frame(width: 112)
                        .accessibilityIdentifier("main.toSky")
                        submitButton(s)
                    }
                }
            }
        case .result:
            Button { model.next() } label: {
                Text(s.answers.count >= s.questions.count ? tr("夜明けの結果へ", "See the dawn") : tr("次の空へ", "Next sky"))
            }
            .buttonStyle(BrassButtonStyle())
            .accessibilityIdentifier("main.next")
        case .summary:
            HStack(spacing: Space.s) {
                ShareLink(item: model.shareText()) {
                    Label(tr("共有", "Share"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(BrassButtonStyle(prominent: false))
                .frame(width: 128)
                .accessibilityIdentifier("main.share")
                Button { model.quit() } label: { Text(tr("天文台へ戻る", "Back to observatory")) }
                    .buttonStyle(BrassButtonStyle())
                    .accessibilityIdentifier("main.home")
            }
        }
    }

    private func submitButton(_ s: Session) -> some View {
        Button { model.submit() } label: {
            Text(s.canAnswer ? tr("答える", "Answer") : (s.pin == nil ? tr("場所に触れて", "Tap a place") : tr("月を選んで", "Pick a month")))
        }
        .buttonStyle(BrassButtonStyle())
        .opacity(s.canAnswer ? 1 : 0.55)
        .disabled(!s.canAnswer)
        .accessibilityIdentifier("main.submit")
    }

    private func hintRow(_ s: Session) -> some View {
        HStack(spacing: Space.s) {
            ForEach(Hint.allCases, id: \.self) { h in
                let on = s.hints.contains(h)
                let locked = s.isHard && h == .lines
                Button { model.toggleHint(h) } label: {
                    VStack(spacing: 1) {
                        Text(h.title).font(Face.label(12)).lineLimit(1).minimumScaleFactor(0.7)
                        Text(locked ? tr("なし", "off") : "−20%").font(Face.engraved(10))
                    }
                    .foregroundStyle(on ? Ink.nightDeep : Ink.brassLight)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                            .fill(on ? AnyShapeStyle(Ink.brassGradient) : AnyShapeStyle(Ink.nightSoft.opacity(0.9)))
                            .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).strokeBorder(Ink.brass.opacity(0.6), lineWidth: 0.8))
                            .allowsHitTesting(false)
                    )
                    .opacity(locked ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .disabled(locked)
                .accessibilityIdentifier("hint.\(h.rawValue)")
            }
        }
    }
}

/// 1 問の結果：地球儀の弧・距離・点・この空の読み方
struct ResultPanel: View {
    @Environment(AppModel.self) private var model
    let session: Session

    var body: some View {
        if let a = session.answers.last {
            ScrollView {
                VStack(spacing: Space.m) {
                    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: model.still)) { tl in
                        let t = model.still ? 1 : min(1, tl.date.timeIntervalSince(model.revealAt) / 1.1)
                        GlobeView(center: session.globe, pin: GeoPoint(lat: a.guessLat, lon: a.guessLon), truth: GeoPoint(lat: a.question.city.lat, lon: a.question.city.lon), arc: t, interactive: true, onTurn: { model.turnGlobe(lat: $0.lat, lon: $0.lon) })
                            .frame(maxHeight: 250)
                    }
                    scorePlate(a)
                    if let lore = session.lore {
                        LoreCard(lore: lore, question: a.question, isNew: session.newLore)
                    }
                }
                .padding(.bottom, Space.l)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func scorePlate(_ a: Answer) -> some View {
        VStack(spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("答え", "Answer")).font(Face.label(11)).foregroundStyle(Ink.mist).tracking(1)
                    Text("\(a.question.city.name) · \(Lore.monthShort(a.question.month))")
                        .font(Face.heading(21)).foregroundStyle(Ink.truth)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                Spacer()
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: model.still)) { tl in
                    let t = model.still ? 1 : min(1, tl.date.timeIntervalSince(model.revealAt) / 1.2)
                    Text(Int(Double(a.score) * t).formatted())
                        .font(Face.engraved(32)).foregroundStyle(Ink.brassLight)
                }
            }
            Rectangle().fill(Ink.brass.opacity(0.35)).frame(height: 0.5)
            HStack(alignment: .top) {
                stat(tr("距離", "Distance"), "\(Int(a.distanceKm.rounded()).formatted()) km", color: Ink.guess)
                stat(tr("場所", "Place"), Scoring.location(distanceKm: a.distanceKm).formatted())
                stat(tr("季節", "Season"), trf("%d（%@）", "%d (%@)", Scoring.season(guess: a.guessMonth, answer: a.question.month), Lore.monthShort(a.guessMonth)))
                if !a.hints.isEmpty {
                    stat(tr("ヒント", "Hints"), "×\(String(format: "%.1f", Scoring.multiplier(hints: a.hints.count)))")
                }
            }
        }
        .padding(Space.m)
        .brassPlate(fill: Ink.nightDeep.opacity(0.8))
    }

    private func stat(_ title: String, _ value: String, color: Color = Ink.ivory) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Face.label(11)).foregroundStyle(Ink.mist)
            Text(value).font(Face.engraved(15)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 読み方の札（答えのあとに 1 枚。初めてなら光る）
struct LoreCard: View {
    @Environment(AppModel.self) private var model
    let lore: Lore
    let question: Question
    var isNew = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text(tr("この空の読み方", "How to read this sky")).font(Face.label(11)).foregroundStyle(Ink.brassLight).tracking(1.2)
                Spacer()
                if isNew {
                    Text(tr("新しい札", "NEW CARD"))
                        .font(Face.label(10)).foregroundStyle(Ink.nightDeep)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Ink.truth))
                }
            }
            HStack(alignment: .top, spacing: Space.m) {
                SkyDomeView(question: question, hints: lore == .clock ? [] : [.compass], highlight: lore.constellations, still: true, interactive: false)
                    .frame(width: 120, height: 120)
                VStack(alignment: .leading, spacing: 6) {
                    Text(lore.title).font(Face.heading(17)).foregroundStyle(Ink.ivory).fixedSize(horizontal: false, vertical: true)
                    Text(lore.rule).font(Face.body(13)).foregroundStyle(Ink.mist).fixedSize(horizontal: false, vertical: true)
                    Text(lore.detail(for: question)).font(Face.body(13).weight(.semibold)).foregroundStyle(Ink.truth).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Space.m)
        .brassPlate(fill: Ink.nightDeep.opacity(0.8))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.plate, style: .continuous)
                .strokeBorder(Ink.truth.opacity(isNew ? 0.8 : 0), lineWidth: 1.5)
                .allowsHitTesting(false)
        )
    }
}

/// 5 問のあと：夜明けの色で合計・称号・月の満ち欠け
struct SummaryView: View {
    @Environment(AppModel.self) private var model
    let session: Session

    var body: some View {
        ScrollView {
            VStack(spacing: Space.l) {
                Spacer(minLength: Space.l)
                Text(tr("夜が明けた", "Dawn breaks"))
                    .font(Face.title(30)).foregroundStyle(Ink.ivory)
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: model.still)) { tl in
                    let t = model.still ? 1 : min(1, tl.date.timeIntervalSince(model.revealAt) / 1.4)
                    Text(Int(Double(session.total) * t).formatted())
                        .font(.system(size: 54, weight: .light, design: .serif).monospacedDigit())
                        .foregroundStyle(Ink.brassLight)
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                }
                Text(Scoring.title(total: session.total))
                    .font(Face.heading(19)).foregroundStyle(Ink.ivory)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 1)
                Text(session.answers.map { Scoring.moon($0.score) }.joined(separator: " "))
                    .font(.system(size: 30))
                VStack(spacing: 0) {
                    ForEach(Array(session.answers.enumerated()), id: \.offset) { i, a in
                        HStack {
                            Text("\(i + 1)").font(Face.engraved(13)).foregroundStyle(Ink.brass).frame(width: 18)
                            Text("\(a.question.city.name) · \(Lore.monthShort(a.question.month))")
                                .font(Face.body(15)).foregroundStyle(Ink.ivory).lineLimit(1).minimumScaleFactor(0.7)
                            Spacer()
                            Text("\(Int(a.distanceKm.rounded()).formatted()) km").font(Face.engraved(13)).foregroundStyle(Ink.mist)
                            Text(a.score.formatted()).font(Face.engraved(15)).foregroundStyle(Ink.brassLight).frame(minWidth: 52, alignment: .trailing)
                        }
                        .padding(.vertical, 9)
                        if i < session.answers.count - 1 { Rectangle().fill(Ink.brass.opacity(0.25)).frame(height: 0.5) }
                    }
                }
                .padding(.horizontal, Space.m)
                .padding(.vertical, Space.xs)
                .brassPlate(fill: Ink.nightDeep.opacity(0.78))
                if case .daily = session.mode {
                    HStack(spacing: Space.l) {
                        badge(tr("連続", "Streak"), trf("%d 日", "%d days", model.streak))
                        badge(tr("読み方の札", "Lore cards"), "\(model.progress.lore.count)/\(Lore.allCases.count)")
                        badge(tr("最高", "Best"), model.progress.bestDaily.formatted())
                    }
                    .padding(Space.m)
                    .brassPlate(fill: Ink.nightDeep.opacity(0.78))
                    Text(tr("明日の 5 問は、0 時に新しい空になる", "Tomorrow's five skies arrive at midnight"))
                        .font(Face.body(13)).foregroundStyle(Ink.ivory)
                        .padding(.horizontal, Space.m).padding(.vertical, 6)
                        .background(Capsule().fill(Ink.nightDeep.opacity(0.6)))
                }
            }
            .padding(.bottom, Space.l)
        }
        .scrollIndicators(.hidden)
    }

    private func badge(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Face.engraved(18)).foregroundStyle(Ink.brassLight)
            Text(title).font(Face.label(11)).foregroundStyle(Ink.mist)
        }
        .frame(maxWidth: .infinity)
    }
}
