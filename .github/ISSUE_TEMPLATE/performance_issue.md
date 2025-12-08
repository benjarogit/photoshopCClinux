---
name: 🚀 Performance Issue
about: Report performance problems (lag, crashes, slow startup)
title: '[PERFORMANCE] '
labels: performance
assignees: ''
---

## 🚀 Performance Problem

Describe the performance issue you're experiencing.

## 📊 Symptoms

What exactly is happening?

- [ ] Screen update lag when painting
- [ ] Slow zoom/pan
- [ ] Startup takes too long
- [ ] Frequent crashes
- [ ] High CPU/RAM usage
- [ ] Black screen flashing
- [ ] Other: _______

## 📋 System Information

**Hardware:**
- CPU: [e.g. AMD Ryzen 7 5800X]
- RAM: [e.g. 16GB DDR4]
- GPU: [e.g. Nvidia RTX 3060]
  - Driver Version: [run: `nvidia-smi` or `glxinfo | grep "OpenGL version"`]

**Software:**
- Linux Distro: [e.g. CachyOS]
- Kernel: [run: `uname -r`]
- Wine Version: [run: `wine --version`]
- Display Server: [ ] X11 [ ] Wayland

## 🔧 Performance Tweaks Already Applied

- [ ] Disabled GPU in Photoshop (Ctrl+K → Performance)
- [ ] Applied Wine registry tweaks (CSMT, shader_backend)
- [ ] Set CPU topology in launcher
- [ ] Reduced brush size / document resolution
- [ ] Closed other applications

## 📈 Performance Metrics

If possible, provide:

```bash
# CPU usage during issue
top -b -n 1 | head -n 20

# Memory usage
free -h

# Wine process info
ps aux | grep wine
```

## ✅ Expected Performance

How fast should it be? Or how did it perform before?

## 📸 Screenshots / Videos

If applicable, add screenshots or screen recordings showing the performance issue.

## 📝 Additional Context

- Document size: [e.g. 4000x3000px, 300dpi]
- Number of layers: [e.g. ~50 layers]
- File format: [e.g. PSD, TIFF]

---

**Quick Performance Tips:**
1. Disable GPU in Photoshop: `Ctrl+K` → Performance → Uncheck GPU
2. Check CSMT is enabled: `export CSMT=enabled` in launcher
3. Try different CPU topology values
4. Use lighter brushes / fewer layers



