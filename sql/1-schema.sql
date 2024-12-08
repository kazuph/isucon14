SET CHARACTER_SET_CLIENT = utf8mb4;
SET CHARACTER_SET_CONNECTION = utf8mb4;

USE isuride;

DROP TABLE IF EXISTS settings;
CREATE TABLE settings
(
  name  VARCHAR(30) NOT NULL COMMENT '設定名',
  value TEXT        NOT NULL COMMENT '設定値',
  PRIMARY KEY (name)
)
  COMMENT = 'システム設定テーブル';

DROP TABLE IF EXISTS chair_models;
CREATE TABLE chair_models
(
  name  VARCHAR(50) NOT NULL COMMENT '椅子モデル名',
  speed INTEGER     NOT NULL COMMENT '移動速度',
  PRIMARY KEY (name)
)
  COMMENT = '椅子モデルテーブル';

DROP TABLE IF EXISTS chairs;
CREATE TABLE chairs
(
  id           VARCHAR(26)  NOT NULL COMMENT '椅子ID',
  owner_id     VARCHAR(26)  NOT NULL COMMENT 'オーナーID',
  name         VARCHAR(30)  NOT NULL COMMENT '椅子の名前',
  model        TEXT         NOT NULL COMMENT '椅子のモデル',
  is_active    TINYINT(1)   NOT NULL COMMENT '配椅子受付中かどうか',
  access_token VARCHAR(255) NOT NULL COMMENT 'アクセストークン',
  created_at   DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '登録日時',
  updated_at   DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新日時',
  PRIMARY KEY (id)
)
  COMMENT = '椅子情報テーブル';

DROP TABLE IF EXISTS chair_locations;
CREATE TABLE chair_locations
(
  id         VARCHAR(26) NOT NULL,
  chair_id   VARCHAR(26) NOT NULL COMMENT '椅子ID',
  latitude   INTEGER     NOT NULL COMMENT '経度',
  longitude  INTEGER     NOT NULL COMMENT '緯度',
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '登録日時',
  PRIMARY KEY (id)
)
  COMMENT = '椅子の現在位置情報テーブル';

DROP TABLE IF EXISTS users;
CREATE TABLE users
(
  id              VARCHAR(26)  NOT NULL COMMENT 'ユーザーID',
  username        VARCHAR(30)  NOT NULL COMMENT 'ユーザー名',
  firstname       VARCHAR(30)  NOT NULL COMMENT '本名(名前)',
  lastname        VARCHAR(30)  NOT NULL COMMENT '本名(名字)',
  date_of_birth   VARCHAR(30)  NOT NULL COMMENT '生年月日',
  access_token    VARCHAR(255) NOT NULL COMMENT 'アクセストークン',
  invitation_code VARCHAR(30)  NOT NULL COMMENT '招待トークン',
  created_at      DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '登録日時',
  updated_at      DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新日時',
  PRIMARY KEY (id),
  UNIQUE (username),
  UNIQUE (access_token),
  UNIQUE (invitation_code)
)
  COMMENT = '利用者情報テーブル';

DROP TABLE IF EXISTS payment_tokens;
CREATE TABLE payment_tokens
(
  user_id    VARCHAR(26)  NOT NULL COMMENT 'ユーザーID',
  token      VARCHAR(255) NOT NULL COMMENT '決済トークン',
  created_at DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '登録日時',
  PRIMARY KEY (user_id)
)
  COMMENT = '決済トークンテーブル';

DROP TABLE IF EXISTS rides;
CREATE TABLE rides
(
  id                    VARCHAR(26) NOT NULL COMMENT 'ライドID',
  user_id               VARCHAR(26) NOT NULL COMMENT 'ユーザーID',
  chair_id              VARCHAR(26) NULL     COMMENT '割り当てられた椅子ID',
  pickup_latitude       INTEGER     NOT NULL COMMENT '配車位置(経度)',
  pickup_longitude      INTEGER     NOT NULL COMMENT '配車位置(緯度)',
  destination_latitude  INTEGER     NOT NULL COMMENT '目的地(経度)',
  destination_longitude INTEGER     NOT NULL COMMENT '目的地(緯度)',
  evaluation            INTEGER     NULL     COMMENT '評価',
  created_at            DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '要求日時',
  updated_at            DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '状態更新日時',
  PRIMARY KEY (id)
)
  COMMENT = 'ライド情報テーブル';

DROP TABLE IF EXISTS ride_statuses;
CREATE TABLE ride_statuses
(
  id              VARCHAR(26)                                                                NOT NULL,
  ride_id VARCHAR(26)                                                                        NOT NULL COMMENT 'ライドID',
  status          ENUM ('MATCHING', 'ENROUTE', 'PICKUP', 'CARRYING', 'ARRIVED', 'COMPLETED') NOT NULL COMMENT '状態',
  created_at      DATETIME(6)                                                                NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '状態変更日時',
  app_sent_at     DATETIME(6)                                                                NULL COMMENT 'ユーザーへの状態通知日時',
  chair_sent_at   DATETIME(6)                                                                NULL COMMENT '椅子への状態通知日時',
  PRIMARY KEY (id)
)
  COMMENT = 'ライドステータスの変更履歴テーブル';

DROP TABLE IF EXISTS owners;
CREATE TABLE owners
(
  id                   VARCHAR(26)  NOT NULL COMMENT 'オーナーID',
  name                 VARCHAR(30)  NOT NULL COMMENT 'オーナー名',
  access_token         VARCHAR(255) NOT NULL COMMENT 'アクセストークン',
  chair_register_token VARCHAR(255) NOT NULL COMMENT '椅子登録トークン',
  created_at           DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '登録日時',
  updated_at           DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新日時',
  PRIMARY KEY (id),
  UNIQUE (name),
  UNIQUE (access_token),
  UNIQUE (chair_register_token)
)
  COMMENT = '椅子のオーナー情報テーブル';

DROP TABLE IF EXISTS coupons;
CREATE TABLE coupons
(
  user_id    VARCHAR(26)  NOT NULL COMMENT '所有しているユーザーのID',
  code       VARCHAR(255) NOT NULL COMMENT 'クーポンコード',
  discount   INTEGER      NOT NULL COMMENT '割引額',
  created_at DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '付与日時',
  used_by    VARCHAR(26)  NULL COMMENT 'クーポンが適用されたライドのID',
  PRIMARY KEY (user_id, code)
)
  COMMENT 'クーポンテーブル';

-- ride_statusesの検索改善
ALTER TABLE ride_statuses ADD INDEX idx_ride_status_lookup (ride_id, created_at);
ALTER TABLE ride_statuses ADD INDEX idx_ride_chair_status (ride_id, chair_sent_at, created_at);

-- chair_locations検索の改善
ALTER TABLE chair_locations ADD INDEX idx_chair_latest (chair_id, created_at);

-- 椅子の移動距離集計用テーブル
DROP TABLE IF EXISTS chair_distance_stats;
CREATE TABLE chair_distance_stats
(
    chair_id VARCHAR(26) NOT NULL COMMENT '椅子ID',
    total_distance INT NOT NULL DEFAULT 0 COMMENT '総移動距離',
    last_updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '最終更新日時',
    PRIMARY KEY (chair_id),
    INDEX idx_last_updated (last_updated_at)
) COMMENT = '椅子の移動距離集計テーブル';

-- 位置情報更新時の集計更新トリガー
DELIMITER //

CREATE TRIGGER after_chair_location_insert
AFTER INSERT ON chair_locations
FOR EACH ROW
BEGIN
    DECLARE prev_lat INT;
    DECLARE prev_lon INT;

    -- 前回の位置情報を取得
    SELECT latitude, longitude
    INTO prev_lat, prev_lon
    FROM chair_locations
    WHERE chair_id = NEW.chair_id
        AND created_at < NEW.created_at
    ORDER BY created_at DESC
    LIMIT 1;

    -- 距離を計算して更新
    IF prev_lat IS NOT NULL THEN
        INSERT INTO chair_distance_stats
            (chair_id, total_distance, last_updated_at)
        VALUES
            (NEW.chair_id, ABS(NEW.latitude - prev_lat) + ABS(NEW.longitude - prev_lon), NEW.created_at)
        ON DUPLICATE KEY UPDATE
            total_distance = total_distance + ABS(NEW.latitude - prev_lat) + ABS(NEW.longitude - prev_lon),
            last_updated_at = NEW.created_at;
    END IF;
END//

DELIMITER ;

-- 既存データの移行
INSERT INTO chair_distance_stats (chair_id, total_distance, last_updated_at)
SELECT
    chair_id,
    SUM(distance),
    MAX(created_at)
FROM (
    SELECT
        chair_id,
        created_at,
        ABS(latitude - LAG(latitude) OVER (PARTITION BY chair_id ORDER BY created_at)) +
        ABS(longitude - LAG(longitude) OVER (PARTITION BY chair_id ORDER BY created_at)) AS distance
    FROM chair_locations
) tmp
WHERE distance IS NOT NULL
GROUP BY chair_id;

-- パフォーマンス改善のための追加インデックス
-- ridesテーブルの検索改善
ALTER TABLE rides ADD INDEX idx_chair_updated (chair_id, updated_at DESC);
ALTER TABLE rides ADD INDEX idx_user_created (user_id, created_at DESC);

-- chairsテーブルの検索改善
ALTER TABLE chairs ADD INDEX idx_access_token (access_token);

-- -- couponsテーブルの検索改善
-- ALTER TABLE coupons ADD INDEX idx_used_by (used_by);
