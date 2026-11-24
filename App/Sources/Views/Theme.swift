import SwiftUI

/// 真鍮の天文台：深い紫紺の夜 × 真鍮の金。答えのあとは夜明けの色。
/// 色は 1 か所で決める（段階：夜 4 段・真鍮 4 段・夜明け 3 段・文字 3 段）
enum Ink {
    // 夜（地）
    static let nightDeep = Color(hex: 0x0D0A1C)
    static let night = Color(hex: 0x1A1433)
    static let nightSoft = Color(hex: 0x2A2250)
    static let nightLine = Color(hex: 0x3C3168)
    // 真鍮
    static let brass = Color(hex: 0xC9A15B)
    static let brassLight = Color(hex: 0xEED9A4)
    static let brassDeep = Color(hex: 0x8A6A32)
    static let brassShadow = Color(hex: 0x4A3818)
    // 夜明け（答えのあと・結果）
    static let dawnLow = Color(hex: 0x3B2A5C)
    static let dawnMid = Color(hex: 0xB0607A)
    static let dawnHigh = Color(hex: 0xF2B48C)
    // 星と文字（暗い地の上だけで使う。明るい地に灰色の小さい文字を置かない）
    static let starlight = Color(hex: 0xF6F0DE)
    static let ivory = Color(hex: 0xF1E9D6)
    static let mist = Color(hex: 0xBDB2D6)
    // 答えの印
    static let guess = Color(hex: 0x9FD3FF)
    static let truth = Color(hex: 0xFFCF6E)
    static let ocean = Color(hex: 0x15234A)
    static let oceanLight = Color(hex: 0x24396E)

    static let brassGradient = LinearGradient(colors: [brassLight, brass, brassDeep], startPoint: .top, endPoint: .bottom)
    static let nightGradient = LinearGradient(colors: [night, nightDeep], startPoint: .top, endPoint: .bottom)
    static let dawnGradient = LinearGradient(colors: [nightDeep, dawnLow, dawnMid, dawnHigh], startPoint: .top, endPoint: .bottom)
}

enum Radius {
    static let small: CGFloat = 8
    static let plate: CGFloat = 14
    static let sheet: CGFloat = 28
}

enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 14
    static let l: CGFloat = 20
    static let xl: CGFloat = 28
}

/// 書体：見出しは細いセリフ、数字は真鍮の刻印（セリフ・等幅の数字・字間あり）
enum Face {
    static func title(_ size: CGFloat = 30) -> Font { .system(size: size, weight: .light, design: .serif) }
    static func heading(_ size: CGFloat = 19) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func engraved(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .semibold, design: .serif).monospacedDigit() }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular) }
    static func label(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .semibold) }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}

/// 真鍮の板（主な部品の地）：縁に細い真鍮の線と、内側の影
struct BrassPlate: ViewModifier {
    var radius: CGFloat = Radius.plate
    var fill: Color = Ink.night.opacity(0.85)

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Ink.brassGradient, lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius - 3, style: .continuous)
                            .strokeBorder(Ink.brass.opacity(0.18), lineWidth: 0.5)
                            .padding(3)
                    )
                    .allowsHitTesting(false)
            )
    }
}

extension View {
    func brassPlate(radius: CGFloat = Radius.plate, fill: Color = Ink.night.opacity(0.85)) -> some View {
        modifier(BrassPlate(radius: radius, fill: fill))
    }
}

/// 真鍮のボタン（押すと 0.95 倍に沈む）
struct BrassButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .serif))
            .foregroundStyle(prominent ? Ink.nightDeep : Ink.brassLight)
            .padding(.horizontal, Space.l)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(prominent ? AnyShapeStyle(Ink.brassGradient) : AnyShapeStyle(Ink.nightSoft.opacity(0.9)))
                    .overlay(Capsule().strokeBorder(prominent ? Ink.brassLight.opacity(0.7) : Ink.brass.opacity(0.7), lineWidth: 1))
                    .shadow(color: .black.opacity(prominent ? 0.35 : 0), radius: 6, y: 3)
                    .allowsHitTesting(false)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 小さな真鍮の丸ボタン（閉じる・設定など）
struct BrassIconStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Ink.brassLight)
            .frame(width: 40, height: 40)
            .background(Circle().fill(Ink.nightSoft.opacity(0.9)).overlay(Circle().strokeBorder(Ink.brass.opacity(0.7), lineWidth: 1)).allowsHitTesting(false))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 背景の星（Canvas。決まった種で同じ並び。動かない）
struct StarDust: View {
    var count = 140
    var seed: UInt64 = 7

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: seed)
            for _ in 0..<count {
                let x = rng.unit() * size.width, y = rng.unit() * size.height
                let r = 0.4 + rng.unit() * 1.1
                let a = 0.15 + rng.unit() * 0.45
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Ink.starlight.opacity(a)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
