# Mac Mini Setup Guide

Complete walkthrough for configuring your Mac Mini as a Flutter iOS build machine
accessible from Ubuntu via SSH.

---

## Prerequisites (do these manually first)

### On the Mac Mini
1. **Install Xcode** from the App Store (free, ~7GB, takes a while)
2. **Open Xcode once** to complete installation and accept the license
3. **Enable Remote Login (SSH)**:
   - System Settings → General → Sharing → Remote Login → ON
   - Note your Mac Mini's local IP (System Settings → Network)

### On Ubuntu
1. **Generate SSH key** (if you don't have one):
   ```bash
   ssh-keygen -t ed25519 -C "flutter-build"
   ```
2. **Copy key to Mac Mini**:
   ```bash
   ssh-copy-id yourusername@192.168.x.x
   ```
3. **Test SSH access**:
   ```bash
   ssh yourusername@192.168.x.x echo "connection works"
   ```

---

## Run the Setup Script

Once SSH works, from your project directory on Ubuntu:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/flutter-context/scripts/mac_setup.sh" 192.168.x.x yourusername
```

This installs: Homebrew, Flutter, CocoaPods, ios-deploy, accepts Xcode license.
Takes 5-15 minutes on first run.

---

## Daily Workflow

### Connect iPhone
Plug iPhone into Mac Mini via USB (Lightning or USB-C).
On iPhone: tap "Trust" when prompted.

### Build and install from Ubuntu
```bash
# Debug build — install directly to iPhone
bash "${CLAUDE_PLUGIN_ROOT}/flutter-context/scripts/build_ios.sh"

# Release build — for TestFlight
bash "${CLAUDE_PLUGIN_ROOT}/flutter-context/scripts/build_ios.sh" --release
```

### If Mac Mini IP changes (DHCP)
Set a static IP on your router for the Mac Mini (recommended),
or update `~/.flutter_build_config` with the new IP:
```bash
echo "MAC_MINI_IP=192.168.x.x" > ~/.flutter_build_config
echo "MAC_MINI_USER=yourusername" >> ~/.flutter_build_config
```

---

## Faster Iteration: Flutter on Android Emulator (Ubuntu)

For rapid UI iteration without involving the Mac Mini, use Android emulator locally:

```bash
# Install Android Studio on Ubuntu (includes emulator)
# Then:
flutter emulators --launch <emulator-id>
flutter run
```

Workflow: develop + iterate on Android emulator → when ready for real iPhone feel →
trigger `build_ios.sh` → test on device.

---

## Troubleshooting

### SSH timeout
- Check Mac Mini hasn't gone to sleep: System Settings → Energy → Prevent sleep
- Or disable sleep for the Mac Mini entirely (it's a build server)

### "No devices found" when installing
- Unplug/replug iPhone USB
- Check iPhone screen — "Trust This Computer?" prompt may be waiting
- Run on Mac Mini: `ios-deploy --detect`

### Build fails with code signing error
- Open Xcode on Mac Mini, open `ios/Runner.xcworkspace`
- Signing & Capabilities → select your Apple ID team
- This is a one-time step per machine

### Flutter version mismatch between Ubuntu and Mac Mini
```bash
# On Mac Mini (via SSH):
ssh user@mac-ip "cd ~/flutter && git fetch && git checkout stable && git pull"
```
