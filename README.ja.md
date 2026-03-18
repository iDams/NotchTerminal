# NotchTerminal

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-blue.svg)]()
[![Version](https://img.shields.io/badge/Version-1.2.0-green.svg)]()

[**English**](README.md) | [**Español**](README.es.md) | **日本語** | [**简体中文**](README.zh-Hans.md) | [**Français**](README.fr.md)

<p align="center">
  <img src="docs/hero.png" alt="NotchTerminal" width="720" />
</p>

**NotchTerminal** は、ノッチを中心に構築された macOS 用のターミナルアプリです。デスクトップを余分なウィンドウで埋め尽くすことなく、ターミナルへのアクセスを素早く、見やすく、作業のすぐ近くに保ちます。

---

## デモ

https://github.com/user-attachments/assets/bfe05d72-96fe-45c9-a9d1-94521a5d3023

https://github.com/user-attachments/assets/4b07bcd6-1c13-4916-bbe0-b65342c73f78

---

## 目次

- [スクリーンショット](#スクリーンショット)
- [特徴](#特徴)
- [要件](#要件)
- [インストール](#インストール)
- [ソースからのビルド](#ソースからのビルド)
- [プロジェクト構造](#プロジェクト構造)
- [設定](#設定)
- [ドキュメント](#ドキュメント)
- [貢献](#貢献)
- [クレジット](#クレジット)
- [サポート](#サポート)
- [ライセンス](#ライセンス)

---

## スクリーンショット

<p align="center">
  <img src="docs/screenshots/screenshot1.png" width="720" />
</p>

<p align="center">
  <img src="docs/screenshots/screenshot2.png" width="720" />
</p>

---

## 特徴

### ノッチオーバーレイ
- ホバーで展開
- マルチディスプレイに対応
- 物理的なノッチの有無にかかわらず Mac に対応
- 最小化されたターミナルチップを表示
- クイックアクション：`新規`、`再編成`、`一括`、`設定`

### ターミナルウィンドウ
- 開く / 閉じる / 最小化 / 最大化
- コンパクトモード
- 常に手前に表示するトグル
- ノッチの近くにドラッグするとノッチにドッキング
- ファイル / フォルダのドラッグ＆ドロップ（エスケープされたパスを挿入）

### セッション
- SwiftData による永続化
- 起動時の自動復元：位置、サイズ、ドッキング状態、コンパクトモード、常に手前に表示、最大化状態

### 開発者ユーティリティ
- **アクティブポート**: リッスン中の TCP ポートのリスト、フィルタリング、PID によるプロセスの終了
- **ストレージ分析**: `node_modules`、`DerivedData`、`Pods`、キャッシュ、ログ、ゴミ箱などのスキャン

### 視覚効果
- オーロラ背景スタイリング
- CRT フィルター
- フェイクノッチグロー

### メニューバー
- クイックアクセス：新規ターミナル、すべてのウィンドウを表示、設定、非表示、終了

### キーボードショートカット
| ショートカット | アクション |
|----------|--------|
| `⌘C` / `⌘V` / `⌘A` | コピー / ペースト / すべて選択 |
| `⌘K` | バッファのクリア |
| `⌘F` | 検索 |
| `⌘W` | セッションを閉じる |
| `⌘+` / `⌘-` | フォントサイズの調整 |

---

## 要件

- macOS 14 以降
- Xcode 16+（開発用のみ）

> デフォルトのシェルは `/bin/zsh` であり、クリーンな macOS インストールで利用可能です。

---

## インストール

> 近日公開

---

## ソースからのビルド

1. リポジトリをクローンします：
   ```bash
   git clone https://github.com/marcoastorj/NotchTerminal.git
   cd NotchTerminal
   ```

2. `NotchTerminal.xcodeproj` を開きます

3. スキーム `NotchTerminal` を選択します

4. ビルドして実行します

### コントリビューター向けのローカルコード署名

リポジトリには個人の Apple `DEVELOPMENT_TEAM` は含まれていません：

1. `Config/Signing.local.example.xcconfig` を `Config/Signing.local.xcconfig` にコピーします
2. `YOURTEAMID` をご自身の Apple Developer チーム ID に置き換えます
3. `Config/Signing.local.xcconfig` はローカルのみに保持します（`.gitignore` 内）

### デバッグワークフロー

デバッグビルドは自動的に `/Applications/NotchTerminal.app` にインストールされ、Xcode 外でテストできます。

---

## プロジェクト構造

```
NotchTerminal/
├── App/                    # アプリのライフサイクル
├── Features/
│   ├── Notch/              # オーバーレイ UI、インタラクション
│   ├── Storage/            # ストレージ分析
│   ├── Windows/            # ウィンドウマネージャー、ターミナル
│   └── Persistence/        # SwiftData モデル
├── Rendering/Metal/        # シェーダーとレンダラー
├── Settings/               # 設定画面
├── Services/               # ヘルパーとサービス
└── Assets.xcassets/        # アイコンと画像
```

---

## 設定

| セクション | 主なオプション |
|---------|--------------|
| **一般** | 言語、ハプティクス、Dock アイコン、メニューバーアイコン、ホバーの動作 |
| **ノッチ** | ディスプレイごとの有効/無効、X/Y オフセット、幅、カスタムオーロラ |
| **外観** | パディング、ホバーでチップを閉じる、ホバーでプレビュー、オーロラテーマ |
| **アプリについて** | 実験的タブを表示 |
| **実験的** | ノッチへのドラッグ感度、スタートアップオーブ、フェイクノッチグロー、CRT フィルター |

サポートされている言語：English、Español、Français、日本語、简体中文

---

## ドキュメント

- ドキュメントインデックス：[`docs/README.md`](docs/README.md)
- テスト：[`docs/quality/`](docs/quality/)
- ローカリゼーション：[`docs/localization/LOCALIZATION.md`](docs/localization/LOCALIZATION.md)

---

## 貢献

[`CONTRIBUTING.md`](CONTRIBUTING.md) を参照してください。

---

## クレジット

[`NotchTerminal/Resources/THIRD_PARTY_NOTICES.md`](NotchTerminal/Resources/THIRD_PARTY_NOTICES.md) を参照してください。

主な帰属：
- **SwiftTerm** – ターミナルエミュレーション（MIT）
- **Port-Killer** – ポートワークフローのインスピレーション（MIT）

UI で使用されているブランドマーク / ロゴは、それぞれの所有者に帰属します。

---

## サポート

開発を支援していただける場合：

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-donate-yellow.svg)](https://buymeacoffee.com/marcoastorj)

<p align="center">
  <img src="docs/bmc_qr.png" alt="Buy Me a Coffee QR" width="200" />
</p>

---

## ライセンス

[MIT](LICENSE) © 2026 Marco Astorga González

---

<p align="center">
  Made with ❤️ by Marco Astorga González
</p>
