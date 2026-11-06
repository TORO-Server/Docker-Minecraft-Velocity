# Docker-Minecraft-Velocity

Velocity (Minecraft プロキシサーバー) の最小限の Docker イメージを自動ビルドおよび配信するプロジェクト。

## 特徴
- **自動ビルド & パブリッシュ**: GitHub Actions を利用し、毎日 Velocity の新規ビルドを自動的に検出して GHCR (GitHub Container Registry) にパブリッシュする。
- **軽量・安全なイメージ**: ベースイメージは Google の `distroless/java-base` (シェルすら含まれない)。Java の実行環境は `jlink` で作り (モジュールは Temurin の JRE と同じ)、既定は非 root (65532) で動く。
- **Java バージョンの自動追従**: Velocity の jar ファイルを解析し、必要な Java バージョン (Java 21 等) を自動的に検出して Docker ベースイメージを切り替える。
- **マルチプラットフォーム対応**: `linux/amd64` および `linux/arm64` アーキテクチャに対応。

## 提供されるタグ
パブリッシュされるイメージには、以下のルールに従ってタグが割り当てられる：
- **バージョンタグ**: `${version}` (例: `3.5.1`)
- **全体最新タグ (Velocity の最新ビルド時のみ)**: `latest`

> [!NOTE]
> 現在のスクリプトの設定により、Velocity `3.0.0` 以上のバージョンが自動ビルドおよびパブリッシュの対象となっている。

## 使い方

本イメージには Java の実行環境と `velocity.jar` のみが含まれている。Velocity サーバーを実行するには、設定ファイルやログを保存するディレクトリを作業ディレクトリ `/app` にマウントする必要がある。

### 1. ディレクトリの準備
ホスト側にデータを保持するディレクトリ（例: `./data`）を作成する。

```bash
mkdir data
```

### 2. コンテナの起動
作成したディレクトリをコンテナの `/app` にマウントして起動する。初回起動時に `velocity.toml` などの設定ファイルがマウントされたディレクトリ配下に自動生成される。

```bash
docker run -d \
  --user "$(id -u):$(id -g)" \
  -p 25577:25577 \
  -v $(pwd)/data:/app \
  --name velocity-proxy \
  ghcr.io/<owner>/docker-minecraft-velocity:latest
```

## 構成スクリプト

### [updateVelocity.py](/updateVelocity.py)
GitHub Actions ワークフローでビルドプロセスを制御するための多機能 Python スクリプト。

#### コマンドラインの使用方法
- **ビルド対象マトリックスの取得**
  まだ `ghcr.io` にパブリッシュされていない新しいビルド情報を PaperMC API (Fill v3) から取得し、GitHub Actions のマトリックス形式 (JSON) で出力する。
  ```bash
  python updateVelocity.py get-matrix
  ```
- **jar ファイルのダウンロードと SHA256 検証**
  指定した URL から jar ファイルをダウンロードし、チェックサムを検証する。
  ```bash
  python updateVelocity.py download <保存パス> <ダウンロードURL> <期待されるSHA256>
  ```
- **Java バージョンの検出**
  jar ファイルに含まれるクラスファイルのバージョンヘッダから、必要な Java メジャーバージョンを自動的に判定して出力する。
  ```bash
  python updateVelocity.py get-jar-version <jarファイルのパス>
  ```
- **Java バージョンの整合性検証**
  Dockerfile が提供する Java バージョンが、jar ファイルが要求する Java バージョン以上であることを確認する。
  ```bash
  python updateVelocity.py verify-java <jarファイルのパス> <Dockerfileのパス>
  ```
