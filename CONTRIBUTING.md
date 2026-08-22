# Contributing to DiskInfo

Thanks for helping improve DiskInfo.

## Good first contributions

You do not need to be an expert. Useful contributions include:

- Testing the app on a different Mac model
- Reporting a drive that DiskInfo cannot read correctly
- Improving SMART parsing
- Improving the user interface
- Improving documentation

When reporting a disk issue, please include:

- macOS version
- Mac model / Apple silicon or Intel
- Drive model
- Whether the drive is internal, USB, or Thunderbolt
- Relevant `smartctl -a` output with serial numbers removed

## Development

Open `Package.swift` in Xcode, select the `DiskInfo` scheme, and run it on a Mac. You will also need `smartmontools` installed.

Please keep changes small and easy to understand. The project is intentionally simple while the design is still evolving.
