#!/bin/bash
# Wi-Fi Roaming Simulation - Complete Setup & Dashboard

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
print_status(){ echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning(){ echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error(){ echo -e "${RED}[ERROR]${NC} $1"; }
print_header(){ echo -e "${BLUE}========================================${NC}"; echo -e "${BLUE}$1${NC}"; echo -e "${BLUE}========================================${NC}"; }

# Root check
if [ "$EUID" -ne 0 ]; then print_error "This script needs sudo privileges. Run with sudo or as root."; exit 1; fi

print_header "Wi-Fi Roaming Simulation - Complete Setup & Dashboard"
echo "Setting up complete Wi-Fi roaming simulation with dashboard"; echo ""

# Phase 1: Clean Environment
print_header "Phase 1: Environment Cleanup"
print_status "Stopping existing services and processes..."
systemctl stop roaming.service 2>/dev/null || true
systemctl stop failover.service 2>/dev/null || true
systemctl stop scone-dashboard.service 2>/dev/null || true
pkill -f hostapd || true; pkill -f wpa_supplicant || true; pkill -f dnsmasq || true
pkill -f dhclient || true; pkill -f roaming_manager || true; pkill -f failover || true
pkill -f "python.*app.py" || true

print_status "Removing existing virtual interfaces..."
ip link set wlan0 down 2>/dev/null || true
ip link set wlan1 down 2>/dev/null || true
ip link set wlan2 down 2>/dev/null || true
ip link set br0 down 2>/dev/null || true
ip link delete br0 2>/dev/null || true
modprobe -r mac80211_hwsim 2>/dev/null || true

# Phase 2: Packages
print_header "Phase 2: Installing Required Packages"
print_status "Updating package repositories..."
apt update -qq
print_status "Installing networking packages..."
apt install -y -qq net-tools wireless-tools wpasupplicant hostapd dnsmasq iproute2 iptables bridge-utils iptables-persistent netfilter-persistent python3 python3-pip curl
print_status "Installing Python packages..."
pip3 install flask > /dev/null 2>&1

# Phase 3: Virtual Interfaces
print_header "Phase 3: Creating Virtual Wi-Fi Interfaces"
print_status "Loading mac80211_hwsim module with 3 radios..."
modprobe mac80211_hwsim radios=3; sleep 2

print_status "Creating bridge interface..."
ip link add name br0 type bridge; ip link set br0 up

print_status "Bringing interfaces up..."
ip link set wlan0 up; ip link set wlan1 up; ip link set wlan2 up; sleep 2

print_status "Adding APs to bridge..."
ip link set wlan0 master br0; ip link set wlan1 master br0
print_status "Configuring IP address for bridge..."
ip addr add 192.168.1.1/24 dev br0

# Phase 4: Access Points
print_header "Phase 4: Configuring Access Points"
mkdir -p /etc/hostapd
install -m 644 ./configs/hostapd-ap1.conf /etc/hostapd/ap1.conf
install -m 644 ./configs/hostapd-ap2.conf /etc/hostapd/ap2.conf

# Phase 5: DHCP
print_header "Phase 5: Configuring DHCP Services"
cat > /etc/dnsmasq.conf << 'EOF'
interface=br0
bind-interfaces
dhcp-range=192.168.1.10,192.168.1.100,255.255.255.0,12h
dhcp-option=3,192.168.1.1
dhcp-option=6,8.8.8.8
port=0
EOF

# Phase 6: Client
print_header "Phase 6: Configuring Wi-Fi Client"
mkdir -p /etc/wpa_supplicant
install -m 600 ./configs/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf

# Phase 7: Management Scripts
print_header "Phase 7: Creating Management Scripts"
install -m 755 ./roaming_manager.sh /home/koti/roaming_manager.sh

# Phase 8: Dashboard
print_header "Phase 8: Creating Web Dashboard"
mkdir -p /home/koti/dashboard
install -m 644 ./dashboard/app.py /home/koti/dashboard/app.py

# Phase 9: Systemd
print_header "Phase 9: Creating System Services"
install -m 644 ./systemd/roaming.service /etc/systemd/system/roaming.service
install -m 644 ./systemd/scone-dashboard.service /etc/systemd/system/scone-dashboard.service
systemctl daemon-reload

# Phase 10: Start All
print_header "Phase 10: Starting All Services"
print_status "Stopping default dnsmasq service..."
systemctl stop dnsmasq 2>/dev/null || true; systemctl disable dnsmasq 2>/dev/null || true

print_status "Starting access points..."
hostapd -B /etc/hostapd/ap1.conf
hostapd -B /etc/hostapd/ap2.conf
sleep 3

print_status "Starting DHCP server..."
pkill dnsmasq || true; sleep 1
dnsmasq -C /etc/dnsmasq.conf --pid-file=/var/run/dnsmasq.pid & sleep 3

print_status "Starting Wi-Fi client..."
wpa_supplicant -B -i wlan2 -c /etc/wpa_supplicant/wpa_supplicant.conf; sleep 3

print_status "Scanning for networks..."
wpa_cli -i wlan2 scan > /dev/null; sleep 3
print_status "Available networks:"; wpa_cli -i wlan2 scan_results

print_status "Connecting to TestNet..."; sleep 5
print_status "Getting IP address..."
timeout 30 dhclient -v wlan2 & DHCP_PID=$!; sleep 15
if kill -0 $DHCP_PID 2>/dev/null; then kill $DHCP_PID 2>/dev/null || true; fi

if ! ip addr show wlan2 | grep -q "inet.*192.168"; then
  print_warning "No IP assigned, retrying connection..."
  wpa_cli -i wlan2 reassociate > /dev/null; sleep 5
  timeout 20 dhclient -v wlan2 || true
fi

# Phase 11: Enable Services
print_header "Phase 11: Enabling System Services"
systemctl enable roaming.service
systemctl enable scone-dashboard.service
print_status "Starting services..."
systemctl start roaming.service
systemctl start scone-dashboard.service

# Phase 12: Dashboard Startup
print_header "Phase 12: Starting Dashboard"
print_status "Stopping any existing dashboard processes..."; pkill -f "python.*app.py" || true; sleep 2
print_status "Starting dashboard on port 5000..."
cd /home/koti/dashboard
nohup python3 app.py > dashboard.log 2>&1 & DASHBOARD_PID=$!; sleep 5

# Phase 13: Final Status
print_header "Phase 13: Final Status Check"
print_status "Interface Status:"
echo "  br0: $(ip addr show br0 | grep 'inet ' | awk '{print $2}' || echo 'No IP')"
echo "  wlan2: $(ip addr show wlan2 | grep 'inet ' | awk '{print $2}' || echo 'No IP')"

print_status "Process Status:"
echo "  hostapd: $(ps aux | grep hostapd | grep -v grep | wc -l) processes"
echo "  dnsmasq: $(ps aux | grep dnsmasq | grep -v grep | wc -l) processes"
echo "  wpa_supplicant: $(ps aux | grep wpa_supplicant | grep -v grep | wc -l) processes"

print_status "Wi-Fi Client Status:"; wpa_cli -i wlan2 status || echo "wpa_cli failed"

print_status "Auto-fixing common issues..."
if ! ip addr show br0 | grep -q "192.168.1.1"; then
  ip addr flush dev br0 2>/dev/null || true
  ip addr add 192.168.1.1/24 dev br0; ip link set br0 up
fi
if ! ps aux | grep dnsmasq | grep -v grep > /dev/null; then
  print_warning "Restarting DHCP server..."; dnsmasq -C /etc/dnsmasq.conf --pid-file=/var/run/dnsmasq.pid & sleep 2
fi
if ! ip addr show wlan2 | grep -q "inet.*192.168"; then
  print_warning "Client has no IP, forcing reconnection..."
  pkill dhclient || true; pkill wpa_supplicant || true; sleep 2
  wpa_supplicant -B -i wlan2 -c /etc/wpa_supplicant/wpa_supplicant.conf; sleep 3
  wpa_cli -i wlan2 scan > /dev/null; sleep 8
  dhclient wlan2 & sleep 10
fi

if kill -0 $DASHBOARD_PID 2>/dev/null; then
  print_status "✅ Dashboard is running (PID: $DASHBOARD_PID)"
else
  print_warning "Dashboard may have failed, restarting..."
  cd /home/koti/dashboard; nohup python3 app.py > dashboard.log 2>&1 & sleep 3
fi

# Summary
print_header "🎉 Setup Complete!"
SERVER_IP=$(hostname -I | awk '{print $1}')
echo ""
echo -e "${GREEN}✅ Wi-Fi Roaming Simulation is now running!${NC}"
echo ""
echo -e "${GREEN}📊 Dashboard URL: http://$SERVER_IP:5000${NC}"
echo ""
echo "📡 Access Points:"
echo "   • TestNet (wlan0) - Channel 1"
echo "   • TestNet (wlan1) - Channel 6"
echo ""
echo "🔄 Roaming Client: wlan2 (Network: 192.168.1.0/24)"
echo ""
echo "📋 Useful Commands:"
echo "   • Check connection: wpa_cli -i wlan2 status"
echo "   • Check signal: iw wlan2 link"
echo "   • View logs: tail -f /home/koti/roaming.log"
echo "   • Dashboard log: tail -f /home/koti/dashboard/dashboard.log"
echo ""
echo "🧪 Test Roaming:"
echo "   • Weaken AP1: iw dev wlan0 set txpower fixed 300   # 300 mBm = 3 dBm"
echo "   • Weaken AP2: iw dev wlan1 set txpower fixed 300"
echo "   • Stop AP1: pkill -f 'hostapd.*ap1.conf'"
echo ""
print_status "Testing dashboard..."
sleep 3
if curl -s -m 5 http://localhost:5000 >/dev/null; then
  echo -e "${GREEN}✅ Dashboard is responding at http://$SERVER_IP:5000${NC}"
else
  echo -e "${YELLOW}⚠️ Dashboard may need more time to start${NC}"
  echo "   Try: tail -f /home/koti/dashboard/dashboard.log"
fi
echo ""; echo -e "${BLUE}🌐 Happy roaming!${NC}"
