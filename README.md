# 🚀 Cryptotel - Multi-Project Management Platform

> **Open Source DevOps Platform** | Built with Docker Swarm, Traefik, and Modern DevOps Practices

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Swarm-blue.svg)](https://docs.docker.com/engine/swarm/)
[![Traefik](https://img.shields.io/badge/Traefik-Proxy-green.svg)](https://traefik.io/)
[![Monitoring](https://img.shields.io/badge/Monitoring-Grafana%2BPrometheus-orange.svg)](https://grafana.com/)

> *"Building the future of  DevOps infrastructure, one container at a time."*

This platform represents years of experience in DevOps engineering, container orchestration, and  infrastructure management. It's designed to showcase real-world DevOps skills and serve as a foundation for collaborative development.

## 🌟 What is Cryptotel ?

Cryptotel  is a comprehensive, production-ready DevOps platform that demonstrates advanced container orchestration, service mesh implementation, and -grade monitoring. Built with modern DevOps practices, it serves as both a learning resource and a practical foundation for  infrastructure.

### 🎯 Key Features

- **🐳 Docker Swarm Orchestration**: Multi-node container orchestration with high availability
- **🌐 Traefik Reverse Proxy**: Dynamic service discovery and SSL termination
- **📊 Monitoring Stack**: Grafana + Prometheus + AlertManager for comprehensive observability
- **🏗️ Private Registry**: Secure container image management
- **🔐  Security**: SSL/TLS, authentication, and access control
- **📈 Auto-scaling**: Built-in scaling capabilities for production workloads
- **🔄 CI/CD Ready**: GitHub Actions integration for automated deployments

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Cryptotel                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Traefik   │  │   Registry  │  │  Portainer  │         │
│  │   Proxy     │  │     UI      │  │     UI      │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Grafana   │  │ Prometheus  │  │AlertManager │         │
│  │  Dashboard  │  │   Metrics   │  │  Alerts     │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
├─────────────────────────────────────────────────────────────┤
│                    Docker Swarm Cluster                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Manager   │  │   Worker    │  │   Worker    │         │
│  │    Node     │  │    Node     │  │    Node     │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Swarm initialized
- Linux server (Ubuntu 20.04+ recommended)
- 4GB RAM minimum, 8GB recommended
- 50GB disk space

### Installation

```bash
# Clone the repository
git clone https://github.com/amirhosein-tahmasbzadeh/cryptotel-.git
cd cryptotel-

# Make scripts executable
chmod +x setup-infrastructure.sh
chmod +x setup-advanced-infrastructure.sh
chmod +x setup-private-registry.sh

# Run the setup
./setup-infrastructure.sh
```

### Access Points

After installation, access your services at:

- **Traefik Dashboard**: https://traefik.cryptotel.xyz
- **Grafana Monitoring**: https://grafana.cryptotel.xyz
- **Portainer Management**: https://portainer.cryptotel.xyz
- **Registry UI**: https://registry-ui.cryptotel.xyz

## 📁 Project Structure

```
cryptotel-/
├── 📄 README.md                    # This file
├── 📄 LICENSE                      # MIT License
├── 📄 .gitignore                   # Git ignore rules
├── 📄 _GUIDE.md          # Comprehensive guide
├── 📄 QUICK_START.md               # Quick start guide
├── 🐳 setup-infrastructure.sh      # Main setup script
├── 🐳 setup-advanced-infrastructure.sh  # Advanced features
├── 🐳 setup-private-registry.sh    # Registry setup
├── 📁 /                  #  configurations
├── 📁 monitoring/                  # Monitoring stack
│   ├── grafana/
│   ├── prometheus/
│   └── alertmanager/
├── 📁 registry/                    # Private registry
├── 📁 traefik/                     # Reverse proxy
├── 📁 portainer/                   # Container management
├── 📁 projects/                    # Multi-project support
├── 📁 scripts/                     # Utility scripts
├── 📁 backups/                     # Backup configurations
└── 📁 logs/                        # Log management
```

## 🔧 Configuration

### Environment Variables

Create a `.env` file in the root directory:

```bash
# Domain configuration
DOMAIN=cryptotel.xyz
REGISTRY_DOMAIN=registry.cryptotel.xyz

# Authentication
GRAFANA_ADMIN_PASSWORD=your-secure-password
PORTAINER_ADMIN_PASSWORD=your-secure-password

# SSL Configuration
SSL_EMAIL=admin@cryptotel.xyz
SSL_PROVIDER=selfsigned  # or letsencrypt
```

### Multi-Project Management

Add new projects to the `projects/` directory:

```yaml
# projects/my-app/docker-compose.yml
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

networks:
  traefik:
    external: true
```

## 📊 Monitoring & Observability

### Grafana Dashboards

- **System Overview**: CPU, Memory, Disk, Network metrics
- **Docker Swarm**: Service health, replicas, resource usage
- **Application Metrics**: Response times, error rates, throughput

### Alerting Rules

Pre-configured alerts for:
- Service downtime
- High resource usage
- SSL certificate expiration
- Container health issues

## 🔒 Security Features

- **SSL/TLS Termination**: Automatic certificate management
- **Authentication**: Basic auth for sensitive endpoints
- **Network Isolation**: Docker networks for service separation
- **Secret Management**: Docker secrets for sensitive data
- **Access Control**: Role-based access in Portainer

## 🚀 CI/CD Integration

### GitHub Actions Workflow

```yaml
name: Deploy to Cryptotel 
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build and Deploy
        run: |
          docker build -t registry.cryptotel.xyz/${{ github.repository }}:latest .
          docker push registry.cryptotel.xyz/${{ github.repository }}:latest
          ssh user@server "cd /opt/cryptotel/projects/${{ github.event.repository.name }} && docker stack deploy -c docker-compose.yml ${{ github.event.repository.name }}"
```

## 🤝 Contributing

We welcome contributions! This is an open-source project designed to showcase DevOps engineering skills and foster collaboration.

### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Docker best practices
- Include comprehensive documentation
- Add monitoring and alerting for new services
- Test thoroughly before submitting PRs

## 📚 Documentation

- **[ Guide](_GUIDE.md)**: Comprehensive platform documentation
- **[Quick Start](QUICK_START.md)**: Get up and running quickly
- **[API Documentation](docs/api.md)**: Service API references
- **[Troubleshooting](docs/troubleshooting.md)**: Common issues and solutions

## 🏆 DevOps Skills Demonstrated

This project showcases proficiency in:

- **Container Orchestration**: Docker Swarm, service discovery
- **Reverse Proxy**: Traefik configuration and SSL management
- **Monitoring**: Prometheus, Grafana, AlertManager
- **CI/CD**: GitHub Actions, automated deployments
- **Infrastructure as Code**: Docker Compose, shell scripting
- **Security**: SSL/TLS, authentication, secrets management
- **High Availability**: Multi-node clustering, failover
- **Observability**: Metrics, logging, alerting
- **Multi-Project Management**: Scalable architecture

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Docker team for the amazing container platform
- Traefik team for the powerful reverse proxy
- Grafana and Prometheus communities
- All contributors and collaborators

## 📞 Contact

**Amir Tahmasb**
- GitHub: [@amirhosein-tahmasbzadeh](https://github.com/amirhosein-tahmasbzadeh)
- Email: [contact@cryptotel.xyz](mailto:amirh.tahmasb@gmail.com)
- Website: [cryptotel.xyz](https://cryptotel.xyz)

---

**⭐ Star this repository if you find it helpful!**

**🔄 Stay updated with the latest DevOps practices and  infrastructure patterns.** 
