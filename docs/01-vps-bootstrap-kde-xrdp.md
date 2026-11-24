# Step 01 — VPS Bootstrap, Swap/ZRAM Tuning & KDE Plasma / xRDP Setup

This guide prepares a clean Ubuntu Linux VPS (e.g., Ubuntu 22.04/24.04 LTS) to run **OmniRoute**, **Hermes Agent**, **Claude Code CLI**, **Docker services**, and headless/visual browsers reliably 24/7.

---

## 1. Base System & Runtime Dependencies

Update packages and install core utilities (`tmux`, `curl`, `git`, `ffmpeg`, `sqlite3`, `build-essential`):

```bash
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y \
  ca-certificates curl gnupg lsb-release git tmux htop sqlite3 \
  python3 python3-pip python3-venv ffmpeg imagemagick xvfb
```

### Install Node.js 24 LTS
```bash
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs
node -v && npm -v
```

### Install Docker & Docker Compose Plugin
```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker "$USER"
```

---

## 2. Memory Tuning: Swap & ZRAM (Critical on Low-RAM VPS)

On compact cloud instances (e.g., **2 vCPU / 3.7–4.0 GiB RAM**), Chromium renderers (150–250 MiB each), Node.js heaps (`omniroute`), and Docker containers can trigger the Linux OOM Killer without a proper swap buffer.

### Add a 6 GiB Swap Buffer (or 4 GiB + ZRAM)
```bash
sudo fallocate -l 6G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Prefer keeping active processes in RAM before paging
sudo sysctl vm.swappiness=20
echo 'vm.swappiness=20' | sudo tee -a /etc/sysctl.conf
```

> [!TIP]
> For production workloads running 10+ concurrent agent workers alongside Remotion video renders or Docker builds, consider `zram-tools` (`4 GB` compressed memory swap) and capping heavy systemd units with `MemoryMax=12G` and `CPUQuota=600%`.

---

## 3. Journald Log Cap (Prevent Disk Saturation)

Continuous 24/7 services can fill a small SSD (`50–80 GB`) via systemd logs. Enforce a strict `150 MB` cap:

```bash
sudo mkdir -p /etc/systemd/journald.conf.d
cat << 'EOF' | sudo tee /etc/systemd/journald.conf.d/size-cap.conf
[Journal]
SystemMaxUse=150M
MaxRetentionSec=7day
EOF
sudo systemctl restart systemd-journald
```

---

## 4. Visual Desktop & Headless Display (`DISPLAY=:10` & `DISPLAY=:99`)

Some OAuth sign-in flows, browser automation tasks, and Remotion/Playwright renders require an X11 display:

### Option A: Headless Virtual Framebuffer (`DISPLAY=:99`) — Lowest RAM Footprint
```bash
# Run Xvfb as a background service on :99
Xvfb :99 -screen 0 1920x1080x24 &
export DISPLAY=:99
```

### Option B: KDE Plasma + xRDP (`DISPLAY=:10`) — Full Remote Desktop
```bash
sudo apt-get install -y kde-plasma-desktop xrdp dbus-x11
echo "startplasma-x11" > ~/.xsession
sudo systemctl enable --now xrdp
```
> [!WARNING]
> Only expose port `3389` over an encrypted SSH tunnel, VPN (Tailscale/WireGuard), or a strict firewall allowlist—never open raw RDP to `0.0.0.0/0` in production, and always replace default passwords immediately.

---

## 5. Windows Workstation SSH Hygiene

When managing your remote VPS (`198.51.100.10` example IP) from Windows PowerShell, avoid hanging terminals if the VPS sleeps or restarts by enforcing connection timeouts and keepalives in `~/.ssh/config` or your PowerShell profile:

```powershell
function Connect-VPS {
    ssh -i "$HOME\.ssh\example_vps_key.pem" `
        -o ConnectTimeout=3 `
        -o ServerAliveInterval=15 `
        -o ServerAliveCountMax=3 `
        ubuntu@198.51.100.10
}
```
And for multi-line Linux scripts executed from Windows PowerShell, write a local `.sh` file, upload with `scp`, strip CRLF (`sed -i 's/\r$//' script.sh`), and run `bash script.sh` to avoid PowerShell `$()` interpolation errors.

---

## Next Step
Proceed to **[02 — OmniRoute AI Gateway & Auto-Failover](02-omniroute-gateway-setup.md)**.
