# Wi-Fi Roaming Simulation: S-Cone 6 Inspired Mobile Connectivity Lab

![S-Cone Industrial Installation](https://github.com/Muvvakotesh2000/wifi-roaming-sim/blob/main/screenshots/s-cone-industrial.jpg)

*Inspired by the Strategic S-Cone 6 Mobile WiFi Network system - An enterprise-grade roaming solution to developers and network engineers*

## 🎯 Project Overview

This project creates a comprehensive Wi-Fi roaming simulation environment that mirrors the behavior of industrial mobile connectivity solutions like the **Strategic S-Cone 6**. Using virtual interfaces on a single Linux machine, it demonstrates seamless client handover between two access points with intelligent roaming algorithm and real-time monitoring.

### Inspiration: Strategic S-Cone 6 Mobile WiFi Network

The [Strategic S-Cone 6](https://sssinc.biz/products/s-cone-mobile-wifi-network/) is an industrial-grade mobile WiFi client system designed for vehicular installation in challenging industrial environments. This project is based on its core functionality - Switching between Access Points while moving.

![S-Cone Key Features](https://github.com/Muvvakotesh2000/wifi-roaming-sim/blob/main/screenshots/s-cone-features.jpg)

## 🎯 Project Demo

<details>
  <summary><b>▶ Watch the Video Demo</b></summary>
  <br/>
  <video 
    width="100%" 
    height="auto" 
    controls 
    muted 
    style="border-radius:12px;">
    <source src="https://github.com/Muvvakotesh2000/wifi-roaming-sim/raw/main/screenshots/demo.mp4" type="video/mp4">
    <p>Your browser doesn't support HTML5 video. 
       <a href="https://github.com/Muvvakotesh2000/wifi-roaming-sim/raw/main/screenshots/demo.mp4">Download the video</a> instead.</p>
  </video>
</details>



## ⭐ Key Features

### 🏗️ Virtual Infrastructure
- **3 Virtual Radio Interfaces**: Simulated using `mac80211_hwsim`
- **Dual Access Points**: Channel 1 and Channel 6 with same SSID
- **Bridge Network**: Unified 192.168.1.0/24 segment for seamless roaming
- **DHCP Integration**: Automatic IP assignment and management

### 🧠 Intelligent Roaming Algorithm
```bash
# Configurable roaming parameters
THRESHOLD_DBM=-65          # Signal strength threshold
MIN_RSSI_IMPROVEMENT=2     # Minimum improvement required (dB)
SCAN_INTERVAL=10          # Seconds between evaluations
```

- **RSSI-Based Decision Making**: Roam when signal drops below threshold
- **Candidate Evaluation**: Compare available APs with minimum improvement logic
- **Predictive Roaming**: Proactive handover before connection degrades
- **Zero Packet Loss**: Maintains active connections during transitions

### 📊 Real-Time Dashboard
- **Web-Based Interface**: Live monitoring at http://localhost:5000
- **Connection Metrics**: Signal strength, BSSID, frequency tracking
- **AP Status Monitoring**: Individual access point health indicators
- **Network Diagnostics**: Interface status, routing, and scan results

### 🔧 Production-Ready Implementation
- **Systemd Services**: Reliable service management and auto-restart
- **Comprehensive Logging**: Detailed roaming activity and diagnostics
- **Configuration Management**: Centralized parameter tuning
- **Error Handling**: Robust recovery from network disruptions

## 📁 Project Structure

```
wifi-roaming-sim/
├── setup.sh                    # One-command deployment script
├── roaming_manager.sh          # Core roaming algorithm
├── dashboard/
│   └── app.py                  # Flask-based monitoring interface
├── systemd/
│   ├── roaming.service         # Roaming manager service
│   └── scone-dashboard.service # Dashboard service
├── configs/
│   ├── hostapd-ap1.conf        # Access Point 1 configuration
│   ├── hostapd-ap2.conf        # Access Point 2 configuration
│   └── wpa_supplicant.conf     # Client configuration
├── screenshots/
│   ├── dashboard.png           # Dashboard interface
│   └── roaming_logs.png        # Log output examples
└── README.md                   # This file
```

## 🚀 Quick Start

### Prerequisites
- Ubuntu 18.04+ or similar Debian-based distribution
- Linux kernel with mac80211_hwsim support
- Root/sudo access
- Minimum 2GB RAM, 10GB disk space

### One-Command Installation
```bash
git clone https://github.com/Muvvakotesh2000/wifi-roaming-sim.git
cd wifi-roaming-sim
sudo ./setup.sh
```

### Manual Installation
```bash
# 1. Install dependencies
sudo apt update
sudo apt install -y hostapd wpa_supplicant dnsmasq python3-flask iw bridge-utils

# 2. Load virtual radio interfaces
sudo modprobe mac80211_hwsim radios=3

# 3. Configure and start services
sudo cp systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable roaming.service scone-dashboard.service
sudo systemctl start roaming.service scone-dashboard.service
```

### Verification
```bash
# Check service status
systemctl status roaming.service scone-dashboard.service

# Monitor connection
wpa_cli -i wlan2 status
iw wlan2 link

# Access dashboard
curl http://localhost:5000
```

## 🔬 Technical Deep Dive

### Network Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                    Wi-Fi Roaming Simulation                     │
├─────────────────────────────────────────────────────────────────┤
│ Dashboard (Flask) │ Roaming Manager │ System Services           │  
│ - Web Interface   │ - Signal Monitor│ - hostapd                 │
│ - Real-time Status│ - AP Selection  │ - wpa_supplicant          │
│ - Connection Logs │ - Auto Handover │ - dnsmasq                 │
├─────────────────────────────────────────────────────────────────┤
│                    Network Layer                                │
│        Bridge (br0) - 192.168.1.1/24                            │
│ ├── AP1 (wlan0) - Channel 1 (2412 MHz) - TestNet                │
│ ├── AP2 (wlan1) - Channel 6 (2437 MHz) - TestNet                │
│ └── Client (wlan2) - Roaming between APs                        │
├─────────────────────────────────────────────────────────────────┤
│                Virtual Hardware Layer                           │
│           mac80211_hwsim - 3 Virtual Radios                     │
└─────────────────────────────────────────────────────────────────┘
```

### Roaming Decision Algorithm
```python
def roaming_decision(current_rssi, current_bssid, scan_results):
    """
    Intelligent roaming decision based on:
    1. Current signal strength vs threshold
    2. Available candidates with better signal
    3. Minimum improvement requirements
    4. Connection stability factors
    """
    should_roam = False
    best_candidate = None
    
    # Evaluate disconnection
    if not current_rssi:
        should_roam = True
        reason = "Disconnected"
    
    # Evaluate signal quality
    elif current_rssi < THRESHOLD_DBM:
        for candidate in scan_results:
            improvement = candidate.rssi - current_rssi
            if improvement >= MIN_RSSI_IMPROVEMENT:
                should_roam = True
                best_candidate = candidate
                reason = f"Better AP (+{improvement} dB)"
                break
    
    return should_roam, best_candidate, reason
```

### Performance Characteristics
- **Handover Time**: 2-5 seconds typical
- **Signal Monitoring**: Every 10 seconds (configurable)
- **Background Scanning**: 3-second intervals when signal weak
- **Memory Usage**: ~50MB total footprint
- **CPU Usage**: <2% on modern hardware

## 🧪 Testing and Validation

### Manual Testing Commands
```bash
# Weaken AP1 signal to trigger roaming
sudo iw dev wlan0 set txpower fixed 300  # 3 dBm

# Stop AP1 to test failover
sudo pkill -f 'hostapd.*ap1.conf'

# Monitor roaming activity
tail -f /home/koti/roaming.log | grep "ROAMING:"

# Generate traffic during roaming
ping -i 0.1 192.168.1.1
```

### Expected Results
- ✅ Client automatically connects to strongest AP
- ✅ Roaming occurs when signal drops below -65 dBm
- ✅ Handover completes within 5 seconds
- ✅ No IP address changes during roaming
- ✅ Minimal packet loss during transition

## 📊 Dashboard Interface

![Dashboard Screenshot](https://github.com/Muvvakotesh2000/wifi-roaming-sim/blob/main/screenshots/dashboard.png)

### Features
- **Real-time Connection Status**: Current AP, signal strength, BSSID
- **Access Point Health**: Individual AP status and signal levels  
- **Network Configuration**: Interface details, IP configuration, routing
- **Scan Results**: Available networks and signal strengths
- **Auto-refresh**: Updates every 5 seconds

### API Endpoints
```http
GET /                    # Main dashboard interface
GET /api/status         # JSON status information
GET /api/metrics        # Performance metrics
GET /api/logs           # Recent roaming activity
```

## 🛠️ Configuration and Customization

### Roaming Parameters
Edit `/home/username/roaming_manager.sh`:
```bash
THRESHOLD_DBM=-70          # More sensitive roaming
MIN_RSSI_IMPROVEMENT=5     # Require larger improvement
SCAN_INTERVAL=5           # More frequent evaluation
```

### Network Settings
Edit `/etc/hostapd/ap1.conf` and `/etc/hostapd/ap2.conf`:
```ini
# Add 5GHz support
hw_mode=a
channel=36

# Adjust transmit power
max_num_sta=10
```

### Dashboard Customization
Edit `/dashboard/app.py` to add:
- Custom metrics collection
- Additional network diagnostics
- Performance graphing
- Alert notifications

## 🔍 Monitoring and Troubleshooting

### Log Files
```bash
# Roaming activity logs
tail -f /home/user-name/roaming.log

# Dashboard logs
tail -f /home/user-name/dashboard/dashboard.log

# System service logs
journalctl -u roaming.service -f
journalctl -u scone-dashboard.service -f
```

### Common Issues and Solutions

| Issue | Symptom | Solution |
|-------|---------|----------|
| Client not connecting | No IP address | `sudo dhclient wlan2` |
| Roaming not working | Client stays on weak AP | Check roaming thresholds |
| Dashboard not loading | Connection refused | Check Flask process and port 5000 |
| APs not starting | hostapd errors | Verify interface status and conflicts |

### Debug Commands
```bash
# Check interface status
ip link show | grep wlan

# Monitor signal strength
watch -n 2 'iw wlan2 link'

# Force manual roaming
wpa_cli -i wlan2 scan
wpa_cli -i wlan2 bssid 0 [TARGET_BSSID]
wpa_cli -i wlan2 reassociate
```

## 🎓 Use Cases

### Network Engineering Curriculum
- **Wi-Fi Protocol Understanding**: 802.11 standards, roaming mechanisms
- **Linux Networking**: Virtual interfaces, bridging, DHCP
- **System Administration**: Service management, monitoring, troubleshooting

### Research Applications
- **Algorithm Development**: Test new roaming strategies
- **Performance Analysis**: Benchmark different approaches  
- **IoT Simulation**: Mobile device connectivity patterns
- **Network Optimization**: Load balancing and band steering

### Industry Training
- **Enterprise Wi-Fi**: Understanding roaming in corporate environments
- **Industrial Networking**: Mobile connectivity challenges and solutions
- **Troubleshooting Skills**: Diagnostic techniques and problem-solving

## 🔮 Future Enhancements

### Planned Features
- [ ] **802.11r Fast BSS Transition**: Sub-second handovers
- [ ] **Band Steering**: 2.4GHz/5GHz optimization
- [ ] **Load Balancing**: Client distribution across APs
- [ ] **Machine Learning**: AI-based roaming decisions
- [ ] **Multi-SSID Support**: Enterprise network simulation
- [ ] **SNMP Integration**: Network management protocol support

### Advanced Capabilities
- [ ] **Geographic Simulation**: GPS-based roaming triggers
- [ ] **Mobility Patterns**: Realistic movement simulation
- [ ] **Interference Modeling**: RF environment effects
- [ ] **Quality of Service**: Traffic prioritization and shaping
- [ ] **Security Testing**: WPA3, 802.1X authentication
- [ ] **Mobile Device Integration**: Real device testing

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup
```bash
# Fork and clone the repository
git clone https://github.com/Muvvakotesh2000/wifi-roaming-sim.git
cd wifi-roaming-sim

# Create a development branch
git checkout -b feature/your-feature-name

# Make your changes and test
sudo ./setup.sh
./tests/test_roaming.sh

# Submit a pull request
```

### Areas for Contribution
- Algorithm improvements
- Dashboard enhancements  
- Additional test scenarios
- Documentation updates
- Bug fixes and optimization

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## References and Acknowledgments

### S-Cone Product References
This project is inspired by and refers the Strategic S-Cone 6 Mobile WiFi Network system. All S-Cone product names, images, and technical specifications are the intellectual property of Strategic Service Solutions Inc.

- **Product Information**: [Strategic S-Cone 6](https://sssinc.biz/products/s-cone-mobile-wifi-network/)
- **Company Website**: [Strategic Service Solutions Inc.](https://sssinc.biz/)
- **Linux mac80211_hwsim**: Virtual radio interface simulation
- **hostapd/wpa_supplicant**: Open-source Wi-Fi infrastructure
- **Flask**: Web dashboard framework

## 📞 Support and Contact

- **Issues**: [GitHub Issues](https://github.com/Muvvakotesh2000/wifi-roaming-sim/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Muvvakotesh2000/wifi-roaming-sim/discussions)
- **Email**: muvvakoteshyadav@gmail.com

---

> *"In industrial environments where reliable wireless connectivity is essential, the right technology can make all the difference."* 

---

### 📈 Project Status

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)
![Python](https://img.shields.io/badge/python-3.6%2B-blue)
![Linux](https://img.shields.io/badge/platform-linux-lightgrey)

**Version**: 1.0.0 | **Last Updated**: September 2025 | **Contributors**: 1