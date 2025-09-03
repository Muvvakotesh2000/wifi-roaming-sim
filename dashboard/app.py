from flask import Flask, render_template_string
import subprocess, time

app = Flask(__name__)

def sh(cmd):
    try:
        return subprocess.getoutput(cmd)
    except Exception:
        return "Error executing command"

def get_signal_strength():
    link_info = sh("iw wlan2 link")
    for line in link_info.split('\n'):
        if 'signal:' in line:
            return line.split('signal:')[1].strip()
    return "Not connected"

def get_connected_ap_info():
    link_info = sh("iw wlan2 link")
    current_bssid = ""
    current_freq = ""
    for line in link_info.split('\n'):
        if 'Connected to' in line:
            current_bssid = line.split('Connected to')[1].split()[0]
        elif 'freq:' in line:
            current_freq = line.split('freq:')[1].strip().split()[0] + " MHz"
    if not current_bssid:
        return "Not connected", "", ""

    ap1_bssid = ""
    ap2_bssid = ""
    ap1_info = sh("iw dev wlan0 info")
    for line in ap1_info.split('\n'):
        if 'addr' in line:
            ap1_bssid = line.split('addr')[1].strip(); break
    ap2_info = sh("iw dev wlan1 info")
    for line in ap2_info.split('\n'):
        if 'addr' in line:
            ap2_bssid = line.split('addr')[1].strip(); break

    connected_ap = "Unknown AP"
    if current_bssid == ap1_bssid: connected_ap = "AP1 (wlan0)"
    elif current_bssid == ap2_bssid: connected_ap = "AP2 (wlan1)"
    else:
        if "2412" in current_freq or "2417" in current_freq:
            connected_ap = "AP1 (wlan0) - Channel 1"
        elif "2437" in current_freq or "2442" in current_freq:
            connected_ap = "AP2 (wlan1) - Channel 6"
    return connected_ap, current_bssid, current_freq

def get_ap_status():
    ap1_info = sh("iw dev wlan0 info"); ap1_running = "UP" in ap1_info and "AP" in ap1_info
    ap2_info = sh("iw dev wlan1 info"); ap2_running = "UP" in ap2_info and "AP" in ap2_info
    hostapd_processes = sh("ps aux | grep hostapd | grep -v grep")
    ap1_hostapd = "ap1.conf" in hostapd_processes
    ap2_hostapd = "ap2.conf" in hostapd_processes
    return {
        'ap1': {'interface_up': ap1_running, 'hostapd_running': ap1_hostapd, 'info': ap1_info},
        'ap2': {'interface_up': ap2_running, 'hostapd_running': ap2_hostapd, 'info': ap2_info}
    }

@app.route("/")
def index():
    link = sh("iw wlan2 link")
    route = sh("ip route | head -5")
    ip_info = sh("ip -4 addr show wlan2 | grep 'inet ' || echo 'No IP assigned'")
    status = sh("wpa_cli -i wlan2 status")
    signal = get_signal_strength()
    connected_ap, current_bssid, current_freq = get_connected_ap_info()

    current_ssid = "Not connected"
    for line in status.split('\n'):
        if line.startswith('ssid='):
            current_ssid = line.split('=')[1]; break

    interface_info = sh("ip link show | grep wlan")
    ap_status = get_ap_status()
    scan_results = sh("wpa_cli -i wlan2 scan_results | tail -n +2")

    ap_signals = {"AP1": "N/A", "AP2": "N/A"}
    for line in scan_results.split('\n'):
        if 'TestNet' in line:
            parts = line.split('\t')
            if len(parts) >= 5:
                bssid, freq, signal_dbm = parts[0], parts[1], parts[2]
                if freq.startswith('2412') or freq.startswith('2417'):
                    ap_signals["AP1"] = f"{signal_dbm} dBm"
                elif freq.startswith('2437') or freq.startswith('2442'):
                    ap_signals["AP2"] = f"{signal_dbm} dBm"

    template = '''
    <!DOCTYPE html>
    <html><head>
        <title>Wi-Fi Roaming Dashboard</title>
        <meta http-equiv="refresh" content="5">
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
            .container { max-width: 1200px; margin: 0 auto; }
            .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
            .status-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
            .status-box { background: white; padding: 15px; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
            .status-box h3 { margin-top: 0; color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
            pre { background: #ecf0f1; padding: 10px; border-radius: 3px; overflow-x: auto; font-size: 12px; }
            .connected { color: #27ae60; font-weight: bold; }
            .disconnected { color: #e74c3c; font-weight: bold; }
            .warning { color: #f39c12; font-weight: bold; }
            .ap-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-bottom: 15px; }
            .ap-box { background: #ecf0f1; padding: 10px; border-radius: 5px; border-left: 4px solid #3498db; }
            .ap-active { border-left-color: #27ae60; background: #d5f4e6; }
            .ap-inactive { border-left-color: #e74c3c; background: #fdf2f2; }
            .current-connection { background: #e8f5e8; border: 2px solid #27ae60; padding: 15px; border-radius: 5px; margin-bottom: 15px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🌐 Wi-Fi Roaming Simulation Dashboard</h1>
                <p>Real-time monitoring of roaming system</p>
                <p>Time: {{ time }}</p>
            </div>

            <div class="status-grid">
                <div class="status-box">
                    <h3>📡 Current Connection</h3>
                    <div class="current-connection">
                        <p><strong>🎯 Connected to:</strong>
                            <span class="{{ 'connected' if connected_ap != 'Not connected' else 'disconnected' }}">{{ connected_ap }}</span>
                        </p>
                        <p><strong>📶 Signal:</strong> <span class="warning">{{ signal }}</span></p>
                        <p><strong>🔗 BSSID:</strong> {{ current_bssid or 'N/A' }}</p>
                        <p><strong>📻 Frequency:</strong> {{ current_freq or 'N/A' }}</p>
                        <p><strong>🌐 SSID:</strong>
                            <span class="{{ 'connected' if current_ssid not in ['Not connected', ''] else 'disconnected' }}">{{ current_ssid if current_ssid else 'Not connected' }}</span>
                        </p>
                    </div>
                </div>

                <div class="status-box">
                    <h3>🏢 Access Points Status</h3>
                    <div class="ap-grid">
                        <div class="ap-box {{ 'ap-active' if ap_status.ap1.interface_up and ap_status.ap1.hostapd_running else 'ap-inactive' }}">
                            <h4>AP1 (wlan0) - Channel 1</h4>
                            <p><strong>Signal:</strong> {{ ap_signals.AP1 }}</p>
                        </div>
                        <div class="ap-box {{ 'ap-active' if ap_status.ap2.interface_up and ap_status.ap2.hostapd_running else 'ap-inactive' }}">
                            <h4>AP2 (wlan1) - Channel 6</h4>
                            <p><strong>Signal:</strong> {{ ap_signals.AP2 }}</p>
                        </div>
                    </div>
                </div>

                <div class="status-box">
                    <h3>📋 WPA Supplicant Status</h3>
                    <pre>{{ status }}</pre>
                </div>

                <div class="status-box">
                    <h3>🔗 Interface Details</h3>
                    <pre>{{ interface_info }}</pre>
                    <h4>Link Information:</h4>
                    <pre>{{ link }}</pre>
                </div>

                <div class="status-box">
                    <h3>🌍 IP Configuration</h3>
                    <pre>{{ ip_info }}</pre>
                </div>

                <div class="status-box">
                    <h3>🛣️ Routing Table</h3>
                    <pre>{{ route }}</pre>
                </div>

                <div class="status-box">
                    <h3>📡 Available Networks</h3>
                    <pre>{{ scan_results }}</pre>
                </div>
            </div>

            <div style="text-align: center; margin-top: 20px; color: #7f8c8d;">
                <p>Auto-refresh every 5 seconds | Dashboard running on port 5000</p>
                <p>🧪 Test roaming by stopping/starting APs or adjusting signal strength</p>
            </div>
        </div>
    </body></html>
    '''
    return render_template_string(
        template,
        link=link, route=route, ip_info=ip_info, status=status, signal=signal,
        current_ssid=current_ssid, connected_ap=connected_ap, current_bssid=current_bssid,
        current_freq=current_freq, time=time.strftime("%Y-%m-%d %H:%M:%S"),
        interface_info=interface_info, ap_status=ap_status, ap_signals=ap_signals,
        scan_results=scan_results
    )

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
