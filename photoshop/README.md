# Photoshop Installation Files

## ⚠️ Important Notice

This directory should contain your **Adobe Photoshop CC 2019** installation files.

**You must obtain these files yourself.** This repository does not provide Photoshop installation files due to licensing restrictions.

---

## 📁 Required Directory Structure

Place your Photoshop CC 2019 installation files in this directory with the following structure:

```
photoshop/
├── Set-up.exe              (Adobe Photoshop CC 2019 Installer)
├── packages/               (Adobe installation packages)
│   ├── AAM/
│   │   ├── install.sig
│   │   └── IPC/
│   └── ADC/
│       ├── Core/
│       ├── HDBox/
│       ├── IPCBox/
│       ├── LCC/
│       └── Runtime/
├── products/               (Photoshop product files)
│   ├── ACR/               (Camera Raw)
│   ├── COCM/
│   ├── COPS/
│   ├── CORE/
│   ├── CORG/
│   └── PHSP/              (Photoshop core with language packs)
└── resources/              (Installation resources)
    ├── AdobePIM.dll
    ├── Config.xml
    └── content/
```

---

## 🔍 How to Obtain Photoshop CC 2019

### Option 1: Official Adobe Installer (Recommended)
1. **If you have an Adobe account with a valid license:**
   - Download Adobe Creative Cloud installer
   - Install Photoshop CC 2019 on Windows first
   - Extract installation files from:
     - Windows: `C:\Program Files (x86)\Common Files\Adobe\Installers\`
     - Or use Adobe offline installer

### Option 2: Offline Installer Package
1. **Search for:** "Adobe Photoshop CC 2019 v20 offline installer"
2. Make sure it's the **v20.x version** (Photoshop CC 2019)
3. Extract all files to this `photoshop/` directory

---

## ✅ Verification

After placing the files, verify the structure:

```bash
# Run from the project root directory
ls -la photoshop/Set-up.exe
ls -la photoshop/packages/
ls -la photoshop/products/PHSP/
```

All commands should show files/directories exist.

---

## 🚀 Ready to Install?

Once files are in place:

```bash
# Run pre-check
./pre-check.sh

# If all checks pass, run installation
./setup.sh
```

---

## 📝 Notes

- **File Size:** Complete installation files are approximately 1.5-2 GB
- **Version:** Must be **Photoshop CC 2019 (v20.x)**, other versions may not work
- **Language Packs:** The installer includes multiple languages (de_DE, en_US, etc.)
- **Replacement Files:** Optional icon files in `replacement/` are not required

---

## ⚖️ Legal Notice

- Adobe Photoshop is proprietary software owned by Adobe Inc.
- You must have a valid license to use Photoshop
- This script only automates installation on Linux via Wine
- No piracy is supported or encouraged
- Use at your own risk

---

## 🆘 Need Help?

- **Pre-installation check failed?** See main [README.md](../README.md)
- **Wrong file structure?** Compare with the structure above
- **Can't find installer?** You must obtain it legally from Adobe

---

**Ready?** Go back to main directory and run `./pre-check.sh`


