#!/bin/bash
set -e  # エラーが発生した場合に実行を停止

echo "Starting deployment process..."

# MySQLの設定更新
echo "Updating MySQL configuration..."
if [ -f misc/mysql/mysqld.cnf ]; then
    sudo cp misc/mysql/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf
    sudo systemctl restart mysql
    echo "MySQL configuration updated and service restarted"
else
    echo "Warning: MySQL config file not found at misc/mysql/mysqld.cnf"
fi

# nginxの設定をコピー
echo "Updating nginx configuration..."
sudo cp misc/nginx/nginx.conf /etc/nginx/nginx.conf
sudo systemctl daemon-reload

# ログファイルの消去
echo "Clearing log files..."
sudo truncate -s 0 /var/log/nginx/access.log
sudo truncate -s 0 /var/log/nginx/error.log
sudo truncate -s 0 /var/log/mysql/error.log
sudo truncate -s 0 /var/log/mysql/mysql-slow.log

# nginxの設定再読み込み
echo "Reloading nginx configuration..."
sudo nginx -t && sudo systemctl reload nginx

# golangの更新
echo "Updating golang application..."
pushd go && go build -o isuride && sudo systemctl restart isuride-go.service && popd

# logsディレクトリの作成
echo "Creating logs directory..."
mkdir -p logs

# DBのパフォーマンス測定
echo "Running database performance measurement..."
sudo query-digester -duration 80 -- -uroot -proot

# slow_queryログの移動
echo "Moving slow query logs..."
sudo mv /tmp/slow_query_*.digest logs/

# alpの実行
echo "Running alp analysis..."
sh ./alp.sh

echo "Deployment complete!"
