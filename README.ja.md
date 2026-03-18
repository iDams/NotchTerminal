# NotchTerminal

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-blue.svg)]()
[![Version](https://img.shields.io/badge/Version-1.2.0-green.svg)]()

[**English**](README.md) | [**Español**](README.es.md) | **日本語** | [**简体中文**](README.zh-Hans.md) | [**Français**](README.fr.md)

<p align="center">
  <img src="docs/hero.png" alt="NotchTerminal" width="720" />
</p>

macOSのノッチに常駐するドロップダウンターミナル。高速で常にアクセス可能、そして作業の邪魔になりません。

---

## デモ

https://github.com/user-attachments/assets/bfe05d72-96fe-45c9-a9d1-94521a5d3023

https://github.com/user-attachments/assets/4b07bcd6-1c13-4916-bbe0-b65342c73f78

---

## 特徴

- **ノッチ統合:** ホバーで展開。すべてのMac（物理的なノッチがない機種も含む）とマルチディスプレイに対応。
- **メニューバーアクセス:** メニューバー項目から、主要機能と設定にすばやくアクセス可能。
- **セッション管理:** SwiftDataによる永続化により、起動時にウィンドウの位置、サイズ、状態を自動的に復元します。
- **ウィンドウ管理:** コンパクトモード、常に手前に表示、パス入力をサポートするドラッグ＆ドロップシステム。
- **組み込みツール:**
  - *アクティブポート:* リッスン中のTCPポートを表示し、プロセスを直接終了できます。
  - *ストレージアナライザー:* `node_modules`、`DerivedData`、キャッシュ、ログをすばやくスキャンしてクリーンアップ。

### 実験的機能
NotchTerminalには、以下の実験的な設定タブが含まれています：
- **CRTフィルター:** Metalシェーダーを使用したレトロなCRTターミナルオーバーレイ。
- **フェイクノッチグロー:** ノッチから発せられる環境光をシミュレート（サイバーパンクテーマなど）。
- **スタートアップオーブ:** アプリ起動時の視覚的インジケーター。
- **ドラッグでドッキング:** ノッチ付近にターミナルウィンドウをドラッグした際のマグネット感度を調整。

### キーボードショートカット

| ショートカット | アクション |
|----------|--------|
| `⌘C` / `⌘V` / `⌘A` | コピー / ペースト / すべて選択 |
| `⌘K` | バッファのクリア |
| `⌘F` | 検索 |
| `⌘W` | セッションを閉じる |
| `⌘+` / `⌘-` | フォントサイズの調整 |

---

## スクリーンショット

<p align="center">
  <img src="docs/screenshots/screenshot1.png" width="720" />
</p>

<p align="center">
  <img src="docs/screenshots/screenshot2.png" width="720" />
</p>

---

## 要件

- macOS 14 以降
- Xcode 16+（ソースからのビルド用）

---

## インストール

> 近日公開

---

## ソースからのビルド

```bash
git clone https://github.com/marcoastorj/NotchTerminal.git
cd NotchTerminal
```
`NotchTerminal.xcodeproj` を開き、`NotchTerminal` スキームを実行します。

**ローカルコード署名:**
リポジトリには個人の Apple `DEVELOPMENT_TEAM` は含まれていません。ローカルでビルドするには：
1. `Config/Signing.local.example.xcconfig` を `Config/Signing.local.xcconfig` にコピーします。
2. ご自身の Apple Developer チーム ID を追加します。
3. このファイルはローカルのみに保持します（`.gitignore` 内）。

---

## ドキュメントとリンク

- [ドキュメントインデックス](docs/README.md)
- [テストガイド](docs/quality/)
- [ローカリゼーション](docs/localization/LOCALIZATION.md)
- [コントリビューションガイド](CONTRIBUTING.md)
- [サードパーティの通知](NotchTerminal/Resources/THIRD_PARTY_NOTICES.md)

---

## サポート

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-donate-yellow.svg)](https://buymeacoffee.com/marcoastorj)

<p align="center">
  <img src="docs/bmc_qr.png" alt="Buy Me a Coffee QR" width="200" />
</p>

---

## ライセンス

[MIT](LICENSE) © 2026 Marco Astorga González
