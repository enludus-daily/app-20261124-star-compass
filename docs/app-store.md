# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.017 |
| アプリ名 | ほしよみ天文台：夜空で場所当て / Star Compass: Sky GeoGuess |
| サポート URL | https://github.com/enludus-daily/app-20261124-star-compass/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261124-star-compass/blob/main/PRIVACY.md |
| 年齢区分の答え | すべて「なし」の想定（暴力・性的表現・ギャンブル・Web 閲覧・ユーザー生成コンテンツ・生成 AI なし）→ 4+。本人が入力 |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：懐中電灯・効果音・壁紙・単純なタイマー・占いではない。星表（338 星）・恒星時の計算・地球儀・点の決まり・読み方の札 12 枚を持つゲーム。
- 既存のアプリとの意味のある違い：Sky Guide・Star Rover は星図で遊びがなく、Stellar Guesser（Web）は星の座標当て。「夜空から場所と月を当てる毎日の問題」は App Store に見当たらない。
- 長く使える価値（4.2）：毎日の 5 問（全員同じ）・連続日数・読み方の札・最近 10 問の平均距離。読み方を覚えるほど当たる距離が縮む（テストで確かめた）。
- 他社の名前・商標・見た目を使っていないか：場所当てゲームの仕組み（地図にピン・距離で点）だけ借り、名前・絵・色はオリジナル（真鍮の天文台）。星座名は一般名。
- Apple Intelligence を使う場合、使えない端末での動き：使わない。
- 前日までのアプリとの違い（4.3 の焼き直し）：枠 016 のがまん水族館（夜の水槽・魚）・ころころ菜園（落ち物）とは仕組みも見た目も別。Theme・部品は新しく書いた。

## 収益の道筋（本人が選ぶ）

- 買い切り Pro ¥480（非消耗型 `com.enludus.daily.017.pro`。`docs/products.json`）。広告なし。
- 理由：毎日の 5 問は無料で十分遊べ、使い込む人（練習・過去の空・難しい空・大陸ごとの記録）だけが払う。勝算の表は README の「課金」（月 300 / 1,000 / 3,000 インストールで ¥2,400 / ¥8,200 / ¥24,500）。
- 審査用の画像：`docs/iap/paywall.png`（CI の screenshots の paywall から。TestFlight の前に置く）

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない（StoreKit を除く）、位置情報を使わない、解析・広告 SDK なし、保存は端末の UserDefaults だけ）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。足りない画面は本人と相談。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
