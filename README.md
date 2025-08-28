# Proxmox Homelab Automation

A simple, shell-based automation system for deploying containerized services in LXC containers on Proxmox VE.

## 🎯 Design Philosophy

- **Idempotent & Fail-Fast**: Operations are safely re-runnable; failures stop immediately
- **Keep It Simple**: Direct approach over complex abstractions
- **Static Configuration**: Hardcoded values preferred over dynamic discovery
- **Latest Everything**: Always use newest versions (Debian, Alpine, Docker images)
- **Minimal Dependencies**: Bash built-ins and basic system tools only

## 🏗️ Architecture

Each service runs in its own LXC container with dedicated resources:

| Stack | ID | Purpose | Resources |
|-------|----|---------|---------  |
| **proxy** | 100 | Reverse proxy, monitoring agents | 2C/2GB/10GB |
| **media** | 101 | Media server (Jellyfin, Sonarr, Radarr) | 6C/10GB/20GB |
| **files** | 102 | File management services | 2C/3GB/15GB |
| **webtools** | 103 | Web-based utilities | 2C/6GB/15GB |
| **monitoring** | 104 | Prometheus, Grafana stack | 4C/6GB/15GB |
| **gameservers** | 105 | Game servers (Satisfactory, Palworld) | 8C/16GB/50GB |
| **backup** | 150 | Proxmox Backup Server | 4C/8GB/50GB |
| **development** | 151 | Development tools | 4C/6GB/15GB |

## 🚀 Quick Start

1. **Run on Proxmox host:**
   ```bash
   bash <(curl -s https://raw.githubusercontent.com/Yakrel/proxmox-homelab-automation/main/installer.sh)
   ```

2. **Select stack from menu**
3. **Wait for deployment**

## 📁 Project Structure

```
├── installer.sh           # Main entry point (downloads latest scripts)
├── scripts/               # Core deployment scripts
│   ├── main-menu.sh      # Interactive menu
│   ├── deploy-stack.sh   # Stack deployment orchestrator
│   └── lxc-manager.sh    # LXC container management
├── docker/               # Docker compose files per stack
│   ├── proxy/
│   ├── media/
│   └── ...
├── stacks.yaml          # Central configuration
└── config/              # Service configurations
```

## 🔧 Requirements

- **Proxmox VE 8.x**
- **ZFS pool named `datapool`**
- **Network bridge `vmbr0`**
- **IP range `192.168.1.x`**

## 📋 Stack Details

### Proxy Stack (LXC 100)
- Cloudflared tunnel
- Promtail log shipping
- Watchtower for updates

### Media Stack (LXC 101)
- Jellyfin media server
- Sonarr/Radarr for automation
- Transmission torrent client

### Files Stack (LXC 102)
- Filebrowser web interface
- Nextcloud personal cloud
- Samba file sharing

### Web Tools Stack (LXC 103)
- Homepage dashboard
- Portainer container management
- Various web utilities

### Monitoring Stack (LXC 104)
- Prometheus metrics collection
- Grafana visualization
- Alertmanager notifications

### Game Servers Stack (LXC 105)
- Satisfactory dedicated server
- Palworld server
- Extensible for more games

### Backup Stack (LXC 150)
- Proxmox Backup Server
- Automated backup schedules
- Data verification

## 🛡️ Security

- **Unprivileged LXC containers** for security isolation
- **Feature flags** (nesting, keyctl) set post-creation
- **Network isolation** with dedicated VLANs
- **Regular security updates** via automated processes

## 📝 Configuration

All configuration is centralized in `stacks.yaml`:

```yaml
network:
  gateway: 192.168.1.1
  bridge: vmbr0
  ip_base: 192.168.1

storage:
  pool: datapool

stacks:
  proxy:
    ct_id: 100
    hostname: lxc-proxy-01
    ip_octet: 100
    cpu_cores: 2
    memory_mb: 2048
    disk_gb: 10
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test on a Proxmox environment
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Troubleshooting

### Container Creation Fails
- Ensure ZFS pool `datapool` exists
- Check network bridge `vmbr0` is configured
- Verify IP range doesn't conflict

### Docker Services Don't Start
- Check LXC features: `pct config <id>`
- Verify keyctl=1 and nesting=1 are set
- Check container logs: `pct exec <id> -- docker logs <service>`

### Network Issues
- Verify gateway and bridge configuration
- Check firewall rules on Proxmox host
- Ensure IP addresses don't conflict

---

**Made for homelabs, by homelabbers** 🏠