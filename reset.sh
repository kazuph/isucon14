#!/bin/bash
# nginxの設定をコピー
sudo cp misc/nginx/nginx.conf /etc/nginx/nginx.conf
sudo systemctl daemon-reload

# ログファイルの消去
sudo truncate -s 0 /var/log/nginx/access.log
sudo truncate -s 0 /var/log/nginx/error.log

# nginxの設定再読み込み（新しいログフォーマットを適用）
sudo nginx -t && sudo systemctl reload nginx

# logsディレクトリの作成
mkdir -p logs

# DBのパフォーマンス測定
sudo query-digester -duration 80 -- -uroot -proot

# slow_query_20241108022705.digestをローカルにコピー
cp /tmp/slow_query_*.digest logs/

sh ./alp.sh
