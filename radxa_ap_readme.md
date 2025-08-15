# Radxa Rock5B+ Access Point Setup Script

A comprehensive bash script to configure your Radxa Rock5B+ as a WiFi Access Point with automatic client subnet assignment and internet sharing.

## 🚀 Features

- **Automatic WiFi interface detection** (handles non-standard names like `wlP2p33s0`)
- **RTL8852BE chipset optimizations** with IEEE 802.11n support
- **Interactive configuration** for SSID, password, and IP settings  
- **Automatic client disconnection** from existing WiFi networks
- **NAT configuration** for internet sharing
- **DHCP server** with proper subnet assignment (fixes common subnet issues)
- **Comprehensive error handling** and logging
- **Configuration backup** before making changes
- **Service verification** and troubleshooting guide
- **Speed test server setup** with iperf3

## 📋 System Requirements

- **Hardware**: Radxa Rock5B+ with WiFi module
- **WiFi Chipset**: Realtek RTL8852BE (standard on Rock5B+)
- **OS**: Debian-based Linux (tested on Radxa's official Debian image)
- **Privileges**: Root access required
- **Network**: Ethernet connection for internet sharing

## 🔧 Supported Hardware

| Device | WiFi Module | Chipset | Status |
|--------|-------------|---------|---------|
| Radxa Rock5B+ | Wireless Module A8 | RTL8852BE | ✅ Fully Supported |
| Rock5B+ variants | Built-in WiFi | RTL8852BE | ✅ Supported |

## 📥 Quick Install & Run

### Method 1: Direct Download (Recommended)
```bash
# Download the script
wget https://raw.githubusercontent.com/YOUR_USERNAME/radxa-rock5b-ap-setup/main/radxa_ap_setup.sh

# Make executable
chmod +x radxa_ap_setup.sh

# Run with root privileges
sudo ./radxa_ap_setup.sh
```

### Method 2: Manual Creation
```bash
# SSH into your Radxa Rock5B+
ssh radxa@<RADXA_IP>

# Create the script file
nano radxa_ap_setup.sh

# Copy-paste the script content, save and exit
# Make executable and run
chmod +x radxa_ap_setup.sh
sudo ./radxa_ap_setup.sh
```

## ⚙️ Configuration Options

The script will interactively prompt for:

| Setting | Default Value | Description |
|---------|---------------|-------------|
| SSID | `RadxaAP` | WiFi network name |
| Password | `radxa123456` | WPA2 password (min 8 chars) |
| AP IP | `192.168.4.1` | Access Point IP address |
| DHCP Range | `192.168.4.2-20` | Client IP assignment range |
| Channel | `7` | WiFi channel (can be 1,6,11) |
| Country | `PK` | Regulatory domain |

## 🛠️ What the Script Does

### 1. **Pre-Setup Checks**
- Verifies root privileges
- Detects WiFi interface automatically
- Installs required packages (`hostapd`, `dnsmasq`, `iptables-persistent`)
- Backs up existing configurations

### 2. **Network Preparation**
- Disconnects from existing WiFi networks
- Stops conflicting services (NetworkManager, wpa_supplicant)
- Configures static IP for AP interface

### 3. **Access Point Configuration**
- **hostapd**: Creates WiFi AP with WPA2 security
- **dnsmasq**: DHCP server for automatic client IP assignment
- **iptables**: NAT rules for internet sharing

### 4. **Service Management**
- Enables and starts required services
- Verifies proper operation
- Provides troubleshooting information

## 📊 Speed Testing

The script automatically sets up an iperf3 server for performance testing:

```bash
# On Rock5B+ (server - automatic)
iperf3 -s

# On client device
iperf3 -c 192.168.4.1
```

## 🐛 Common Issues & Solutions

### Issue: Clients Can't Connect
**Symptoms**: Devices see the network but can't authenticate
```bash
# Check hostapd status and logs
sudo systemctl status hostapd
sudo journalctl -u hostapd -f

# Solutions:
# 1. Verify password (minimum 8 characters)
# 2. Try different channel (1, 6, or 11)
# 3. Check country code settings
```

### Issue: No Internet Access for Clients
**Symptoms**: Connected but no internet browsing
```bash
# Check IP forwarding
cat /proc/sys/net/ipv4/ip_forward  # Should return 1

# Check NAT rules
sudo iptables -t nat -L

# Check default route
ip route show default

# Solution: Restart the script or manually enable forwarding
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
```

### Issue: Wrong Subnet Assignment
**Symptoms**: Clients get IPs outside 192.168.4.x range
```bash
# Check dnsmasq configuration
sudo systemctl status dnsmasq
cat /etc/dnsmasq.conf | grep dhcp-range

# Check DHCP leases
cat /var/lib/dhcp/dhcpd.leases

# Solution: Restart dnsmasq
sudo systemctl restart dnsmasq
```

### Issue: Interface Detection Problems
**Symptoms**: "No WiFi interface found" error
```bash
# List all network interfaces
ls /sys/class/net/

# Check WiFi interfaces specifically
iwconfig 2>/dev/null | grep -E "^wl|^wlan"

# Manual fix: Edit script and set INTERFACE variable
# INTERFACE="your_wifi_interface_name"
```

## 📝 Log Files & Debugging

```bash
# Script log
tail -f /tmp/radxa_ap_setup.log

# Service logs
sudo journalctl -u hostapd -f    # hostapd logs
sudo journalctl -u dnsmasq -f    # dnsmasq logs

# System logs
dmesg | grep -i rtw89           # WiFi driver logs
```

## 🔄 Manual Service Management

```bash
# Restart services
sudo systemctl restart hostapd
sudo systemctl restart dnsmasq

# Stop AP mode
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq

# Check service status
sudo systemctl status hostapd dnsmasq
```

## 🧪 Testing Your Setup

### 1. **Basic Connectivity Test**
- Look for your SSID in available WiFi networks
- Connect with your password
- Check if you receive IP in 192.168.4.x range

### 2. **Speed Test**
```bash
# Install iperf3 on client
sudo apt install iperf3  # Linux
# brew install iperf3    # macOS

# Run speed test
iperf3 -c 192.168.4.1 -t 60
```

### 3. **Multiple Clients Test**
- Connect several devices simultaneously
- Check DHCP lease assignments:
```bash
cat /var/lib/dhcp/dhcpd.leases
```

## ⚡ Performance Optimization

### For Better Range & Stability
```bash
# Edit hostapd.conf for 5GHz (if supported)
sudo nano /etc/hostapd/hostapd.conf

# Change:
hw_mode=a        # Use 5GHz band
channel=36       # 5GHz channel
```

### For Maximum Compatibility
```bash
# Use 2.4GHz with best compatibility settings
hw_mode=g
channel=6        # Less congested channel
ieee80211n=0    # Disable N mode if issues
```

## 📚 Technical Details

### RTL8852BE Chipset Specifics
- **WiFi Standards**: 802.11a/b/g/n/ac/ax (WiFi 6)
- **Frequency Bands**: 2.4GHz and 5GHz
- **Driver**: `rtw89_8852be` (uses nl80211 interface)
- **AP Mode**: Supported with proper configuration

### Network Architecture
```
Internet → Ethernet (enP4p65s0) → Radxa Rock5B+ → WiFi AP (wlP2p33s0) → Clients
         └─ NAT/Masquerade ─┘                   └─ DHCP: 192.168.4.2-20 ─┘
```

## 🔒 Security Considerations

- **WPA2-PSK**: Industry standard encryption
- **Strong Password**: Minimum 8 characters recommended
- **Firewall**: iptables rules configured for security
- **Access Control**: Optional MAC address filtering available

## 🤝 Contributing

Found a bug or want to improve the script? Contributions welcome!

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🆘 Support

### Getting Help
- **GitHub Issues**: [Report bugs or request features](https://github.com/YOUR_USERNAME/radxa-rock5b-ap-setup/issues)
- **Radxa Community**: [Official Radxa Forum](https://forum.radxa.com/)
- **Documentation**: [Radxa Rock5B+ Official Docs](https://docs.radxa.com/en/rock5/rock5b)

### Before Reporting Issues
Please include:
- Radxa Rock5B+ model and WiFi module info
- Operating system version
- Complete error logs from `/tmp/radxa_ap_setup.log`
- Output of `lspci | grep -i wireless`

## ✅ Changelog

### v1.0.0 (Current)
- Initial release
- RTL8852BE support
- Automatic interface detection
- Interactive configuration
- Comprehensive error handling
- Speed test integration

---

**⭐ If this script helped you, please star the repository!**

Made with ❤️ for the Radxa Rock5B+ community