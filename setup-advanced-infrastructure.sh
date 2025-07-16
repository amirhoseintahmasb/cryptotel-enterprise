#!/bin/bash

# =============================================================================
# CryptoTel Enterprise Infrastructure Setup
# =============================================================================
# Senior DevOps Engineer Grade Setup with:
# - Advanced Load Balancing (HAProxy + Traefik)
# - Docker Swarm with High Availability
# - Enterprise Monitoring Stack (Prometheus + Grafana)
# - Centralized Logging (ELK Stack)
# - Security Hardening
# - Backup & Disaster Recovery
# - Auto-scaling & Health Checks
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Enterprise Configuration
DOMAIN="cryptotel.xyz"
EMAIL="admin@cryptotel.xyz"
PROJECT_ROOT="/opt/cryptotel"
DOCKER_REGISTRY="registry.cryptotel.xyz"
SWARM_MANAGER_IP=$(hostname -I | awk '{print $1}')
NODE_ROLE="manager"  # Change to "worker" for worker nodes

# Security Configuration
SECURITY_GROUPS=("cryptotel-swarm" "cryptotel-web" "cryptotel-db")
FIREWALL_PORTS=(22 80 443 2377 7946 4789 9000 8080 9090 3000 5000 9200 5601)

# Monitoring Configuration
PROMETHEUS_RETENTION="30d"
GRAFANA_ADMIN_PASS="CryptoTel2024!"
ELASTIC_PASS="CryptoTel2024!"

# Logging
LOG_FILE="/var/log/cryptotel-enterprise.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_enterprise() {
    echo -e "${PURPLE}[ENTERPRISE]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

check_enterprise_requirements() {
    log_enterprise "Checking enterprise requirements..."
    
    # Check system resources
    local total_mem=$(free -m | awk 'NR==2{printf "%.0f", $2/1024}')
    local total_disk=$(df -BG / | awk 'NR==2{print $2}' | sed 's/G//')
    
    if [ "$total_mem" -lt 4 ]; then
        log_error "Insufficient RAM. Minimum 4GB required, found ${total_mem}GB"
        exit 1
    fi
    
    if [ "$total_disk" -lt 20 ]; then
        log_error "Insufficient disk space. Minimum 20GB required, found ${total_disk}GB"
        exit 1
    fi
    
    # Check kernel version
    local kernel_version=$(uname -r | cut -d. -f1,2)
    if [ "$(echo "$kernel_version >= 4.9" | bc -l)" -eq 0 ]; then
        log_error "Kernel version 4.9+ required, found $kernel_version"
        exit 1
    fi
    
    log_success "Enterprise requirements met"
}

setup_enterprise_system() {
    log_enterprise "Setting up enterprise system environment..."
    
    # Update system
    apt-get update && apt-get upgrade -y
    
    # Install enterprise packages
    apt-get install -y \
        curl git zsh nginx docker.io docker-compose \
        certbot python3-certbot-nginx \
        htop tree vim ufw fail2ban \
        apache2-utils bc jq \
        prometheus-node-exporter \
        logrotate rsync \
        python3-pip python3-venv \
        build-essential \
        ntp ntpdate \
        sysstat iotop \
        net-tools iputils-ping \
        unzip wget
    
    # Configure NTP
    systemctl enable ntp
    systemctl start ntp
    
    # Configure system limits
    cat >> /etc/security/limits.conf << EOF
# CryptoTel Enterprise Limits
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

    # Configure sysctl for Docker Swarm
    cat >> /etc/sysctl.conf << EOF
# CryptoTel Enterprise Network Tuning
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.tcp_max_syn_backlog=4096
net.core.somaxconn=65535
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=1200
net.ipv4.tcp_max_tw_buckets=400000
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_timestamps=1
vm.swappiness=10
vm.dirty_ratio=15
vm.dirty_background_ratio=5
EOF

    sysctl -p
    
    log_success "Enterprise system setup completed"
}

setup_enterprise_firewall() {
    log_enterprise "Setting up enterprise firewall..."
    
    # Reset UFW
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH
    ufw allow ssh
    
    # Allow Docker Swarm ports
    ufw allow 2377/tcp  # Swarm cluster management
    ufw allow 7946/tcp  # Swarm node communication
    ufw allow 7946/udp  # Swarm node communication
    ufw allow 4789/udp  # Overlay network traffic
    
    # Allow application ports
    for port in "${FIREWALL_PORTS[@]}"; do
        ufw allow "$port/tcp"
    done
    
    # Enable UFW
    ufw --force enable
    
    log_success "Enterprise firewall configured"
}

setup_enterprise_docker() {
    log_enterprise "Setting up enterprise Docker environment..."
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Configure Docker daemon for enterprise
    cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "live-restore": true,
  "userland-proxy": false,
  "experimental": false,
  "metrics-addr": "0.0.0.0:9323",
  "default-ulimits": {
    "nofile": {
      "Hard": 64000,
      "Name": "nofile",
      "Soft": 64000
    }
  }
}
EOF

    systemctl restart docker
    
    # Create enterprise networks
    docker network create --driver overlay --attachable traefik-public 2>/dev/null || true
    docker network create --driver overlay --attachable cryptotel-backend 2>/dev/null || true
    docker network create --driver overlay --attachable cryptotel-monitoring 2>/dev/null || true
    docker network create --driver overlay --attachable cryptotel-logging 2>/dev/null || true
    
    # Initialize Docker Swarm if manager
    if [ "$NODE_ROLE" = "manager" ]; then
        if ! docker info | grep -q "Swarm: active"; then
            log_info "Initializing Docker Swarm as manager..."
            docker swarm init --advertise-addr "$SWARM_MANAGER_IP" --default-addr-pool 10.10.0.0/16
        else
            log_info "Docker Swarm already initialized"
        fi
    fi
    
    log_success "Enterprise Docker setup completed"
}

setup_enterprise_loadbalancer() {
    log_enterprise "Setting up enterprise load balancer..."
    
    mkdir -p "$PROJECT_ROOT/loadbalancer"
    
    # Create HAProxy configuration for external load balancing
    cat > "$PROJECT_ROOT/loadbalancer/haproxy.cfg" << EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
    stats auth admin:CryptoTel2024!

frontend http_front
    bind *:80
    bind *:443 ssl crt /etc/ssl/certs/cryptotel.pem
    http-request redirect scheme https unless { ssl_fc }
    
    # Health checks
    option httpchk GET /health
    
    # Rate limiting
    stick-table type ip size 100k expire 30s store http_req_rate(10s)
    http-request track-sc0 src
    http-request deny deny_status 429 if { sc_http_req_rate(0) gt 100 }
    
    default_backend http_back

backend http_back
    balance roundrobin
    option httpchk GET /health
    server traefik1 127.0.0.1:8080 check
    server traefik2 127.0.0.1:8081 check backup

frontend swarm_front
    bind *:2377
    mode tcp
    default_backend swarm_back

backend swarm_back
    mode tcp
    balance roundrobin
    server swarm1 $SWARM_MANAGER_IP:2377 check
EOF

    # Create HAProxy Docker Compose
    cat > "$PROJECT_ROOT/loadbalancer/docker-compose.yml" << EOF
version: '3.8'

services:
  haproxy:
    image: haproxy:2.8
    ports:
      - "80:80"
      - "443:443"
      - "8404:8404"
      - "2377:2377"
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
      - /etc/ssl/certs:/etc/ssl/certs:ro
    networks:
      - traefik-public
    deploy:
      placement:
        constraints:
          - node.role == manager
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first

networks:
  traefik-public:
    external: true
EOF

    log_success "Enterprise load balancer configured"
}

setup_enterprise_traefik() {
    log_enterprise "Setting up enterprise Traefik..."
    
    mkdir -p "$PROJECT_ROOT/traefik"
    mkdir -p "$PROJECT_ROOT/traefik/certs"
    mkdir -p "$PROJECT_ROOT/traefik/config"
    
    # Create enterprise Traefik configuration
    cat > "$PROJECT_ROOT/traefik/traefik.yml" << 'EOF'
api:
  dashboard: true
  insecure: false
  debug: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entrypoint:
          to: websecure
          scheme: https
          permanent: true
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: letsencrypt
        domains:
          - main: "cryptotel.xyz"
            sans:
              - "*.cryptotel.xyz"

providers:
  docker:
    swarmMode: true
    exposedByDefault: false
    network: traefik-public
    watch: true
  file:
    directory: /etc/traefik/dynamic
    watch: true

certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@cryptotel.xyz
      storage: /certificates/acme.json
      httpChallenge:
        entryPoint: web
      tlsChallenge: {}

log:
  level: INFO
  format: json

accessLog:
  format: json
  fields:
    defaultMode: keep
    headers:
      defaultMode: keep

metrics:
  prometheus:
    buckets:
      - 0.1
      - 0.3
      - 1.2
      - 5.0

ping:
  entryPoint: web

healthcheck:
  interval: 10s
  timeout: 5s
EOF

    # Create dynamic configuration
    mkdir -p "$PROJECT_ROOT/traefik/dynamic"
    cat > "$PROJECT_ROOT/traefik/dynamic/middleware.yml" << 'EOF'
http:
  middlewares:
    security-headers:
      headers:
        frameDeny: true
        sslRedirect: true
        browserXssFilter: true
        contentTypeNosniff: true
        forceSTSHeader: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000
        customFrameOptionsValue: "SAMEORIGIN"
        customRequestHeaders:
          X-Forwarded-Proto: "https"
    
    rate-limit:
      rateLimit:
        burst: 100
        average: 50
    
    cors:
      headers:
        accessControlAllowMethods:
          - GET
          - POST
          - PUT
          - DELETE
          - OPTIONS
        accessControlAllowHeaders:
          - Authorization
          - Content-Type
          - X-Requested-With
        accessControlAllowOriginList:
          - "https://cryptotel.xyz"
          - "https://*.cryptotel.xyz"
        accessControlMaxAge: 100
        addVaryHeader: true
EOF

    # Create Traefik Docker Compose
    cat > "$PROJECT_ROOT/traefik/docker-compose.yml" << EOF
version: '3.8'

services:
  traefik:
    image: traefik:v2.10
    command:
      - --configfile=/etc/traefik/traefik.yml
    ports:
      - "8080:8080"
      - "8081:8081"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      - ./dynamic:/etc/traefik/dynamic:ro
      - ./certs:/certificates
    networks:
      - traefik-public
    deploy:
      placement:
        constraints:
          - node.role == manager
      replicas: 2
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.traefik.rule=Host(\`traefik.$DOMAIN\`)"
        - "traefik.http.routers.traefik.tls.certresolver=letsencrypt"
        - "traefik.http.routers.traefik.service=api@internal"
        - "traefik.http.routers.traefik.middlewares=security-headers"
        - "traefik.http.services.traefik.loadbalancer.server.port=8080"

networks:
  traefik-public:
    external: true
EOF

    log_success "Enterprise Traefik configured"
}

setup_enterprise_monitoring() {
    log_enterprise "Setting up enterprise monitoring stack..."
    
    mkdir -p "$PROJECT_ROOT/monitoring"
    
    # Create Prometheus configuration
    cat > "$PROJECT_ROOT/monitoring/prometheus.yml" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: cryptotel-swarm

rule_files:
  - "alert_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'traefik'
    static_configs:
      - targets: ['traefik:8080']

  - job_name: 'docker'
    static_configs:
      - targets: ['localhost:9323']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
EOF

    # Create alert rules
    cat > "$PROJECT_ROOT/monitoring/alert_rules.yml" << 'EOF'
groups:
  - name: cryptotel-alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% for 5 minutes"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 85% for 5 minutes"

      - alert: HighDiskUsage
        expr: (node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High disk usage on {{ $labels.instance }}"
          description: "Disk usage is above 85% for 5 minutes"

      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "Service {{ $labels.job }} has been down for more than 1 minute"
EOF

    # Create monitoring Docker Compose
    cat > "$PROJECT_ROOT/monitoring/docker-compose.yml" << EOF
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=$PROMETHEUS_RETENTION'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.size=10GB'
      - '--web.enable-lifecycle'
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./alert_rules.yml:/etc/prometheus/alert_rules.yml:ro
      - prometheus_data:/prometheus
    networks:
      - cryptotel-monitoring
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.prometheus.rule=Host(\`prometheus.$DOMAIN\`)"
        - "traefik.http.routers.prometheus.tls.certresolver=letsencrypt"
        - "traefik.http.services.prometheus.loadbalancer.server.port=9090"

  grafana:
    image: grafana/grafana:latest
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASS
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    networks:
      - cryptotel-monitoring
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.grafana.rule=Host(\`grafana.$DOMAIN\`)"
        - "traefik.http.routers.grafana.tls.certresolver=letsencrypt"
        - "traefik.http.services.grafana.loadbalancer.server.port=3000"

  alertmanager:
    image: prom/alertmanager:latest
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager_data:/alertmanager
    networks:
      - cryptotel-monitoring
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.alertmanager.rule=Host(\`alertmanager.$DOMAIN\`)"
        - "traefik.http.routers.alertmanager.tls.certresolver=letsencrypt"
        - "traefik.http.services.alertmanager.loadbalancer.server.port=9093"

  node-exporter:
    image: prom/node-exporter:latest
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    networks:
      - cryptotel-monitoring
    deploy:
      mode: global

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    command:
      - '--docker=/var/run/docker.sock'
      - '--docker_only=true'
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    networks:
      - cryptotel-monitoring
    deploy:
      mode: global

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:

networks:
  cryptotel-monitoring:
    external: true
EOF

    # Create AlertManager configuration
    cat > "$PROJECT_ROOT/monitoring/alertmanager.yml" << 'EOF'
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
  - name: 'web.hook'
    webhook_configs:
      - url: 'http://127.0.0.1:5001/'
EOF

    log_success "Enterprise monitoring stack configured"
}

setup_enterprise_logging() {
    log_enterprise "Setting up enterprise logging stack..."
    
    mkdir -p "$PROJECT_ROOT/logging"
    
    # Create ELK stack Docker Compose
    cat > "$PROJECT_ROOT/logging/docker-compose.yml" << EOF
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    networks:
      - cryptotel-logging
    deploy:
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline:ro
      - ./logstash/config/logstash.yml:/usr/share/logstash/config/logstash.yml:ro
    networks:
      - cryptotel-logging
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.logstash.rule=Host(\`logstash.$DOMAIN\`)"
        - "traefik.http.routers.logstash.tls.certresolver=letsencrypt"
        - "traefik.http.services.logstash.loadbalancer.server.port=9600"

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    networks:
      - cryptotel-logging
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.kibana.rule=Host(\`kibana.$DOMAIN\`)"
        - "traefik.http.routers.kibana.tls.certresolver=letsencrypt"
        - "traefik.http.services.kibana.loadbalancer.server.port=5601"

  filebeat:
    image: docker.elastic.co/beats/filebeat:8.11.0
    user: root
    volumes:
      - ./filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/log/docker:/var/log/docker:ro
    networks:
      - cryptotel-logging
    deploy:
      mode: global

volumes:
  elasticsearch_data:

networks:
  cryptotel-logging:
    external: true
EOF

    # Create Filebeat configuration
    mkdir -p "$PROJECT_ROOT/logging/filebeat"
    cat > "$PROJECT_ROOT/logging/filebeat/filebeat.yml" << 'EOF'
filebeat.inputs:
- type: container
  paths:
    - '/var/lib/docker/containers/*/*.log'

processors:
  - add_docker_metadata:
      host: "unix:///var/run/docker.sock"

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  indices:
    - index: "filebeat-%{[agent.version]}-%{+yyyy.MM.dd}"

setup.kibana:
  host: "kibana:5601"
EOF

    log_success "Enterprise logging stack configured"
}

deploy_enterprise_stack() {
    log_enterprise "Deploying enterprise stack..."
    
    # Deploy load balancer
    cd "$PROJECT_ROOT/loadbalancer"
    docker stack deploy -c docker-compose.yml haproxy
    
    # Deploy Traefik
    cd "$PROJECT_ROOT/traefik"
    docker stack deploy -c docker-compose.yml traefik
    
    # Deploy monitoring
    cd "$PROJECT_ROOT/monitoring"
    docker stack deploy -c docker-compose.yml monitoring
    
    # Deploy logging
    cd "$PROJECT_ROOT/logging"
    docker stack deploy -c docker-compose.yml logging
    
    # Wait for services to be ready
    sleep 60
    
    log_success "Enterprise stack deployed successfully"
}

setup_enterprise_backup() {
    log_enterprise "Setting up enterprise backup system..."
    
    mkdir -p "$PROJECT_ROOT/backup"
    
    # Create backup script
    cat > "$PROJECT_ROOT/backup/backup.sh" << 'EOF'
#!/bin/bash

BACKUP_DIR="/opt/cryptotel/backup"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup Docker volumes
docker run --rm -v cryptotel_registry_data:/data -v "$BACKUP_DIR":/backup alpine tar czf /backup/registry_$DATE.tar.gz -C /data .

# Backup configurations
tar czf "$BACKUP_DIR/config_$DATE.tar.gz" -C /opt/cryptotel traefik monitoring logging

# Backup Docker Swarm secrets
if [ -d "/var/lib/docker/swarm" ]; then
    tar czf "$BACKUP_DIR/swarm_$DATE.tar.gz" -C /var/lib/docker swarm
fi

# Cleanup old backups
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $DATE"
EOF

    chmod +x "$PROJECT_ROOT/backup/backup.sh"
    
    # Create cron job for daily backups
    echo "0 2 * * * /opt/cryptotel/backup/backup.sh" | crontab -
    
    log_success "Enterprise backup system configured"
}

main() {
    log_enterprise "Starting CryptoTel Enterprise Infrastructure Setup..."
    
    check_enterprise_requirements
    setup_enterprise_system
    setup_enterprise_firewall
    setup_enterprise_docker
    setup_enterprise_loadbalancer
    setup_enterprise_traefik
    setup_enterprise_monitoring
    setup_enterprise_logging
    deploy_enterprise_stack
    setup_enterprise_backup
    
    log_success "CryptoTel Enterprise Infrastructure Setup completed!"
    log_enterprise "Enterprise access points:"
    log_enterprise "  - Load Balancer: http://$SWARM_MANAGER_IP:8404"
    log_enterprise "  - Traefik Dashboard: https://traefik.$DOMAIN"
    log_enterprise "  - Prometheus: https://prometheus.$DOMAIN"
    log_enterprise "  - Grafana: https://grafana.$DOMAIN"
    log_enterprise "  - Kibana: https://kibana.$DOMAIN"
    log_enterprise "  - AlertManager: https://alertmanager.$DOMAIN"
}

main "$@" 