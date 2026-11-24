import Foundation

enum Continent: String, CaseIterable, Codable, Sendable {
    case asia, europe, northAmerica, southAmerica, africa, oceania, polar

    var title: String {
        switch self {
        case .asia: tr("アジア", "Asia")
        case .europe: tr("ヨーロッパ", "Europe")
        case .northAmerica: tr("北アメリカ", "North America")
        case .southAmerica: tr("南アメリカ", "South America")
        case .africa: tr("アフリカ", "Africa")
        case .oceania: tr("オセアニア", "Oceania")
        case .polar: tr("極地", "Polar")
        }
    }
}

struct City: Hashable, Sendable, Identifiable {
    let id: String
    let lat: Double
    let lon: Double
    let ja: String
    let en: String
    let continent: Continent
    /// Pro の自由練習で足す都市（毎日の問題には全員に出る）
    let extra: Bool

    var name: String { Lang.isJapanese ? ja : en }
}

enum CityBook {
    private static func c(_ id: String, _ lat: Double, _ lon: Double, _ ja: String, _ en: String, _ k: Continent, extra: Bool = false) -> City {
        City(id: id, lat: lat, lon: lon, ja: ja, en: en, continent: k, extra: extra)
    }

    static let all: [City] = [
        c("tokyo", 35.68, 139.69, "東京", "Tokyo", .asia),
        c("sapporo", 43.06, 141.35, "札幌", "Sapporo", .asia),
        c("naha", 26.21, 127.68, "那覇", "Naha", .asia),
        c("seoul", 37.57, 126.98, "ソウル", "Seoul", .asia),
        c("beijing", 39.90, 116.40, "北京", "Beijing", .asia),
        c("shanghai", 31.23, 121.47, "上海", "Shanghai", .asia),
        c("hongkong", 22.32, 114.17, "香港", "Hong Kong", .asia),
        c("taipei", 25.03, 121.57, "台北", "Taipei", .asia),
        c("manila", 14.60, 120.98, "マニラ", "Manila", .asia),
        c("bangkok", 13.76, 100.50, "バンコク", "Bangkok", .asia),
        c("singapore", 1.35, 103.82, "シンガポール", "Singapore", .asia),
        c("jakarta", -6.21, 106.85, "ジャカルタ", "Jakarta", .asia),
        c("delhi", 28.61, 77.21, "デリー", "Delhi", .asia),
        c("mumbai", 19.08, 72.88, "ムンバイ", "Mumbai", .asia),
        c("dubai", 25.20, 55.27, "ドバイ", "Dubai", .asia),
        c("tehran", 35.69, 51.39, "テヘラン", "Tehran", .asia),
        c("ulaanbaatar", 47.89, 106.91, "ウランバートル", "Ulaanbaatar", .asia),
        c("hanoi", 21.03, 105.85, "ハノイ", "Hanoi", .asia),
        c("london", 51.51, -0.13, "ロンドン", "London", .europe),
        c("paris", 48.86, 2.35, "パリ", "Paris", .europe),
        c("berlin", 52.52, 13.40, "ベルリン", "Berlin", .europe),
        c("rome", 41.90, 12.50, "ローマ", "Rome", .europe),
        c("madrid", 40.42, -3.70, "マドリード", "Madrid", .europe),
        c("moscow", 55.76, 37.62, "モスクワ", "Moscow", .europe),
        c("stockholm", 59.33, 18.07, "ストックホルム", "Stockholm", .europe),
        c("istanbul", 41.01, 28.98, "イスタンブール", "Istanbul", .europe),
        c("athens", 37.98, 23.73, "アテネ", "Athens", .europe),
        c("reykjavik", 64.15, -21.94, "レイキャビク", "Reykjavík", .europe),
        c("lisbon", 38.72, -9.14, "リスボン", "Lisbon", .europe),
        c("helsinki", 60.17, 24.94, "ヘルシンキ", "Helsinki", .europe),
        c("newyork", 40.71, -74.01, "ニューヨーク", "New York", .northAmerica),
        c("losangeles", 34.05, -118.24, "ロサンゼルス", "Los Angeles", .northAmerica),
        c("chicago", 41.88, -87.63, "シカゴ", "Chicago", .northAmerica),
        c("vancouver", 49.28, -123.12, "バンクーバー", "Vancouver", .northAmerica),
        c("mexicocity", 19.43, -99.13, "メキシコシティ", "Mexico City", .northAmerica),
        c("honolulu", 21.31, -157.86, "ホノルル", "Honolulu", .northAmerica),
        c("anchorage", 61.22, -149.90, "アンカレッジ", "Anchorage", .northAmerica),
        c("miami", 25.76, -80.19, "マイアミ", "Miami", .northAmerica),
        c("toronto", 43.65, -79.38, "トロント", "Toronto", .northAmerica),
        c("denver", 39.74, -104.99, "デンバー", "Denver", .northAmerica),
        c("sydney", -33.87, 151.21, "シドニー", "Sydney", .oceania),
        c("melbourne", -37.81, 144.96, "メルボルン", "Melbourne", .oceania),
        c("perth", -31.95, 115.86, "パース", "Perth", .oceania),
        c("auckland", -36.85, 174.76, "オークランド", "Auckland", .oceania),
        c("darwin", -12.46, 130.84, "ダーウィン", "Darwin", .oceania),
        c("christchurch", -43.53, 172.64, "クライストチャーチ", "Christchurch", .oceania),
        c("cairo", 30.04, 31.24, "カイロ", "Cairo", .africa),
        c("capetown", -33.92, 18.42, "ケープタウン", "Cape Town", .africa),
        c("buenosaires", -34.60, -58.38, "ブエノスアイレス", "Buenos Aires", .southAmerica),
        c("lima", -12.05, -77.04, "リマ", "Lima", .southAmerica),
        // Pro の自由練習で足す都市（南米・アフリカ・極地）
        c("saopaulo", -23.55, -46.63, "サンパウロ", "São Paulo", .southAmerica, extra: true),
        c("rio", -22.91, -43.17, "リオデジャネイロ", "Rio de Janeiro", .southAmerica, extra: true),
        c("santiago", -33.45, -70.67, "サンティアゴ", "Santiago", .southAmerica, extra: true),
        c("bogota", 4.71, -74.07, "ボゴタ", "Bogotá", .southAmerica, extra: true),
        c("quito", -0.18, -78.47, "キト", "Quito", .southAmerica, extra: true),
        c("ushuaia", -54.80, -68.30, "ウシュアイア", "Ushuaia", .southAmerica, extra: true),
        c("nairobi", -1.29, 36.82, "ナイロビ", "Nairobi", .africa, extra: true),
        c("lagos", 6.52, 3.38, "ラゴス", "Lagos", .africa, extra: true),
        c("marrakech", 31.63, -7.99, "マラケシュ", "Marrakesh", .africa, extra: true),
        c("johannesburg", -26.20, 28.05, "ヨハネスブルグ", "Johannesburg", .africa, extra: true),
        c("antananarivo", -18.88, 47.51, "アンタナナリボ", "Antananarivo", .africa, extra: true),
        c("addisababa", 9.03, 38.74, "アディスアベバ", "Addis Ababa", .africa, extra: true),
        c("longyearbyen", 78.22, 15.65, "ロングイェールビーン", "Longyearbyen", .polar, extra: true),
        c("tromso", 69.65, 18.96, "トロムソ", "Tromsø", .polar, extra: true),
        c("nuuk", 64.18, -51.72, "ヌーク", "Nuuk", .polar, extra: true),
        c("mcmurdo", -77.85, 166.67, "マクマード基地", "McMurdo Station", .polar, extra: true),
    ]

    static let byID: [String: City] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static let base: [City] = all.filter { !$0.extra }
}
