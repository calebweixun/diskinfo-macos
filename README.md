# DiskInfo for macOS

DiskInfo is a native macOS app for understanding the physical drives connected to your Mac.

The goal is simple: make SMART and disk information useful to normal Mac users without requiring them to read raw `smartctl` output.

## What it does

- Finds physical disks using macOS `diskutil`
- Reads SMART data using `smartctl`
- Shows drive model, serial number, firmware, capacity and protocol
- Shows health, temperature, SSD wear, available spare and lifetime read/write data
- Shows power-on hours, power cycles, unsafe shutdowns and media/data errors
- Provides a simple native SwiftUI interface
- Includes a small command-line version for terminal users

## Requirements

- macOS 13 or later
- Xcode 15 or later for development
- [smartmontools](https://www.smartmontools.org/)

Install smartmontools with Homebrew:

```sh
brew install smartmontools
```

## Run from source

Clone the repository and open the package in Xcode:

```sh
git clone https://github.com/calebweixun/diskinfo-macos.git
cd diskinfo-macos
open Package.swift
```

Select the `DiskInfo` scheme and run it.

You can also build from Terminal:

```sh
swift build -c release
```

The command-line tool will be available at `.build/release/diskinfo` and the GUI executable at `.build/release/DiskInfo`.

## Why smartctl?

macOS exposes useful storage information through `diskutil`, but SMART health details are not presented in a convenient, consistent user interface. DiskInfo uses `diskutil` for macOS device discovery and `smartctl` for SMART data.

Different controllers expose different SMART fields. DiskInfo therefore treats many fields as optional and displays the information that the connected drive actually provides.

## Open source

DiskInfo's source code is licensed under the MIT License. See [LICENSE](LICENSE).

The project uses `smartmontools`, which is a separate open-source project with its own license. DiskInfo does not copy smartmontools source code into this repository; it invokes the user's installed `smartctl` executable.

## Status

This project is early-stage. The priority is making it reliable and useful for Mac users before adding advanced features.

### Planned

- Better disk type detection
- More robust SMART parsing for NVMe and SATA drives
- Health explanations in plain language
- SMART self-tests
- Temperature and wear history
- Exportable health reports
- Menu bar monitoring
- Better handling of USB and Thunderbolt enclosures
- Automated tests with sample `smartctl` output

## Contributing

Issues, suggestions, hardware test results and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).
