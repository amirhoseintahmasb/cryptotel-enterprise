# 🚀 Enterprise Platform Quick Start

## ✅ System Status: HEALTHY
- **Disk Usage**: 3% (187G available)
- **Services**: 9 running
- **Memory**: 11.2% used
- **CPU**: 52.3% (normal for active system)

---

## 🎯 What You Have Now

### ✅ Working Services
- **Traefik**: Load balancer & SSL termination
- **Registry**: Private Docker registry with UI
- **Monitoring**: Prometheus + Grafana + AlertManager
- **Management**: Portainer for container management
- **Backup**: Automated backup system

### ✅ Access URLs
- **Registry UI**: https://registry-ui.cryptotel.xyz ✅
- **AlertManager**: https://alertmanager.cryptotel.xyz ✅
- **Grafana**: https://grafana.cryptotel.xyz (admin/EnterpriseSecurePass123!)
- **Prometheus**: https://prometheus.cryptotel.xyz
- **Portainer**: https://portainer.cryptotel.xyz

---

## 🛠️ Essential Commands

### System Status
```bash
# Quick status check
/opt/cryptotel/scripts/status.sh

# Check services
docker service ls

# Check disk usage
df -h
```

### Project Management
```bash
# Deploy new project
/opt/cryptotel/scripts/deploy-project.sh my-project

# Remove project
docker stack rm my-project

# Scale service
docker service scale my-project_web=3
```

### Storage Management
```bash
# Cleanup unused resources
/opt/cryptotel/scripts/cleanup.sh

# Manual cleanup
docker system prune -a -f
```

---

## 📦 Adding New Projects

### 1. Create Project Structure
```bash
mkdir -p /opt/cryptotel/projects/my-project
cd /opt/cryptotel/projects/my-project
```

### 2. Create docker-compose.yml
```yaml
version: '3.8'
services:
  web:
    image: registry.cryptotel.xyz/my-project:latest
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
```

### 3. Deploy
```bash
docker stack deploy -c docker-compose.yml my-project
```

### 4. Add DNS Record
Add `myapp.cryptotel.xyz` → Your server IP in Cloudflare

---

## 🔄 CI/CD Setup

### GitHub Actions (.github/workflows/deploy.yml)
```yaml
name: Deploy to Enterprise Platform

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build and Push
        run: |
          docker build -t registry.cryptotel.xyz/${{ github.repository }}:latest .
          docker push registry.cryptotel.xyz/${{ github.repository }}:latest
      
      - name: Deploy
        run: |
          ssh root@cryptotel.xyz "cd /opt/cryptotel/projects/${{ github.event.repository.name }} && docker stack deploy -c docker-compose.yml ${{ github.event.repository.name }}"
```

---

## 🗄️ Storage Optimization

### Automated Cleanup (Weekly)
```bash
# Add to crontab
0 2 * * 0 /opt/cryptotel/scripts/cleanup.sh
```

### Manual Cleanup
```bash
# Remove old images
docker image prune -a -f --filter "until=168h"

# Remove unused volumes
docker volume prune -f

# Complete cleanup
docker system prune -a -f --volumes
```

### Registry Management
```bash
# List registry contents
curl -X GET http://registry.cryptotel.xyz/v2/_catalog

# Remove old tags
docker exec registry registry garbage-collect /etc/docker/registry/config.yml
```

---

## 📊 Monitoring

### Grafana Dashboards
- **System Overview**: CPU, Memory, Disk
- **Docker Swarm**: Service health, replicas
- **Application Metrics**: Response times, errors

### Alert Rules
- Service down alerts
- High memory usage (>90%)
- Disk space warnings (>80%)

---

## 🔒 Security

### SSL Certificates
- Automatic Let's Encrypt certificates
- Self-signed fallback for internal services

### Access Control
- Registry authentication
- Traefik dashboard protection
- Service isolation via networks

---

## 🛠️ Troubleshooting

### Service Not Accessible
```bash
# Check service health
docker service ps <service-name>

# Check logs
docker service logs <service-name> --tail 50

# Check network
docker exec $(docker ps -q --filter "name=traefik") wget -qO- http://service-name:port
```

### Storage Issues
```bash
# Check space
df -h
docker system df

# Quick cleanup
docker system prune -a -f
```

### Registry Issues
```bash
# Check registry health
curl -u username:password https://registry.cryptotel.xyz/v2/_catalog

# Restart registry
docker service update enterprise-registry_registry
```

---

## 📋 Maintenance Schedule

### Daily
- Check `/opt/cryptotel/scripts/status.sh`
- Monitor disk usage

### Weekly
- Run `/opt/cryptotel/scripts/cleanup.sh`
- Update base images

### Monthly
- Review logs
- Update SSL certificates
- Backup configuration

---

## 🎯 Next Steps

1. **Add DNS records** for your subdomains
2. **Deploy your first project** using the example
3. **Set up GitHub Actions** for CI/CD
4. **Configure monitoring alerts**
5. **Set up automated backups**

---

## 📞 Support

- **Documentation**: `/opt/cryptotel/ENTERPRISE_GUIDE.md`
- **Scripts**: `/opt/cryptotel/scripts/`
- **Projects**: `/opt/cryptotel/projects/`
- **Status**: `/opt/cryptotel/scripts/status.sh`

---

*Your Enterprise Platform is ready for production! 🚀* 