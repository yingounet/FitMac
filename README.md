# FitMac

**Make Your Mac Fit Again!** 

An open-source, free, and secure Mac cleaning tool with both GUI (SwiftUI) and CLI support. Similar to CleanMyMac / OnyX, but completely open source (MIT License).

## Features

### MVP (Current)

- **Disk Status** - View disk usage and available space
- **Cache Cleaner** - Scan and clean system/application/browser/developer caches
- **Large Files Finder** - Find large files taking up space
- **App Uninstaller** - Find and remove app leftovers

### Safety Features

- Dry-run mode by default (preview changes before applying)
- All deletions go to Trash (recoverable)
- Transparent file paths
- No network connections (except optional updates)

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/yingounet/FitMac.git
cd FitMac

# Build
swift build -c release

# The binary will be at .build/release/fitmac
# You can copy it to your PATH
cp .build/release/fitmac /usr/local/bin/
```

## Usage

### Show Disk Status

```bash
fitmac status
```

### Cache Management

```bash
# Scan all caches
fitmac cache --scan

# Scan specific category
fitmac cache --scan --category browser
fitmac cache --scan --category dev

# Clean caches (dry-run by default)
fitmac cache --clean

# Actually delete files
fitmac cache --clean --no-dry-run
```

### Find Large Files

```bash
# Find files larger than 100MB in home directory
fitmac large

# Find files larger than 500MB in Downloads
fitmac large --path ~/Downloads --min 500MB

# Limit results
fitmac large --limit 10
```

### Find App Leftovers

```bash
# Search for app leftovers
fitmac uninstall "AppName"

# Clean leftovers (dry-run by default)
fitmac uninstall "AppName" --clean

# Actually delete
fitmac uninstall "AppName" --clean --no-dry-run
```

## Requirements

- macOS 13 Ventura or later (for GUI)
- macOS 11 Big Sur or later (for CLI)
- Xcode 15+ (for building from source)

## Project Structure

```
FitMac/
├── Sources/
│   ├── FitMacCore/       # Core library (shared by CLI and GUI)
│   │   ├── Cleaners/     # Scanner and cleaner logic
│   │   ├── Models/       # Data models
│   │   └── Utils/        # Utilities
│   ├── FitMacCLI/        # Command-line interface
│   └── FitMacApp/        # SwiftUI application (coming soon)
├── Tests/
│   └── FitMacCoreTests/  # Unit tests
└── Package.swift
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


**FitMac — Make Your Mac Fit Again!**
