# サーバー構成と設定手順書

## 1. サーバー構成

| サーバー | Public IPv4 | Private IPv4 | 役割 |
|---------|-------------|--------------|------|
| server1 | 54.64.128.31 | 192.168.0.11 | Master DB + アプリケーション |
| server2 | 54.248.111.13 | 192.168.0.12 | Slave DB + アプリケーション |
| server3 | 35.75.53.201 | 192.168.0.13 | ロードバランサー (Nginx) |

## 2. 各サーバーの設定手順

### 2.1 Server1（Master DB + アプリケーション）

#### Nginxの停止と無効化

```bash
# Nginxを停止し、自動起動を無効化
sudo systemctl stop nginx
sudo systemctl disable nginx
```

#### アプリケーション設定
アプリケーションは8080ポートで直接リッスンします。

#### MySQL設定 (`/etc/mysql/mysql.conf.d/mysqld.cnf`)

```conf
[mysqld]
# レプリケーション設定
server-id = 1
log-bin = /var/log/mysql/mysql-bin.log
binlog_format = ROW
sync_binlog = 1
innodb_flush_log_at_trx_commit = 1

# バインドアドレス（内部ネットワークからの接続を許可）
bind-address = 0.0.0.0
```

#### 初期ユーザー設定

MySQLサーバー起動後、以下のコマンドでMySQLプロンプトにアクセスし、SQLコマンドを実行します：

```bash
sudo mysql -u root
```

```sql
CREATE USER 'isucon'@'192.168.0.%' IDENTIFIED BY 'isucon';
GRANT ALL PRIVILEGES ON isuride.* TO 'isucon'@'192.168.0.%';
CREATE USER 'isucon'@'localhost' IDENTIFIED BY 'isucon';
GRANT ALL PRIVILEGES ON isuride.* TO 'isucon'@'localhost';
FLUSH PRIVILEGES;
```

#### レプリケーションユーザーの作成

```sql
CREATE USER 'repl'@'%' IDENTIFIED BY 'isucon_repl';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
```

### 2.2 Server2（Slave DB + アプリケーション）

#### Nginxの停止と無効化

```bash
# Nginxを停止し、自動起動を無効化
sudo systemctl stop nginx
sudo systemctl disable nginx
```

#### アプリケーション設定
アプリケーションは8080ポートで直接リッスンします。

#### MySQL設定 (`/etc/mysql/mysql.conf.d/mysqld.cnf`)

```conf
[mysqld]
# レプリケーション設定
server-id = 2
relay-log = /var/log/mysql/mysql-relay-bin.log
read_only = ON

# レプリケーション接続設定
replica_host = '192.168.0.11'
replica_user = 'repl'
replica_password = 'isucon_repl'
replica_auto_position = 1

# バインドアドレス（内部ネットワークからの接続を許可）
bind-address = 0.0.0.0
```

#### 初期ユーザー設定

MySQLサーバー起動後、以下のコマンドでMySQLプロンプトにアクセスし、SQLコマンドを実行します：

```bash
sudo mysql -u root
```

```sql
CREATE USER 'isucon'@'192.168.0.%' IDENTIFIED BY 'isucon';
GRANT ALL PRIVILEGES ON isuride.* TO 'isucon'@'192.168.0.%';
CREATE USER 'isucon'@'localhost' IDENTIFIED BY 'isucon';
GRANT ALL PRIVILEGES ON isuride.* TO 'isucon'@'localhost';
FLUSH PRIVILEGES;
```

#### レプリケーション設定

```bash
# 初期データの同期
sudo systemctl stop mysql
sudo rm -rf /var/lib/mysql/*
sudo mysqldump -h 192.168.0.11 -u isucon -p isuride --single-transaction > /tmp/dump.sql
sudo mysql isuride < /tmp/dump.sql

# MySQLの設定を反映して再起動
sudo systemctl restart mysql

# レプリケーションの状態確認
sudo mysql -e "SHOW SLAVE STATUS\G"
```

注意: レプリケーションの設定は`/etc/mysql/mysql.conf.d/mysqld.cnf`に記述されているため、
`CHANGE MASTER TO`コマンドを実行する必要はありません。MySQLの再起動後に自動的に
レプリケーションが開始されます。

#### アプリケーション設定（環境変数: `/etc/environment`）

```bash
ISUCON_DB_HOST=localhost
ISUCON_DB_PORT=3306
ISUCON_DB_USER=isucon
ISUCON_DB_PASSWORD=isucon
ISUCON_DB_NAME=isuride
```

### 2.3 Server3（ロードバランサー）

#### サイト設定 (`/etc/nginx/sites-available/isuride.conf`)

```nginx
# アプリケーションサーバーは8080ポートで直接リッスン
upstream write_servers {
    server 192.168.0.11:8080;  # Server1: Master
}

upstream read_servers {
    server 192.168.0.12:8080;  # Server2: Slave
    server 192.168.0.11:8080 backup;  # Server1: バックアップ
}

server {
    listen 80;
    server_name _;

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 書き込み系エンドポイント
        location ~ ^/api/.*/(?:create|update|delete|post) {
            proxy_pass http://write_servers;
        }

        # chair_locationsの更新
        location /api/chair/coordinate {
            proxy_pass http://write_servers;
        }

        # デフォルトは読み取りサーバーへ
        proxy_pass http://read_servers;
    }
}
```

#### Nginxの設定有効化

```bash
sudo ln -s /etc/nginx/sites-available/isuride.conf /etc/nginx/sites-enabled/isuride.conf
sudo rm -f /etc/nginx/sites-enabled/default
```

## 3. 動作確認

### レプリケーションステータスの確認（Server2）

```sql
SHOW SLAVE STATUS\G
```

### Nginxの設定テスト（Server3）

```bash
sudo nginx -t
```

## 4. トラブルシューティング

### レプリケーションが停止した場合（Server2）

```sql
STOP SLAVE;
RESET SLAVE;
CHANGE MASTER TO
    MASTER_HOST='192.168.0.11',
    MASTER_USER='repl',
    MASTER_PASSWORD='isucon_repl',
    MASTER_AUTO_POSITION=1;
START SLAVE;
```

### Nginxのログ確認（Server3）

```bash
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```
