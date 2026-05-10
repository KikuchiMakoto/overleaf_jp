# Overleaf CE 日本語化 Docker

Overleaf Community Edition (CE) を日本語 LaTeX (LuaLaTeX / XeLaTeX) に対応させたカスタム Docker イメージです。

- **ベース**: `sharelatex/sharelatex:6`（Overleaf CE 公式イメージ）
- **追加**: 日本語フォント（Noto CJK, IPAex）、luatexja、jlreq、haranoaji 等の日本語 TeX パッケージ群
- **高速化**: フォントキャッシュ事前構築、tmpfs マウント、必要な fmt のみ事前コンパイル

## 構成

```
.
├── Dockerfile          # 日本語化カスタムレイヤ
├── docker-compose.yml  # ランタイム設定（MongoDB / Redis / ShareLaTeX）
├── AGENTS.md           # エージェント向け Dockerfile / Compose 編集指針
├── README.md           # このファイル
└── overleaf/           # git submodule（Overleaf 公式リポジトリ）
    └── bin/shared/mongodb-init-replica-set.js
```

## 前提条件

- Docker Engine 24.0+
- Docker Compose v2
- Git

## セットアップ

### 1. リポジトリのクローン

```bash
git clone --recursive <リポジトリURL> overleaf_jp
cd overleaf_jp
```

既にクローン済みで submodule が空の場合：

```bash
git submodule update --init --recursive
```

### 2. 必須設定の編集

`docker-compose.yml` を開き、以下を自分の環境に合わせて変更してください。

#### アクセス URL（必須）
```yaml
environment:
  OVERLEAF_SITE_URL: https://tex.example.com
```

#### 管理者メールアドレス（任意）
```yaml
environment:
  # OVERLEAF_ADMIN_EMAIL: admin@example.com
```

メール確認を無効化している場合（`EMAIL_CONFIRMATION_DISABLED: "true"`）、メール設定は必須ではありません。メール送信を有効化する場合は、SMTP 設定も追加してください。

#### コンパイルタイムアウト（任意）
初回フォントキャッシュ生成時のタイムアウトを避けるため、300秒に延長しています。必要に応じて調整してください。
```yaml
environment:
  COMPILE_TIMEOUT: 300
```

### 3. 初回ビルド＆起動

```bash
docker compose up -d
```

初回ビルドでは TeXLive パッケージのダウンロード・インストールが発生するため、**数分〜10分程度**かかります。

### 4. データディレクトリの作成

初回起動前にホスト側で永続化ディレクトリを作成しておくことを推奨します。

```bash
mkdir -p ~/overleaf/sharelatex_data
mkdir -p ~/overleaf/mongo_data
mkdir -p ~/overleaf/redis_data
```

### 5. MongoDB レプリカセットの初期化

初回起動後、MongoDB のレプリカセットを初期化する必要があります。

```bash
docker compose exec mongo mongosh --eval "rs.initiate()"
```

数秒待って `rs.status()` で `PRIMARY` が選出されることを確認してください。

### 6. 管理者アカウントの作成

```bash
docker compose exec sharelatex /bin/bash -c "cd /overleaf/services/web && node modules/server-ce-scripts/scripts/create-admin --email=admin@example.com"
```

## 日本語 TeX の使用

プロジェクト内で以下のプリアンブルを使用すると、LuaLaTeX で日本語組版が行えます。

```latex
\documentclass[report]{jlreq}
\usepackage[deluxe, haranoaji]{luatexja-preset}
\begin{document}
日本語\textbf{太字}も問題なく出力できます。
\end{document}
```

**注意**: `luatexja-preset` を使う場合は、手動での `\setmainjfont` 等は**不要**です。両方指定するとフォントシリーズエラーが発生する場合があります。

## フォントキャッシュの永続化

コンテナ再起動時に LuaLaTeX / XeLaTeX のフォントキャッシュが消失しないよう、以下の named volume が定義されています。

- `texmf-var`: LuaLaTeX キャッシュ（`$TEXMFVAR/luatex-cache`）
- `fontconfig-cache`: XeLaTeX / fontconfig キャッシュ

## トラブルシューティング

### コンパイルがタイムアウトする
初回コンパイル時はフォントキャッシュの構築が発生し、時間がかかることがあります。`COMPILE_TIMEOUT` をさらに延長するか、キャッシュが正しく構築されているか確認してください。

```bash
docker compose exec sharelatex luaotfload-tool --status
docker compose exec sharelatex fc-cache -fv
```

### フォント関連のエラー
`AGENTS.md` の「よくあるフォント関連エラーと対策」セクションを参照してください。

## ライセンス

- Overleaf CE 本体: [AGPL-3.0](https://github.com/overleaf/overleaf/blob/main/LICENSE)（`overleaf/` サブモジュール）
- このリポジトリの追加ファイル（`Dockerfile`, `docker-compose.yml` 等）: 各ファイルに記載のライセンスに準じます
