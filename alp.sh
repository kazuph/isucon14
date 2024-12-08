export LOG_DATE=$(date +%Y%m%d%H%M)
echo $LOG_DATE
sudo mv /var/log/nginx/access.log /tmp/access_$LOG_DATE.log
sudo chown root:root /tmp/access_$LOG_DATE.log
sudo chmod 644 /tmp/access_$LOG_DATE.log
sudo systemctl reload nginx

# logsディレクトリがない場合は作成
mkdir -p logs

# 集計　
sudo alp json --sort sum -r -m "/api/chair/[\w/-]+,/api/app/[\w/-]+,/api/owner/[\w/-]+,/api/internal/[\w/-]+,/assets/[\w.-]+,/images/[\w.-]+,/favicon[\w.-]*" \
--percentiles="50,90,95,99" \
-o count,1xx,2xx,3xx,4xx,5xx,method,uri,min,max,sum,avg,p50,p90,p95,p99,stddev < /tmp/access_$LOG_DATE.log > logs/alp_$LOG_DATE.log
cat logs/alp_$LOG_DATE.log
echo logs/alp_$LOG_DATE.log
