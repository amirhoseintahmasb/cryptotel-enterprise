#!/bin/bash

# =============================================================================
# CryptoTel Web3 Infrastructure Setup Script
# =============================================================================
# This script sets up a complete Web3 development environment with:
# - Traefik reverse proxy with SSL/TLS
# - Portainer for container management
# - Docker Swarm for orchestration
# - Hardhat for smart contract development
# - React frontend for dApp
# - Admin panel for contract management
# - Monitoring and health checks
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="cryptotel.xyz"
EMAIL="admin@cryptotel.xyz"
PROJECT_ROOT="/opt/cryptotel"
DOCKER_REGISTRY="registry.cryptotel.xyz"

# Logging
LOG_FILE="/var/log/cryptotel-setup.log"
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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_dependencies() {
    log_info "Checking system dependencies..."
    
    local deps=("curl" "git" "wget" "unzip" "jq")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warning "Missing dependencies: ${missing[*]}"
        log_info "Installing missing dependencies..."
        apt-get update
        apt-get install -y "${missing[@]}"
    fi
    
    log_success "Dependencies check completed"
}

setup_system() {
    log_info "Setting up system environment..."
    
    # Update system
    apt-get update && apt-get upgrade -y
    
    # Install essential packages
    apt-get install -y \
        curl \
        git \
        zsh \
        nginx \
        docker.io \
        docker-compose \
        certbot \
        python3-certbot-nginx \
        htop \
        tree \
        vim \
        ufw \
        fail2ban
    
    # Configure firewall
    ufw --force enable
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 9000/tcp  # Portainer
    ufw allow 8080/tcp  # Traefik dashboard
    
    log_success "System setup completed"
}

setup_docker() {
    log_info "Setting up Docker environment..."
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Create Docker networks
    docker network create traefik-public 2>/dev/null || true
    docker network create cryptotel-network 2>/dev/null || true
    
    # Initialize Docker Swarm if not already initialized
    if ! docker info | grep -q "Swarm: active"; then
        log_info "Initializing Docker Swarm..."
        docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')
    else
        log_info "Docker Swarm already initialized"
    fi
    
    log_success "Docker setup completed"
}

setup_traefik() {
    log_info "Setting up Traefik reverse proxy..."
    
    mkdir -p "$PROJECT_ROOT/traefik"
    mkdir -p "$PROJECT_ROOT/traefik/certs"
    mkdir -p "$PROJECT_ROOT/traefik/config"
    
    # Create Traefik configuration
    cat > "$PROJECT_ROOT/traefik/traefik.yml" << 'EOF'
api:
  dashboard: true
  insecure: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entrypoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

providers:
  docker:
    swarmMode: true
    exposedByDefault: false
    network: traefik-public

certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@cryptotel.xyz
      storage: /certificates/acme.json
      httpChallenge:
        entryPoint: web

log:
  level: INFO

accessLog: {}
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
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      - ./certs:/certificates
    networks:
      - traefik-public
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.traefik.rule=Host(\`traefik.cryptotel.xyz\`)"
        - "traefik.http.routers.traefik.tls.certresolver=letsencrypt"
        - "traefik.http.routers.traefik.service=api@internal"
        - "traefik.http.routers.traefik.middlewares=auth"
        - "traefik.http.middlewares.auth.basicauth.users=admin:\$2y\$10\$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi"

networks:
  traefik-public:
    external: true
EOF

    log_success "Traefik configuration created"
}

setup_portainer() {
    log_info "Setting up Portainer..."
    
    mkdir -p "$PROJECT_ROOT/portainer"
    
    cat > "$PROJECT_ROOT/portainer/docker-compose.yml" << EOF
version: '3.8'

services:
  portainer:
    image: portainer/portainer-ce:latest
    command: -H unix:///var/run/docker.sock
    restart: always
    security_opt:
      - no-new-privileges:true
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - portainer_data:/data
    networks:
      - traefik-public
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.portainer.rule=Host(\`portainer.cryptotel.xyz\`)"
        - "traefik.http.routers.portainer.tls.certresolver=letsencrypt"
        - "traefik.http.services.portainer.loadbalancer.server.port=9000"

volumes:
  portainer_data:

networks:
  traefik-public:
    external: true
EOF

    log_success "Portainer configuration created"
}

deploy_services() {
    log_info "Deploying services to Docker Swarm..."
    
    # Deploy Traefik
    cd "$PROJECT_ROOT/traefik"
    docker stack deploy -c docker-compose.yml traefik
    
    # Deploy Portainer
    cd "$PROJECT_ROOT/portainer"
    docker stack deploy -c docker-compose.yml portainer
    
    # Wait for services to be ready
    sleep 30
    
    log_success "Services deployed successfully"
}

setup_private_registry() {
    log_info "Setting up private Docker registry..."
    
    # Run the registry setup script
    if [ -f "$PROJECT_ROOT/setup-private-registry.sh" ]; then
        chmod +x "$PROJECT_ROOT/setup-private-registry.sh"
        "$PROJECT_ROOT/setup-private-registry.sh"
    else
        log_error "Registry setup script not found"
        return 1
    fi
}

main() {
    log_info "Starting CryptoTel Infrastructure Setup..."
    
    check_root
    check_dependencies
    setup_system
    setup_docker
    setup_traefik
    setup_portainer
    deploy_services
    setup_private_registry
    
    log_success "CryptoTel Infrastructure Setup completed successfully!"
    log_info "Access points:"
    log_info "  - Traefik Dashboard: https://traefik.$DOMAIN"
    log_info "  - Portainer: https://portainer.$DOMAIN"
    log_info "  - Private Registry: https://registry.$DOMAIN"
}

# Run main function
main "$@" 