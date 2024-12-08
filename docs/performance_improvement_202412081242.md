# パフォーマンス改善記録 2024-12-08 12:42

## 🔍 問題点の特定

アクセスログとスロークエリログの分析から、以下の問題点が特定されました：

1. `/api/owner/[w/-]+` のGETリクエストが特に遅い（平均3.002秒）
2. `/api/chair/[w/-]+` のGETリクエストが多い（8,533件、平均119ms）
3. `/api/app/[w/-]+` のGETリクエストも重い（平均337ms）

## 💡 改善策の実装

### 1. データベースの最適化

#### インデックスの追加
```sql
-- ride_statusesの検索改善
ALTER TABLE ride_statuses ADD INDEX idx_ride_status_lookup (ride_id, created_at);
ALTER TABLE ride_statuses ADD INDEX idx_ride_chair_status (ride_id, chair_sent_at, created_at);

-- chair_locations検索の改善
ALTER TABLE chair_locations ADD INDEX idx_chair_latest (chair_id, created_at);
```

#### 集計テーブルの導入
```sql
CREATE TABLE chair_distance_summary (
    chair_id VARCHAR(26) PRIMARY KEY,
    total_distance DECIMAL(10,2),
    last_updated DATETIME(6),
    INDEX idx_chair_distance (chair_id)
);
```

### 2. アプリケーションコードの改善

#### バッチ処理の実装（batch_handlers.go）
- 5分ごとに椅子の移動距離を集計
- chair_distance_summaryテーブルを定期的に更新
- アプリケーション起動時と初期化時にも更新を実行

#### N+1クエリの解消（owner_handlers.go）
- ownerGetSalesのクエリを最適化
  - 複数のクエリを1つのJOINクエリに統合
  - 売上計算をSQLで効率的に実行
- ownerGetChairsで集計テーブルを活用
  - 重い移動距離計算をキャッシュ化

#### DBコネクション設定の最適化（main.go）
```go
// コネクションプールの設定
_db.SetMaxOpenConns(100)  // 最大接続数
_db.SetMaxIdleConns(20)   // アイドル接続の最大数
_db.SetConnMaxLifetime(5 * time.Minute) // 接続の最大生存時間
```

## 📈 期待される改善効果

1. `/api/owner/[w/-]+` GET
   - 改善前: 3.002秒
   - 改善目標: 200ms以下
   - 改善方法: 集計テーブルの活用、クエリの最適化

2. `/api/chair/[w/-]+` GET
   - 改善前: 119ms
   - 改善目標: 30ms
   - 改善方法: インデックスの活用、集計テーブルの利用

3. `/api/app/[w/-]+` GET
   - 改善前: 337ms
   - 改善目標: 50ms
   - 改善方法: N+1クエリの解消、JOINの最適化

## 🔧 技術的な詳細

### バッチ処理の仕組み
1. アプリケーション起動時に`StartDistanceUpdateBatch()`を実行
2. 5分ごとに`updateChairDistanceSummaries()`を実行
3. 初期化時（`POST /api/initialize`）にも更新を実行

### クエリの最適化ポイント
1. 複雑なWINDOW関数（LAG）を使用していた移動距離計算を集計テーブルに移行
2. JOINを使用して複数のクエリを1回のクエリに統合
3. インデックスを活用した効率的なデータ取得

### コネクションプールの設定理由
- 最大接続数（100）: 同時リクエスト数に対応
- アイドル接続（20）: 接続のオーバーヘッドを削減
- 生存時間（5分）: 接続の再利用とリソース解放のバランス

## 📝 注意点
- バッチ処理による集計は5分間隔のため、データに若干の遅延が発生する可能性あり
- 初期化時には集計テーブルも更新されるため、初期化に要する時間が若干増加
