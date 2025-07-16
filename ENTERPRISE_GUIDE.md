# Enterprise Multi-Project Management Platform
## Quick Reference Guide

### System Status: ✅ HEALTHY
- **Disk Usage**: 3% (187G available)
- **Services**: 9 running
- **Networks**: 2 overlay networks active

---

## 🚀 Essential Commands

### 1. System Status
```bash
# Check all services
docker service ls

# Check system resources
df -h
docker system df

# Check service logs
docker service logs <service_name> --tail 50
```

### 2. Service Management
```bash
# Deploy a new project
cd /opt/cryptotel/projects/<project-name>
docker stack deploy -c docker-compose.yml <stack-name>

# Remove a project
docker stack rm <stack-name>

# Scale a service
docker service scale <service-name>=2

# Update a service
docker service update <service-name>
```

### 3. Registry Management
```bash
# Access Registry UI
https://registry-ui.cryptotel.xyz

# Push to registry
docker tag image:tag registry.cryptotel.xyz/project/image:tag
docker push registry.cryptotel.xyz/project/image:tag

# Pull from registry
docker pull registry.cryptotel.xyz/project/image:tag
```

### 4. Monitoring
```bash
# Access monitoring
https://grafana.cryptotel.xyz (admin/EnterpriseSecurePass123!)
https://prometheus.cryptotel.xyz
https://alertmanager.cryptotel.xyz
```

---

## 📦 Multi-Project Management

### Project Structure
```
/opt/cryptotel/
├── projects/
│   ├── project1/
│   │   ├── docker-compose.yml
│   │   ├── .env
│   │   └── src/
│   ├── project2/
│   │   ├── docker-compose.yml
│   │   └── src/
│   └── shared/
│       ├── networks/
│       └── volumes/
├── registry/
├── monitoring/
└── traefik/
```

### Adding New Project
```bash
# 1. Create project directory
mkdir -p /opt/cryptotel/projects/my-project
cd /opt/cryptotel/projects/my-project

# 2. Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  app:
    image: my-app:latest
    networks:
      - traefik
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.cryptotel.xyz`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls=true"
      - "traefik.http.routers.myapp.tls.certresolver=selfsigned"
      - "traefik.http.services.myapp.loadbalancer.server.port=80"

networks:
  traefik:
    external: true
EOF

# 3. Deploy
docker stack deploy -c docker-compose.yml my-project
```

---

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow
```yaml
# .github/workflows/deploy.yml
name: Deploy to Enterprise Platform

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Docker image
        run: |
          docker build -t registry.cryptotel.xyz/${{ github.repository }}:${{ github.sha }} .
          docker build -t registry.cryptotel.xyz/${{ github.repository }}:latest .
      
      - name: Push to Registry
        run: |
          docker push registry.cryptotel.xyz/${{ github.repository }}:${{ github.sha }}
          docker push registry.cryptotel.xyz/${{ github.repository }}:latest
      
      - name: Deploy to Swarm
        run: |
          ssh root@cryptotel.xyz "cd /opt/cryptotel/projects/${{ github.event.repository.name }} && docker stack deploy -c docker-compose.yml ${{ github.event.repository.name }}"
```

### Automated Deployment Script
```bash
#!/bin/bash
# /opt/cryptotel/scripts/deploy-project.sh

PROJECT_NAME=$1
REGISTRY_URL="registry.cryptotel.xyz"

# Build and push
docker build -t $REGISTRY_URL/$PROJECT_NAME:latest .
docker push $REGISTRY_URL/$PROJECT_NAME:latest

# Deploy
cd /opt/cryptotel/projects/$PROJECT_NAME
docker stack deploy -c docker-compose.yml $PROJECT_NAME

echo "Project $PROJECT_NAME deployed successfully!"
```

---

## 🗄️ Storage Management

### Cleanup Commands
```bash
# Remove unused images
docker image prune -a -f

# Remove unused volumes
docker volume prune -f

# Remove unused networks
docker network prune -f

# Complete cleanup
docker system prune -a -f --volumes

# Check space usage
docker system df
```

### Automated Cleanup Script
```bash
#!/bin/bash
# /opt/cryptotel/scripts/cleanup.sh

echo "=== Docker Cleanup ==="

# Remove images older than 30 days
docker image prune -a -f --filter "until=720h"

# Remove stopped containers
docker container prune -f

# Remove unused volumes
docker volume prune -f

# Remove unused networks
docker network prune -f

# Clean up build cache
docker builder prune -f

echo "Cleanup completed!"
```

### Registry Cleanup
```bash
# Remove old tags from registry
docker exec registry registry garbage-collect /etc/docker/registry/config.yml

# List registry contents
curl -X GET http://registry.cryptotel.xyz/v2/_catalog
curl -X GET http://registry.cryptotel.xyz/v2/<repo>/tags/list
```

---

## 📊 Monitoring & Alerting

### Grafana Dashboards
- **System Overview**: CPU, Memory, Disk, Network
- **Docker Swarm**: Service health, replicas, resource usage
- **Application Metrics**: Response times, error rates

### Alert Rules
```yaml
# /opt/cryptotel/monitoring/alertmanager.yml
groups:
  - name: docker_alerts
    rules:
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.service }} is down"
      
      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9
        for: 5m
        labels:
          severity: warning
```

---

## 🔒 Security

### SSL Certificates
```bash
# Check certificate status
openssl s_client -connect cryptotel.xyz:443 -servername cryptotel.xyz

# Renew certificates
docker service update traefik_traefik
```

### Access Control
```bash
# Add user to registry
htpasswd -B /opt/cryptotel/enterprise/registry/auth/htpasswd username

# Update Traefik auth
docker service update --label-add "traefik.http.routers.api.middlewares=auth" traefik_traefik
```

---

## 🛠️ Troubleshooting

### Common Issues

**1. Service Not Accessible**
```bash
# Check service health
docker service ps <service-name>

# Check network connectivity
docker exec $(docker ps -q --filter "name=traefik") wget -qO- http://service-name:port

# Check Traefik logs
docker service logs traefik_traefik --tail 50
```

**2. Registry Issues**
```bash
# Check registry health
curl -u username:password https://registry.cryptotel.xyz/v2/_catalog

# Restart registry
docker service update enterprise-registry_registry
```

**3. Storage Full**
```bash
# Quick cleanup
docker system prune -a -f

# Check what's using space
du -sh /var/lib/docker/*
```

---

## 📋 Maintenance Schedule

### Daily
- Check service health: `docker service ls`
- Monitor disk usage: `df -h`

### Weekly
- Run cleanup script: `/opt/cryptotel/scripts/cleanup.sh`
- Update base images: `docker pull <image>:latest`

### Monthly
- Review and rotate logs
- Update SSL certificates
- Backup configuration

---

## 🎯 Quick Start for New Projects

1. **Clone your project**
```bash
cd /opt/cryptotel/projects
git clone https://github.com/your-org/your-project.git
cd your-project
```

2. **Create docker-compose.yml with Traefik labels**

3. **Deploy**
```bash
docker stack deploy -c docker-compose.yml your-project
```

4. **Add DNS record**: `your-project.cryptotel.xyz` → Server IP

5. **Access**: `https://your-project.cryptotel.xyz`

---

## 📞 Emergency Contacts

- **Server Access**: SSH to cryptotel.xyz
- **Registry**: https://registry-ui.cryptotel.xyz
- **Monitoring**: https://grafana.cryptotel.xyz
- **Management**: https://portainer.cryptotel.xyz

---

*Last Updated: $(date)*
*System Status: ✅ Operational* 