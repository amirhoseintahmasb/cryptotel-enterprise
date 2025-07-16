#!/bin/bash

# =============================================================================
# CryptoTel Private Docker Registry Setup
# =============================================================================
# This script sets up a private Docker registry with:
# - Authentication (htpasswd)
# - SSL/TLS via Traefik
# - Persistent storage
# - Access via registry.cryptotel.xyz
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DOMAIN="cryptotel.xyz"
REGISTRY_DOMAIN="registry.cryptotel.xyz"
PROJECT_ROOT="/opt/cryptotel"
REGISTRY_USER="admin"
REGISTRY_PASS="CryptoTel2024!"

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

setup_registry_directories() {
    log_info "Setting up registry directories..."
    
    mkdir -p "$PROJECT_ROOT/registry"
    mkdir -p "$PROJECT_ROOT/registry/auth"
    mkdir -p "$PROJECT_ROOT/registry/data"
    mkdir -p "$PROJECT_ROOT/registry/certs"
    
    log_success "Registry directories created"
}

setup_registry_auth() {
    log_info "Setting up registry authentication..."
    
    # Install htpasswd if not available
    if ! command -v htpasswd &> /dev/null; then
        apt-get update
        apt-get install -y apache2-utils
    fi
    
    # Create htpasswd file
    htpasswd -Bbn "$REGISTRY_USER" "$REGISTRY_PASS" > "$PROJECT_ROOT/registry/auth/htpasswd"
    
    log_success "Registry authentication configured"
}

create_registry_config() {
    log_info "Creating registry configuration..."
    
    cat > "$PROJECT_ROOT/registry/config.yml" << 'EOF'
version: 0.1
log:
  level: info
storage:
  filesystem:
    rootdirectory: /var/lib/registry
  delete:
    enabled: true
  cache:
    blobdescriptor: inmemory
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
auth:
  htpasswd:
    realm: basic-realm
    path: /auth/htpasswd
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF

    log_success "Registry configuration created"
}

create_registry_compose() {
    log_info "Creating registry Docker Compose..."
    
    cat > "$PROJECT_ROOT/registry/docker-compose.yml" << EOF
version: '3.8'

services:
  registry:
    image: registry:2
    ports:
      - "5000:5000"
    environment:
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: basic-realm
      REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
      REGISTRY_STORAGE_DELETE_ENABLED: "true"
      REGISTRY_HTTP_HEADERS_X-CONTENT-TYPE-OPTIONS: nosniff
    volumes:
      - ./config.yml:/etc/docker/registry/config.yml:ro
      - ./auth:/auth:ro
      - registry_data:/var/lib/registry
    networks:
      - traefik-public
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.registry.rule=Host(\`$REGISTRY_DOMAIN\`)"
        - "traefik.http.routers.registry.tls.certresolver=letsencrypt"
        - "traefik.http.services.registry.loadbalancer.server.port=5000"
        - "traefik.http.routers.registry.middlewares=registry-auth"
        - "traefik.http.middlewares.registry-auth.basicauth.users=admin:\$2y\$10\$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi"
        - "traefik.http.middlewares.registry-auth.basicauth.removeheader=true"

volumes:
  registry_data:
    driver: local

networks:
  traefik-public:
    external: true
EOF

    log_success "Registry Docker Compose created"
}

deploy_registry() {
    log_info "Deploying registry to Docker Swarm..."
    
    cd "$PROJECT_ROOT/registry"
    docker stack deploy -c docker-compose.yml registry
    
    # Wait for registry to be ready
    log_info "Waiting for registry to be ready..."
    sleep 30
    
    log_success "Registry deployed successfully"
}

test_registry() {
    log_info "Testing registry connectivity..."
    
    # Test local connection
    if curl -u "$REGISTRY_USER:$REGISTRY_PASS" http://localhost:5000/v2/_catalog; then
        log_success "Registry is accessible locally"
    else
        log_error "Registry is not accessible locally"
        return 1
    fi
    
    # Test via Traefik (if available)
    if curl -u "$REGISTRY_USER:$REGISTRY_PASS" https://$REGISTRY_DOMAIN/v2/_catalog; then
        log_success "Registry is accessible via Traefik"
    else
        log_warning "Registry is not accessible via Traefik yet (may need SSL certificate)"
    fi
}

setup_docker_login() {
    log_info "Setting up Docker login for registry..."
    
    # Create Docker config directory
    mkdir -p /root/.docker
    
    # Login to registry
    echo "$REGISTRY_PASS" | docker login $REGISTRY_DOMAIN -u "$REGISTRY_USER" --password-stdin
    
    log_success "Docker login configured"
}

create_registry_management_script() {
    log_info "Creating registry management script..."
    
    cat > "$PROJECT_ROOT/registry/manage-registry.sh" << 'EOF'
#!/bin/bash

# Registry Management Script

REGISTRY_DOMAIN="registry.cryptotel.xyz"
REGISTRY_USER="admin"
REGISTRY_PASS="CryptoTel2024!"

case "$1" in
    "list")
        echo "Listing repositories..."
        curl -u "$REGISTRY_USER:$REGISTRY_PASS" https://$REGISTRY_DOMAIN/v2/_catalog
        ;;
    "tags")
        if [ -z "$2" ]; then
            echo "Usage: $0 tags <repository>"
            exit 1
        fi
        echo "Listing tags for $2..."
        curl -u "$REGISTRY_USER:$REGISTRY_PASS" https://$REGISTRY_DOMAIN/v2/$2/tags/list
        ;;
    "delete")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 delete <repository> <tag>"
            exit 1
        fi
        echo "Deleting $2:$3..."
        # Get digest
        DIGEST=$(curl -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
                     -u "$REGISTRY_USER:$REGISTRY_PASS" \
                     -I https://$REGISTRY_DOMAIN/v2/$2/manifests/$3 | grep Docker-Content-Digest | cut -d' ' -f2 | tr -d '\r')
        # Delete manifest
        curl -X DELETE -u "$REGISTRY_USER:$REGISTRY_PASS" \
             https://$REGISTRY_DOMAIN/v2/$2/manifests/$DIGEST
        ;;
    "cleanup")
        echo "Running garbage collection..."
        docker exec registry_registry.1.$(docker service ps registry_registry -q) registry garbage-collect /etc/docker/registry/config.yml
        ;;
    *)
        echo "Usage: $0 {list|tags|delete|cleanup}"
        echo "  list                    - List all repositories"
        echo "  tags <repository>       - List tags for a repository"
        echo "  delete <repo> <tag>     - Delete a specific tag"
        echo "  cleanup                 - Run garbage collection"
        exit 1
        ;;
esac
EOF

    chmod +x "$PROJECT_ROOT/registry/manage-registry.sh"
    log_success "Registry management script created"
}

main() {
    log_info "Starting CryptoTel Private Registry Setup..."
    
    setup_registry_directories
    setup_registry_auth
    create_registry_config
    create_registry_compose
    deploy_registry
    test_registry
    setup_docker_login
    create_registry_management_script
    
    log_success "CryptoTel Private Registry Setup completed!"
    log_info "Registry access:"
    log_info "  - URL: https://$REGISTRY_DOMAIN"
    log_info "  - Username: $REGISTRY_USER"
    log_info "  - Password: $REGISTRY_PASS"
    log_info "  - Management script: $PROJECT_ROOT/registry/manage-registry.sh"
}

main "$@" 