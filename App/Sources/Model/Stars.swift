import Foundation

/// 明るい星（J2000 の赤経・赤緯・実視等級。公的な星表の値を丸めて手で入れた。ネットも外部の依存も使わない）
struct Star: Hashable, Sendable {
    let key: String
    /// 赤経（時）
    let ra: Double
    /// 赤緯（度）
    let dec: Double
    let mag: Double
}

struct Constellation: Hashable, Sendable {
    let key: String
    let ja: String
    let en: String
    let lines: [(String, String)]

    static func == (a: Constellation, b: Constellation) -> Bool { a.key == b.key }
    func hash(into h: inout Hasher) { h.combine(key) }
}

enum StarCatalog {
    /// key ra(h) dec(°) mag
    private static let table = """
    UMa.a 11.062 61.751 1.79
    UMa.b 11.031 56.382 2.37
    UMa.g 11.897 53.695 2.44
    UMa.d 12.257 57.033 3.31
    UMa.e 12.900 55.960 1.77
    UMa.z 13.399 54.925 2.23
    UMa.h 13.792 49.313 1.86
    UMa.i 8.987 48.042 3.14
    UMa.l 10.285 42.914 3.45
    UMa.m 10.372 41.499 3.05
    UMa.nu 11.308 33.094 3.48
    UMa.o 8.504 60.718 3.36
    UMa.psi 11.161 44.498 3.01
    UMa.chi 11.767 47.779 3.69
    UMa.th 9.548 51.678 3.17
    UMa.u 9.851 59.039 3.80
    UMi.a 2.530 89.264 1.98
    UMi.d 17.537 86.586 4.36
    UMi.e 16.766 82.037 4.21
    UMi.z 15.734 77.795 4.32
    UMi.b 14.845 74.155 2.08
    UMi.g 15.345 71.834 3.05
    UMi.h 16.292 75.755 4.95
    Cas.b 0.153 59.150 2.27
    Cas.a 0.675 56.537 2.24
    Cas.g 0.945 60.717 2.15
    Cas.d 1.430 60.235 2.68
    Cas.e 1.907 63.670 3.37
    Cep.a 21.310 62.585 2.45
    Cep.b 21.478 70.561 3.23
    Cep.g 23.656 77.632 3.21
    Cep.i 22.828 66.201 3.52
    Cep.z 22.181 58.201 3.35
    Cyg.a 20.690 45.280 1.25
    Cyg.g 20.370 40.257 2.23
    Cyg.b 19.512 27.960 3.08
    Cyg.e 20.770 33.970 2.48
    Cyg.d 19.750 45.131 2.87
    Cyg.z 21.216 30.227 3.21
    Cyg.h 19.938 35.083 3.89
    Lyr.a 18.616 38.784 0.03
    Lyr.e 18.739 39.670 4.67
    Lyr.z 18.746 37.605 4.34
    Lyr.b 18.835 33.363 3.52
    Lyr.g 18.982 32.690 3.25
    Lyr.d 18.908 36.899 4.30
    Aql.a 19.846 8.868 0.77
    Aql.g 19.771 10.613 2.72
    Aql.b 19.922 6.407 3.71
    Aql.z 19.090 13.863 2.99
    Aql.d 19.425 3.115 3.36
    Aql.l 19.104 -4.882 3.43
    Aql.th 20.188 -0.821 3.24
    Her.pi 17.251 36.809 3.16
    Her.h 16.715 38.922 3.48
    Her.z 16.688 31.603 2.81
    Her.e 17.005 30.926 3.92
    Her.b 16.504 21.490 2.77
    Her.a 17.244 14.390 3.06
    Her.d 17.251 24.839 3.14
    Her.m 17.774 27.721 3.42
    Boo.a 14.261 19.182 -0.05
    Boo.e 14.750 27.074 2.37
    Boo.g 14.535 38.308 3.03
    Boo.b 15.032 40.391 3.49
    Boo.d 15.258 33.315 3.47
    Boo.h 13.911 18.398 2.68
    Boo.r 14.531 30.371 3.58
    CrB.a 15.578 26.715 2.23
    CrB.b 15.464 29.106 3.68
    CrB.th 15.549 31.359 4.14
    CrB.g 15.712 26.296 3.84
    CrB.d 15.827 26.068 4.63
    CrB.e 15.960 26.878 4.15
    Leo.a 10.140 11.967 1.35
    Leo.h 10.122 16.763 3.49
    Leo.g 10.333 19.842 2.01
    Leo.z 10.278 23.417 3.44
    Leo.m 9.880 26.007 3.88
    Leo.e 9.764 23.774 2.98
    Leo.b 11.818 14.572 2.14
    Leo.d 11.235 20.524 2.56
    Leo.th 11.237 15.430 3.33
    Gem.a 7.577 31.889 1.58
    Gem.b 7.755 28.026 1.14
    Gem.g 6.629 16.399 1.92
    Gem.e 6.732 25.131 2.98
    Gem.m 6.383 22.514 2.87
    Gem.d 7.335 21.982 3.53
    Gem.z 7.068 20.570 3.79
    Tau.a 4.599 16.509 0.85
    Tau.b 5.438 28.608 1.65
    Tau.z 5.627 21.143 3.00
    Tau.th 4.478 15.871 3.40
    Tau.g 4.330 15.628 3.65
    Tau.d 4.382 17.543 3.76
    Tau.e 4.477 19.181 3.53
    Tau.l 4.011 12.490 3.41
    Tau.eta 3.791 24.105 2.87
    Tau.m27 3.819 24.053 3.62
    Tau.m17 3.748 24.113 3.70
    Tau.m20 3.763 24.368 3.87
    Tau.m23 3.772 23.948 4.18
    Tau.m19 3.754 24.467 4.30
    Ori.a 5.919 7.407 0.50
    Ori.b 5.242 -8.202 0.13
    Ori.g 5.419 6.350 1.64
    Ori.d 5.533 -0.299 2.23
    Ori.e 5.604 -1.202 1.69
    Ori.z 5.679 -1.943 1.77
    Ori.k 5.796 -9.670 2.06
    Ori.l 5.585 9.934 3.39
    Ori.i 5.590 -5.910 2.77
    CMa.a 6.752 -16.716 -1.46
    CMa.b 6.378 -17.956 1.98
    CMa.e 6.977 -28.972 1.50
    CMa.d 7.140 -26.393 1.84
    CMa.h 7.402 -29.303 2.45
    CMa.g 7.062 -15.633 4.11
    CMa.i 6.936 -17.054 4.37
    CMa.z 6.338 -30.063 3.02
    CMa.o2 7.050 -23.833 3.02
    CMi.a 7.655 5.225 0.34
    CMi.b 7.453 8.289 2.89
    Aur.a 5.278 45.998 0.08
    Aur.b 5.992 44.948 1.90
    Aur.th 5.995 37.213 2.62
    Aur.i 4.950 33.166 2.69
    Aur.e 5.032 43.823 2.99
    Aur.h 5.109 41.234 3.17
    Per.a 3.405 49.861 1.79
    Per.b 3.136 40.957 2.12
    Per.z 3.902 31.884 2.85
    Per.e 3.964 40.010 2.89
    Per.d 3.715 47.788 3.01
    Per.g 3.080 53.506 2.93
    Per.h 2.845 55.896 3.76
    And.a 0.140 29.091 2.06
    And.d 0.656 30.861 3.27
    And.b 1.162 35.621 2.05
    And.g 2.065 42.330 2.10
    And.m 0.946 38.499 3.87
    Peg.a 23.079 15.205 2.48
    Peg.b 23.063 28.083 2.42
    Peg.g 0.220 15.184 2.83
    Peg.e 21.736 9.875 2.38
    Peg.z 22.691 10.831 3.40
    Peg.th 22.170 6.198 3.53
    Peg.h 22.717 30.221 2.94
    Dra.g 17.943 51.489 2.23
    Dra.b 17.507 52.301 2.79
    Dra.xi 17.892 56.873 3.75
    Dra.nu 17.536 55.184 4.88
    Dra.d 19.209 67.662 3.07
    Dra.e 19.803 70.268 3.83
    Dra.z 17.146 65.715 3.17
    Dra.h 16.400 61.514 2.73
    Dra.th 16.032 58.565 4.01
    Dra.i 15.415 58.966 3.29
    Dra.a 14.073 64.376 3.65
    Dra.k 12.558 69.788 3.87
    Dra.l 11.523 69.331 3.82
    Vir.a 13.420 -11.161 0.98
    Vir.g 12.694 -1.449 2.74
    Vir.e 13.036 10.959 2.83
    Vir.d 12.927 3.397 3.38
    Vir.b 11.845 1.765 3.61
    Vir.z 13.578 -0.596 3.37
    Vir.h 12.332 -0.667 3.89
    Sco.a 16.490 -26.432 1.06
    Sco.d 16.006 -22.622 2.29
    Sco.b 16.091 -19.806 2.56
    Sco.pi 15.981 -26.114 2.89
    Sco.s 16.353 -25.593 2.89
    Sco.t 16.598 -28.216 2.82
    Sco.e 16.836 -34.293 2.29
    Sco.m 16.864 -38.047 3.00
    Sco.z 16.910 -42.362 3.62
    Sco.h 17.203 -43.239 3.33
    Sco.th 17.622 -42.998 1.86
    Sco.i 17.793 -40.127 2.99
    Sco.k 17.708 -39.030 2.39
    Sco.l 17.560 -37.104 1.62
    Sco.u 17.513 -37.296 2.69
    Sgr.e 18.403 -34.385 1.85
    Sgr.s 18.921 -26.297 2.05
    Sgr.z 19.043 -29.880 2.60
    Sgr.d 18.350 -29.828 2.70
    Sgr.l 18.466 -25.422 2.82
    Sgr.g 18.097 -30.424 2.99
    Sgr.phi 18.761 -26.991 3.17
    Sgr.t 19.116 -27.671 3.32
    Sgr.h 18.294 -36.762 3.11
    Cen.a 14.660 -60.835 -0.27
    Cen.b 14.064 -60.373 0.61
    Cen.th 14.111 -36.370 2.06
    Cen.e 13.665 -53.466 2.30
    Cen.h 14.592 -42.158 2.33
    Cen.g 12.692 -48.960 2.17
    Cen.d 12.139 -50.722 2.58
    Cen.z 13.926 -47.288 2.55
    Cen.i 13.343 -36.712 2.75
    Cru.a 12.443 -63.099 0.77
    Cru.b 12.795 -59.689 1.25
    Cru.g 12.519 -57.113 1.63
    Cru.d 12.252 -58.749 2.79
    Cru.e 12.356 -60.401 3.59
    Car.a 6.399 -52.696 -0.74
    Car.b 9.220 -69.717 1.69
    Car.e 8.375 -59.510 1.86
    Car.i 9.285 -59.275 2.21
    Car.th 10.716 -64.394 2.76
    Car.u 9.785 -65.072 2.97
    Car.w 10.229 -70.038 3.29
    Vel.g 8.159 -47.337 1.83
    Vel.d 8.745 -54.709 1.95
    Vel.l 9.133 -43.433 2.21
    Vel.k 9.368 -55.011 2.47
    Vel.m 10.779 -49.420 2.69
    Vel.phi 9.948 -54.568 3.52
    Crv.g 12.263 -17.542 2.59
    Crv.b 12.573 -23.397 2.65
    Crv.d 12.498 -16.515 2.95
    Crv.e 12.169 -22.620 3.00
    Crv.a 12.140 -24.729 4.02
    Gru.a 22.137 -46.961 1.74
    Gru.b 22.711 -46.885 2.10
    Gru.g 21.899 -37.365 3.01
    Gru.e 22.809 -51.317 3.49
    Gru.d 22.488 -43.496 3.97
    PsA.a 22.961 -29.622 1.16
    Eri.a 1.629 -57.237 0.46
    Eri.b 5.131 -5.086 2.79
    Eri.g 3.967 -13.509 2.95
    Eri.th 2.971 -40.305 2.88
    Eri.d 3.721 -9.763 3.54
    Eri.e 3.549 -9.458 3.73
    Hya.a 9.460 -8.659 1.98
    Hya.g 13.315 -23.172 2.99
    Hya.z 8.923 5.946 3.11
    Hya.e 8.779 6.419 3.38
    Hya.nu 10.827 -16.194 3.11
    Hya.pi 14.106 -26.683 3.25
    Oph.a 17.582 12.560 2.08
    Oph.h 17.173 -15.725 2.43
    Oph.z 16.619 -10.567 2.54
    Oph.d 16.239 -3.694 2.74
    Oph.b 17.725 4.567 2.76
    Oph.k 16.961 9.375 3.20
    Oph.e 16.305 -4.692 3.24
    Oph.nu 17.984 -9.774 3.32
    Del.b 20.626 14.595 3.63
    Del.a 20.661 15.912 3.77
    Del.g 20.777 16.124 4.27
    Del.d 20.724 15.075 4.43
    Del.e 20.554 11.303 4.03
    Lep.a 5.546 -17.822 2.58
    Lep.b 5.471 -20.759 2.84
    Lep.e 5.091 -22.371 3.19
    Lep.m 4.966 -16.206 3.29
    Lep.z 5.783 -14.822 3.55
    Lep.g 5.741 -22.448 3.59
    Lep.d 5.855 -20.879 3.81
    Col.a 5.661 -34.074 2.65
    Col.b 5.849 -35.768 3.12
    Pup.z 8.060 -40.003 2.25
    Pup.pi 7.286 -37.097 2.70
    Pup.r 8.126 -24.304 2.81
    Pup.t 6.832 -50.615 2.93
    Pup.nu 6.629 -43.196 3.17
    Ari.a 2.120 23.462 2.01
    Ari.b 1.911 20.808 2.64
    Ari.g 1.892 19.294 3.88
    Tri.a 1.885 29.579 3.41
    Tri.b 2.159 34.987 3.00
    Tri.g 2.289 33.847 4.01
    Cet.b 0.726 -17.987 2.04
    Cet.a 3.038 4.090 2.54
    Cet.h 1.143 -10.182 3.45
    Cet.t 1.734 -15.938 3.50
    Cet.i 0.324 -8.824 3.56
    Cet.th 1.400 -8.183 3.60
    Cet.z 1.858 -10.335 3.73
    Cet.g 2.722 3.236 3.47
    Cet.d 2.658 0.329 4.07
    Cet.o 2.322 -2.978 3.04
    TrA.a 16.811 -69.028 1.91
    TrA.b 15.919 -63.430 2.85
    TrA.g 15.315 -68.679 2.89
    Pav.a 20.427 -56.735 1.94
    Ara.b 17.422 -55.530 2.85
    Ara.a 17.531 -49.876 2.95
    Lup.a 14.699 -47.388 2.30
    Lup.b 14.976 -43.134 2.68
    Lup.g 15.586 -41.167 2.78
    Lup.d 15.356 -40.648 3.22
    Hyi.b 0.429 -77.254 2.80
    Hyi.a 1.980 -61.570 2.86
    Tuc.a 22.308 -60.260 2.86
    Phe.a 0.438 -42.306 2.40
    Oct.s 21.147 -88.956 5.42
    Oct.nu 21.691 -77.390 3.76
    Mus.a 12.620 -69.136 2.69
    Lib.b 15.283 -9.383 2.61
    Lib.a 14.848 -16.042 2.75
    Lib.s 15.068 -25.282 3.29
    Ser.a 15.738 6.426 2.63
    Cap.d 21.784 -16.127 2.85
    Cap.b 20.350 -14.781 3.05
    Cap.a 20.300 -12.545 3.57
    Cap.g 21.668 -16.662 3.67
    Cap.z 21.444 -22.411 3.74
    Cap.w 20.864 -26.919 4.11
    Aqr.b 21.526 -5.571 2.90
    Aqr.a 22.096 -0.320 2.95
    Aqr.d 22.911 -15.821 3.27
    Aqr.z 22.481 -0.020 3.65
    Aqr.l 22.877 -7.580 3.73
    Aqr.e 20.794 -9.496 3.77
    Psc.h 1.525 15.346 3.62
    Psc.g 23.286 3.282 3.69
    Cnc.b 8.275 9.186 3.52
    Cnc.d 8.745 18.154 3.94
    Cnc.i 8.778 28.760 4.02
    Cnc.a 8.975 11.858 4.25
    Cnc.g 8.721 21.469 4.66
    CVn.a 12.934 38.318 2.88
    Lyn.a 9.351 34.392 3.13
    Cam.b 5.057 60.442 4.03
    Sge.g 19.979 19.492 3.47
    Lac.a 22.522 50.282 3.77
    Mon.b 6.480 -7.033 3.76
    Dor.a 4.567 -55.045 3.27
    Ret.a 4.241 -62.474 3.35
    Pic.b 5.788 -51.067 3.85
    Ind.a 20.626 -47.291 3.11
    Crt.d 11.322 -14.779 3.56
    CrA.a 19.158 -37.905 4.10
    """

    static let stars: [Star] = table.split(separator: "\n").compactMap { line in
        let p = line.split(separator: " ")
        guard p.count == 4, let ra = Double(p[1]), let dec = Double(p[2]), let mag = Double(p[3]) else { return nil }
        return Star(key: String(p[0]), ra: ra, dec: dec, mag: mag)
    }

    static let byKey: [String: Star] = Dictionary(uniqueKeysWithValues: stars.map { ($0.key, $0) })

    private static func c(_ key: String, _ ja: String, _ en: String, _ lines: String) -> Constellation {
        let pairs: [(String, String)] = lines.split(separator: " ").compactMap { seg in
            let ab = seg.split(separator: "-")
            guard ab.count == 2 else { return nil }
            func full(_ s: Substring) -> String { s.contains(".") ? String(s) : key + "." + s }
            return (full(ab[0]), full(ab[1]))
        }
        return Constellation(key: key, ja: ja, en: en, lines: pairs)
    }

    /// 星座の線（点と点をつなぐ。ほかの星座の星は「星座.記号」で書く）
    static let constellations: [Constellation] = [
        c("UMa", "おおぐま座（北斗七星）", "Big Dipper", "a-b b-g g-d d-a d-e e-z z-h"),
        c("UMi", "こぐま座", "Little Dipper", "a-d d-e e-z z-b b-g g-h h-z"),
        c("Cas", "カシオペヤ座", "Cassiopeia", "b-a a-g g-d d-e"),
        c("Cep", "ケフェウス座", "Cepheus", "a-b b-g g-i i-z z-a i-a"),
        c("Cyg", "はくちょう座", "Cygnus", "a-g g-h h-b d-g g-e e-z"),
        c("Lyr", "こと座", "Lyra", "a-e a-z z-b b-g g-d d-z"),
        c("Aql", "わし座", "Aquila", "z-g g-a a-b a-d d-l b-th"),
        c("Her", "ヘルクレス座", "Hercules", "pi-h h-z z-e e-pi z-b e-d d-a pi-m"),
        c("Boo", "うしかい座", "Boötes", "a-e e-d d-b b-g g-r r-a a-h"),
        c("CrB", "かんむり座", "Corona Borealis", "th-b b-a a-g g-d d-e"),
        c("Leo", "しし座", "Leo", "a-h h-g g-z z-m m-e g-d d-b b-th th-a d-th"),
        c("Gem", "ふたご座", "Gemini", "a-b a-e e-m b-d d-z z-g"),
        c("Tau", "おうし座", "Taurus", "l-g g-th th-a a-z g-d d-e e-b"),
        c("Ori", "オリオン座", "Orion", "a-g g-d d-e e-z z-k k-b b-d a-z a-l l-g"),
        c("CMa", "おおいぬ座", "Canis Major", "b-a a-i i-g a-o2 o2-d d-e e-z d-h"),
        c("CMi", "こいぬ座", "Canis Minor", "a-b"),
        c("Aur", "ぎょしゃ座", "Auriga", "a-b b-th th-Tau.b Tau.b-i i-a a-e e-h"),
        c("Per", "ペルセウス座", "Perseus", "h-g g-a a-d d-e e-z a-b"),
        c("And", "アンドロメダ座", "Andromeda", "a-d d-b b-g b-m"),
        c("Peg", "ペガスス座（秋の四辺形）", "Great Square of Pegasus", "And.a-b b-a a-g g-And.a a-z z-th th-e b-h"),
        c("Dra", "りゅう座", "Draco", "b-g g-xi xi-nu nu-b xi-d d-e d-z z-h h-th th-i i-a a-k k-l"),
        c("Vir", "おとめ座", "Virgo", "b-h h-g g-d d-e g-a d-z z-a"),
        c("Sco", "さそり座", "Scorpius", "b-d d-pi d-s s-a a-t t-e e-m m-z z-h h-th th-i i-k k-l l-u"),
        c("Sgr", "いて座（南斗六星）", "Sagittarius (Teapot)", "g-d d-e e-g d-l l-phi phi-d phi-s s-t t-z z-phi z-e e-h"),
        c("Cen", "ケンタウルス座", "Centaurus", "a-b b-e e-g g-d e-z z-h h-th th-i"),
        c("Cru", "みなみじゅうじ座（南十字）", "Southern Cross", "a-g b-d"),
        c("Car", "りゅうこつ座", "Carina", "a-e e-i i-u u-th th-w w-b"),
        c("Vel", "ほ座", "Vela", "g-d d-k k-phi phi-m m-l l-g"),
        c("Crv", "からす座", "Corvus", "a-e e-g g-d d-b b-e"),
        c("Gru", "つる座", "Grus", "g-d d-a d-b b-e"),
        c("Hya", "うみへび座", "Hydra", "e-z z-a a-nu nu-g g-pi"),
        c("Oph", "へびつかい座", "Ophiuchus", "a-k k-d d-e e-z z-h h-nu a-b b-h"),
        c("Del", "いるか座", "Delphinus", "e-b b-a a-g g-d d-b"),
        c("Lep", "うさぎ座", "Lepus", "m-a a-z a-b b-e b-g g-d"),
        c("Ari", "おひつじ座", "Aries", "a-b b-g"),
        c("Tri", "さんかく座", "Triangulum", "a-b b-g g-a"),
        c("Cet", "くじら座", "Cetus", "b-i i-th b-t t-z z-th th-h z-o o-d d-g g-a"),
        c("TrA", "みなみのさんかく座", "Southern Triangle", "a-b b-g g-a"),
        c("Lup", "おおかみ座", "Lupus", "a-b b-d d-g"),
        c("Lib", "てんびん座", "Libra", "a-b a-s"),
        c("Cap", "やぎ座", "Capricornus", "a-b b-w w-z z-d d-g g-a"),
        c("Aqr", "みずがめ座", "Aquarius", "e-b b-a a-z a-l l-d"),
        c("Cnc", "かに座", "Cancer", "b-d d-g g-i d-a"),
        c("Hyi", "みずへび座", "Hydrus", "a-b"),
        c("Col", "はと座", "Columba", "a-b"),
        c("Ara", "さいだん座", "Ara", "a-b"),
    ]

    /// 線の両端が表にある星座だけ（テストで確かめる）
    static func lineStars(_ c: Constellation) -> [(Star, Star)] {
        c.lines.compactMap { a, b in
            guard let s = byKey[a], let t = byKey[b] else { return nil }
            return (s, t)
        }
    }

    /// 星座の中心（線の星の平均の向き）。名札を置く所
    static func center(_ c: Constellation) -> (ra: Double, dec: Double) {
        let keys = Set(c.lines.flatMap { [$0.0, $0.1] })
        let ss = keys.compactMap { byKey[$0] }
        var x = 0.0, y = 0.0, z = 0.0
        for s in ss {
            let ra = s.ra * 15 * .pi / 180, dec = s.dec * .pi / 180
            x += cos(dec) * cos(ra); y += cos(dec) * sin(ra); z += sin(dec)
        }
        let ra = atan2(y, x) * 180 / .pi / 15
        let dec = atan2(z, sqrt(x * x + y * y)) * 180 / .pi
        return ((ra + 24).truncatingRemainder(dividingBy: 24), dec)
    }

    /// 天の川の中心線（銀河の赤道）を赤道座標で。銀経 0〜360 を step ごとに
    static func milkyWay(step: Double = 6) -> [(ra: Double, dec: Double)] {
        // 銀河座標 → 赤道座標（J2000）。北銀極 RA 192.859°, Dec 27.128°、銀経 0 の向き 122.932°
        let raP = 192.859 * .pi / 180, decP = 27.128 * .pi / 180, lNCP = 122.932 * .pi / 180
        return stride(from: 0.0, through: 360.0, by: step).map { lDeg in
            let l = lDeg * .pi / 180, b = 0.0
            let sinDec = sin(decP) * sin(b) + cos(decP) * cos(b) * cos(lNCP - l)
            let dec = asin(sinDec)
            let y = cos(b) * sin(lNCP - l)
            let x = cos(decP) * sin(b) - sin(decP) * cos(b) * cos(lNCP - l)
            var ra = raP + atan2(y, x)
            ra = ra.truncatingRemainder(dividingBy: 2 * .pi)
            if ra < 0 { ra += 2 * .pi }
            return (ra * 180 / .pi / 15, dec * 180 / .pi)
        }
    }
}
