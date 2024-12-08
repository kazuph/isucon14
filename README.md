# ISU RIDE Application

## システム構成

### 依存サービス
- MySQL: メインデータベース
- nginx: Webサーバー/リバースプロキシ
- payment_mock: 決済モックサービス (port: 12345)

### アプリケーションアーキテクチャ
- 言語: Go
- フレームワーク: chi router

### システム構成図

```mermaid
graph TB
    Client[クライアント]
    Nginx[Nginx]
    App[Go Application]
    DB[(MySQL)]
    Payment[Payment Mock Service]

    Client --> Nginx
    Nginx --> App
    App --> DB
    App --> Payment

    subgraph "Application Layer"
        App
    end

    subgraph "Infrastructure Layer"
        DB
        Payment
    end
```

## データ構造

### ER図
```mermaid
erDiagram
    users ||--o{ rides : requests
    users ||--o{ payment_tokens : has
    users ||--o{ coupons : owns
    owners ||--o{ chairs : owns
    chairs ||--o{ chair_locations : updates
    chairs ||--o{ rides : serves
    rides ||--o{ ride_statuses : has

    users {
        string id PK
        string username
        string firstname
        string lastname
        string date_of_birth
        string access_token
        string invitation_code
        datetime created_at
        datetime updated_at
    }

    chairs {
        string id PK
        string owner_id FK
        string name
        string model
        boolean is_active
        string access_token
        datetime created_at
        datetime updated_at
    }

    rides {
        string id PK
        string user_id FK
        string chair_id FK
        int pickup_latitude
        int pickup_longitude
        int destination_latitude
        int destination_longitude
        int evaluation
        datetime created_at
        datetime updated_at
    }

    ride_statuses {
        string id PK
        string ride_id FK
        string status
        datetime created_at
        datetime app_sent_at
        datetime chair_sent_at
    }
```

### 主要エンティティ
1. User
   - ユーザー情報
   - 認証情報
   - 支払い方法

2. Chair
   - 椅子情報
   - 位置情報
   - 稼働状態

3. Ride
   - 配車情報
   - 料金
   - 評価

4. Owner
   - オーナー情報
   - 椅子管理

## アプリケーションフロー

### 配車リクエストフロー
```mermaid
sequenceDiagram
    actor User
    participant App
    participant Chair
    participant DB

    User->>App: 配車リクエスト
    App->>DB: 利用可能な椅子を検索
    App->>DB: 配車情報を保存

    loop Matching
        App->>Chair: 通知確認
        Chair->>App: ステータス更新
        App->>User: 状態通知
    end

    Chair->>App: 到着通知
    App->>User: 完了通知
    User->>App: 評価送信
```

### 決済フロー
```mermaid
sequenceDiagram
    actor User
    participant App
    participant PaymentService
    participant DB

    User->>App: 支払い方法登録
    App->>PaymentService: トークン検証
    PaymentService-->>App: 検証結果

    App->>DB: 支払い情報保存
    App-->>User: 登録完了
```

## API エンドポイント

### ユーザー向けAPI (/api/app/*)
- POST /users - ユーザー登録
- POST /payment-methods - 支払い方法登録
- GET /rides - 配車履歴
- POST /rides - 配車リクエスト

### オーナー向けAPI (/api/owner/*)
- POST /owners - オーナー登録
- GET /sales - 売上確認
- GET /chairs - 椅子一覧

### 椅子向けAPI (/api/chair/*)
- POST /chairs - 椅子登録
- POST /activity - 稼働状態更新
- POST /coordinate - 位置情報更新

### 内部API (/api/internal/*)
- GET /matching - 配車マッチング

## 監視設定

### nginxログ
- フォーマット: JSON
- 出力先: /var/log/nginx/access.log
- 主要フィールド:
  - time: リクエスト時刻
  - method: HTTPメソッド
  - uri: リクエストURI
  - status: ステータスコード
  - request_time: リクエスト処理時間

```
cp /etc/nginx/nginx.conf misc/nginx/nginx.conf
```
