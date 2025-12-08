---
name: 🐛 Bug Report
about: Report a bug or issue with Photoshop installation or usage
title: '[BUG] '
labels: bug
assignees: ''
---

## 🐛 Bug Description

A clear and concise description of what the bug is.

## 📋 System Information

**Linux Distribution:**
- Distro: [e.g. CachyOS, Arch, Ubuntu 22.04]
- Desktop Environment: [e.g. KDE, GNOME, XFCE]
- Kernel Version: [run: `uname -r`]

**Hardware:**
- GPU: [e.g. Nvidia RTX 3060, Intel UHD 620, AMD RX 6700]
  - Check with: `lspci | grep -i 'vga\|3d\|2d'`
- RAM: [e.g. 16GB]

**Display Server:**
- [ ] X11
- [ ] Wayland

**Wine Version:**
- Wine Version: [run: `wine --version`]
- [ ] wine-staging
- [ ] wine-stable

## 🔍 Steps to Reproduce

1. Go to '...'
2. Click on '...'
3. Scroll down to '...'
4. See error

## ✅ Expected Behavior

A clear description of what you expected to happen.

## ❌ Actual Behavior

What actually happened instead.

## 📸 Screenshots / Logs

If applicable, add screenshots or logs:

```bash
# Include relevant logs
cat ~/.photoshopCCV19/wine-error.log | tail -n 50

# Or output from troubleshoot tool
./troubleshoot.sh
```

## 🔧 Troubleshooting Already Done

- [ ] Ran `./pre-check.sh` - all checks passed
- [ ] Ran `./troubleshoot.sh` - no critical errors
- [ ] Disabled GPU in Photoshop (Ctrl+K → Performance)
- [ ] Checked logs in `~/.photoshopCCV19/`
- [ ] Tried reinstalling

## 📦 Installation Method

- [ ] Fresh installation (v2.0.1)
- [ ] Upgrade from v2.0.0
- [ ] Custom installation path (specify: _______)

## 📝 Additional Context

Add any other context about the problem here.

---

**Note:** Please run `./troubleshoot.sh` and include relevant output for faster diagnosis!


