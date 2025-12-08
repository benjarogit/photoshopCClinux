# Adobe Photoshop CC 2019 Installer for Linux

![Photoshop on Linux](images/Screenshot.png)

![License](https://img.shields.io/badge/license-GPL--2.0-blue) ![Platform](https://img.shields.io/badge/platform-Linux-green) ![Wine](https://img.shields.io/badge/wine-5.0%2B-red) ![Photoshop](https://img.shields.io/badge/Photoshop-CC%202019-blue)

**Run Adobe Photoshop CC 2019 natively on Linux using Wine**

Optimized for CachyOS and all major Linux distributions.

---

## 🌍 Languages / Sprachen

- 🇬🇧 **[English Documentation](#english-documentation)** - See below
- 🇩🇪 **[Deutsche Dokumentation](README.de.md)** - Vollständige Anleitung

---

# English Documentation

## 📋 Table of Contents

- [Features](#-features)
- [System Requirements](#-system-requirements)
- [Important Notice](#-important-notice)
- [Quick Start](#-quick-start)
- [Installation Guide](#-installation-guide)
- [Known Issues & Solutions](#-known-issues--solutions)
- [Troubleshooting](#-troubleshooting)
- [Performance Tips](#-performance-tips)
- [Uninstallation](#-uninstallation)
- [Contributing](#-contributing)
- [License](#-license)

---

## ✨ Features

- ✅ **Local Installation** - Uses local installation files (no downloads from Adobe)
- ✅ **Automatic Setup** - Installs Wine components and dependencies automatically
- ✅ **Multi-Distribution Support** - Works on CachyOS, Arch, Ubuntu, Fedora, and more
- ✅ **Pre-Installation Check** - Validates system before installation
- ✅ **Automatic Troubleshooting** - Built-in diagnostic tools
- ✅ **Desktop Integration** - Creates menu entry and terminal command
- ✅ **GPU Workarounds** - Fixes for common graphics issues
- ✅ **Multi-Language** - Supports all Photoshop language packs

---

## 🖥️ System Requirements

### Required

- **OS:** 64-bit Linux distribution
- **RAM:** Minimum 4 GB (8 GB recommended)
- **Storage:** 5 GB free space in `/home`
- **Graphics:** Any GPU (Intel, Nvidia, AMD) with up-to-date drivers

### Required Packages

<details>
<summary><b>CachyOS / Arch Linux</b></summary>

```bash
sudo pacman -S wine winetricks
```
</details>

<details>
<summary><b>Ubuntu / Debian / Linux Mint</b></summary>

```bash
sudo apt install wine winetricks
```
</details>

<details>
<summary><b>Fedora / RHEL</b></summary>

```bash
sudo dnf install wine winetricks
```
</details>

<details>
<summary><b>openSUSE</b></summary>

```bash
sudo zypper install wine winetricks
```
</details>

---

## ⚠️ Important Notice

### You Must Provide Photoshop Installation Files

**This repository does NOT include Photoshop installation files.**

You must:
1. **Own a valid Adobe Photoshop CC 2019 license**
2. **Obtain the installer yourself** (see [How to Get Photoshop](#how-to-get-photoshop-files))
3. **Place files in `photoshop/` directory** (see [photoshop/README.md](photoshop/README.md))

### ⚡ Version Compatibility

**This installer is optimized for Photoshop CC 2019 (v20.x).**

According to [Wine AppDB](https://appdb.winehq.org/objectManager.php?iId=17&sClass=application), different Photoshop versions have varying compatibility:

- ✅ **CC 2019 (v20.0)** - Works with workarounds (GPU disabled) - **This installer**
- ⚠️ **CC 2024** - Limited support, many GPU issues
- 🏆 **CS3-CS6** - Better Wine compatibility, but older features
- ❌ **CC 2020+** - Increased online requirements, not recommended

**Why CC 2019?**
- Last version before heavy Creative Cloud integration
- Good feature set for professional work
- Works reliably with GPU disabled
- Offline installation possible

**Alternative Versions:**
If you have access to older versions, **Photoshop CS6 (13.0)** or **CS3 (10.0)** have better Wine ratings (Silver/Platinum), but lack modern features.

### How to Get Photoshop Files

#### Option 1: Official Adobe (Recommended)
- Download from Adobe Creative Cloud
- Get offline installer for Photoshop CC 2019 (v20.x)

#### Option 2: Existing Installation
- If you have Photoshop on Windows, extract installation files
- Windows location: `C:\Program Files\Adobe\Adobe Photoshop CC 2019\`

**⚖️ Legal:** You must have a valid license. This script only automates Wine installation.

---

## 🚀 Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/benjarogit/photoshopCClinux.git
cd photoshopCClinux
```

### 2. Place Photoshop Files

Copy your Photoshop CC 2019 installation files to `photoshop/` directory:

```
photoshop/
├── Set-up.exe
├── packages/
└── products/
```

See [photoshop/README.md](photoshop/README.md) for detailed structure.

### 3. Run Pre-Check

```bash
chmod +x pre-check.sh
./pre-check.sh
```

Should show: ✅ "All critical checks passed!"

### 4. Disable Internet (Recommended)

```bash
# WiFi
nmcli radio wifi off

# Or Ethernet
sudo ip link set <interface> down
```

This prevents Adobe login prompts during installation.

### 5. Run Installation

```bash
chmod +x setup.sh
./setup.sh
```

Select **Option 1** (install photoshop CC)

![Setup Screenshot](images/setup-screenshot.png)

### 6. In Adobe Setup Window

- Click "Install"
- Keep default path (`C:\Program Files\Adobe\...`)
- Select your language (e.g., en_US or de_DE)
- Wait 10-20 minutes

### 7. Re-enable Internet

```bash
nmcli radio wifi on
```

### 8. Launch Photoshop

```bash
photoshop
```

Or search for "Adobe Photoshop CC" in your application menu.

### 9. Disable GPU (Important!)

For stability:
1. In Photoshop: `Edit > Preferences > Performance` (Ctrl+K)
2. Uncheck "Use Graphics Processor"
3. Restart Photoshop

---

## 📖 Installation Guide

### Detailed Steps

#### Pre-Installation

1. **Install Required Packages**
   ```bash
   # CachyOS/Arch
   sudo pacman -S wine winetricks
   
   # Ubuntu/Debian
   sudo apt install wine winetricks
   ```

2. **Check System**
   ```bash
   ./pre-check.sh
   ```
   
   This validates:
   - 64-bit architecture
   - Wine/winetricks installation
   - Available disk space
   - RAM
   - Installation files presence

#### During Installation

1. **Wine Configuration**
   - Mono installer will appear → Click "Install"
   - Gecko installer will appear → Click "Install"
   - Wine config window → Set to Windows 10, click OK

2. **Component Installation** (automatic, ~10 minutes)
   - vcrun2010, vcrun2012, vcrun2013, vcrun2015
   - fonts and font-smoothing
   - msxml3, msxml6, gdiplus

3. **Adobe Photoshop Setup** (10-20 minutes)
   - Adobe installer window appears
   - Click "Install"
   - Choose language
   - Wait for completion
   - **Ignore** "ARKServiceAdmin" errors if they appear

#### Post-Installation

1. **Run Troubleshoot**
   ```bash
   ./troubleshoot.sh
   ```

2. **Launch Photoshop**
   ```bash
   photoshop
   ```
   
   First launch takes 1-2 minutes (normal!)

3. **Disable GPU**
   - Edit > Preferences > Performance
   - Uncheck "Use Graphics Processor"

---

## 🐛 Known Issues & Solutions

### Issue 1: Photoshop Crashes on Startup

**Cause:** GPU acceleration incompatibility with Wine

**Solution:**
```
1. Launch Photoshop
2. Edit > Preferences > Performance (Ctrl+K)
3. Uncheck "Use Graphics Processor"
4. Uncheck "Use OpenCL"
5. Restart Photoshop
```

### Issue 2: "VCRUNTIME140.dll is missing"

**Cause:** Visual C++ Runtime not installed properly

**Solution:**
```bash
WINEPREFIX=~/.photoshopCCV19/prefix winetricks vcrun2015
```

### Issue 3: Liquify Tool Doesn't Work

**Cause:** GPU/OpenCL issues

**Solution:**
- Disable GPU acceleration (see Issue 1)
- Or disable OpenCL: Preferences > Performance > Uncheck "Use OpenCL"

### Issue 4: Blurry/Ugly Fonts

**Solution:**
```bash
WINEPREFIX=~/.photoshopCCV19/prefix winetricks fontsmooth=rgb
```

### Issue 5: Installation Hangs at 100%

**Solution:**
- Wait 2-3 minutes
- If nothing happens, close installer (Alt+F4)
- Installation is likely complete
- Verify: `ls ~/.photoshopCCV19/prefix/drive_c/Program\ Files/Adobe/`

### Issue 6: "ARKServiceAdmin" Error During Installation

**Solution:**
- This error can be **ignored**
- Click "Ignore" or "Continue"
- Installation will complete successfully

### Issue 7: Slow First Startup (1-2 Minutes)

**Not an Issue:**
- First startup is always slow
- Subsequent starts take 10-30 seconds
- This is normal Wine behavior

---

## 🔧 Troubleshooting

### Automatic Troubleshooting

```bash
./troubleshoot.sh
```

This tool:
- ✅ Checks system requirements
- ✅ Validates installation
- ✅ Analyzes Wine configuration
- ✅ Scans logs for errors
- ✅ Applies automatic fixes when possible
- ✅ Provides detailed reports

### Manual Troubleshooting

#### Check Logs

```bash
# Setup log
cat ~/.photoshopCCV19/setuplog.log

# Wine errors
tail -n 50 ~/.photoshopCCV19/wine-error.log

# Runtime errors
tail -n 30 ~/.photoshopCCV19/photoshop-runtime.log
```

#### Wine Configuration

```bash
./setup.sh  # Select Option 3
```

Recommended settings:
- **Windows Version:** Windows 10
- **DPI:** 96 (default)
- **Virtual Desktop:** Optional (enable if fullscreen issues)

#### Reinstall Components

```bash
WINEPREFIX=~/.photoshopCCV19/prefix winetricks --force vcrun2015 msxml6
```

---

## 🚀 Performance Tips

### Essential (For Stability)

1. **Disable GPU in Photoshop** (Ctrl+K → Performance)
2. **Disable OpenCL** (Ctrl+K → Performance)

### Optional (For Speed)

3. **Use Wine-Staging**
   ```bash
   # CachyOS/Arch
   sudo pacman -S wine-staging
   
   # Ubuntu
   sudo add-apt-repository ppa:cybermax-dexter/sdl2-backport
   sudo apt install wine-staging
   ```

4. **Enable CSMT**
   ```bash
   WINEPREFIX=~/.photoshopCCV19/prefix winetricks csmt
   ```

5. **Use Virtual Desktop** (if performance issues)
   ```bash
   ./setup.sh  # Option 3 → Graphics → Enable virtual desktop
   ```

### Expected Performance

| Feature | Native Windows | Wine Linux | Notes |
|---------|---------------|------------|-------|
| Basic Tools | 100% | 90-95% | Excellent |
| Filters | 100% | 80-90% | Good |
| Liquify | 100% | 70-80% | Usable (GPU off) |
| 3D Features | 100% | 30-50% | Limited |
| Camera Raw | 100% | 60-80% | Usable |
| Startup Time | 5-10s | 10-30s | After first launch |

**Overall:** 85-90% of native performance for standard photo editing.

---

## 🗑️ Uninstallation

### Complete Removal

```bash
./setup.sh  # Select Option 4
```

This removes:
- Wine prefix (`~/.photoshopCCV19/`)
- Desktop entry
- Terminal command (`/usr/local/bin/photoshop`)

### Manual Removal

```bash
# Remove installation
rm -rf ~/.photoshopCCV19/

# Remove desktop entry
rm ~/.local/share/applications/photoshop.desktop

# Remove command
sudo rm /usr/local/bin/photoshop
```

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test your changes
4. Submit a pull request

### Reporting Issues

When reporting bugs, include:
- Linux distribution and version
- Wine version (`wine --version`)
- Error logs from `~/.photoshopCCV19/wine-error.log`
- Steps to reproduce

---

## 📚 Additional Resources

### Official Resources

- **German Documentation:** [README.de.md](README.de.md)
- **Quick Start Guide:** [START_HIER.md](START_HIER.md) (DE) or quick start section above
- **Testing Guide:** [TESTING.md](TESTING.md)
- **Wine AppDB:** [Photoshop on Wine](https://appdb.winehq.org/objectManager.php?iId=17&sClass=application)

### Alternative Solutions

If this installer doesn't work for you, consider these alternatives:

- **[PhotoGIMP](https://github.com/Diolinux/PhotoGIMP)** - GIMP configured to look/feel like Photoshop
- **[Krita](https://krita.org/)** - Professional painting and illustration (native Linux)
- **[Photopea](https://www.photopea.com/)** - Online Photoshop alternative (browser-based)
- **Older Photoshop Versions** - CS6 or CS3 have better Wine compatibility (see Wine AppDB)

### Community & Helpful Guides

- [How to Run Photoshop on Linux](https://www.linuxnest.com/how-to-run-photoshop-on-linux-an-ultimate-guide/)
- [Install Adobe Photoshop on Linux](https://thelinuxcode.com/install_adobe_photoshop_linux/)
- [Original Gictorbit Project](https://github.com/Gictorbit/photoshopCClinux)

---

## 📄 License

This project is licensed under the **GPL-2.0 License** - see the [LICENSE](LICENSE) file for details.

### Legal Notice

- ⚠️ Adobe Photoshop is proprietary software owned by Adobe Inc.
- ⚠️ You must have a valid license to use Photoshop
- ⚠️ This script only automates Wine installation
- ⚠️ No piracy is supported or encouraged
- ✅ Use at your own risk

---

## 🙏 Acknowledgments

- **[Gictorbit](https://github.com/Gictorbit)** - Original installer script
- **Wine Team** - Windows compatibility layer
- **Community Contributors** - Bug reports and fixes

---

## 📊 Project Status

![GitHub last commit](https://img.shields.io/github/last-commit/benjarogit/photoshopCClinux)
![GitHub issues](https://img.shields.io/github/issues/benjarogit/photoshopCClinux)
![GitHub stars](https://img.shields.io/github/stars/benjarogit/photoshopCClinux)

**Status:** ✅ Production Ready

**Tested on:**
- CachyOS (Primary)
- Arch Linux
- Ubuntu 22.04+
- Fedora 38+
- Other major distributions

---

## ❓ FAQ

<details>
<summary><b>Q: Do I need an Adobe account?</b></summary>

You need a valid Photoshop license, but you can use the offline installer without logging in during installation. Disable internet connection during setup.
</details>

<details>
<summary><b>Q: Which Photoshop version works?</b></summary>

Photoshop CC 2019 (v20.x) is tested and recommended. Other versions may not work properly.
</details>

<details>
<summary><b>Q: Can I use plugins?</b></summary>

Most plugins work. Install them to: `~/.photoshopCCV19/prefix/drive_c/Program Files/Adobe/Adobe Photoshop CC 2019/Plug-ins/`
</details>

<details>
<summary><b>Q: Does Camera Raw work?</b></summary>

Yes! After Photoshop installation, run `./setup.sh` and select Option 2 to install Camera Raw.
</details>

<details>
<summary><b>Q: Why is GPU disabled?</b></summary>

Wine has limited GPU acceleration support. Disabling it prevents crashes and improves stability.
</details>

<details>
<summary><b>Q: Can I use the latest Photoshop version?</b></summary>

Photoshop 2020+ has increased Adobe login requirements and may not work well offline. CC 2019 is the sweet spot for Linux.
</details>

---

## 💬 Support

- 🐛 **Bug Reports:** [GitHub Issues](https://github.com/benjarogit/photoshopCClinux/issues)
- 💡 **Feature Requests:** [GitHub Issues](https://github.com/benjarogit/photoshopCClinux/issues)
- 📖 **Documentation:** See files in this repository
- 🔧 **Automatic Help:** Run `./troubleshoot.sh`

---

**Made with ❤️ for the Linux community**

**Star ⭐ this repo if it helped you!**
