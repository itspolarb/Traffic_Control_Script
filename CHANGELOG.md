# Changelog

## v2.2.0
Updated the full version in `full/traffic_control/` to v2.2.

### Added
- grouped preset scene menu
- multi-prop scene preset support
- preset scene groups for cleaner navigation
- new preset scenes:
  - Drag Strip Markers (1/8 Mile)
  - Shoulder Work Pack
  - Mini Road Closure
- finer placement rotation controls for better road alignment

### Changed
- preset scenes moved out of the single-prop menu into their own menu
- full version preset system expanded from simple row presets into grouped scene presets
- prop limit increased for larger preset scenes
- preview and placement flow refined for scene-based preset deployment

### Fixed
- warning light row orientation
- work light row orientation
- barrier taper orientation issues
- barrier preset facing issues in scene presets
- preset preview crash caused by a bad preview reference
- assorted preset alignment issues during testing

### Notes
- v2.2 focuses on stable grouped presets and multi-prop scene support
- larger DOT-style closure packs and preset save/load are planned for a future update
- `lite/traffic_control_lite/` remains in the repository as the simpler alternative version

## v2.1.0
Updated the full version in `full/traffic_control/` to v2.1.

### Added
- single or row prop placement
- row count control
- row spacing control
- row direction control
- row angle control
- cone presets
- barrier presets for each included barrier model
- configurable per-player prop limit with a default of 20

### Improved
- barrier model tuning so barrier presets line up correctly
- death-safe cleanup for menu and preview states
- general scene-equipment stability after beta testing

### Notes
- broken drag and light presets were removed before the v2.1 release so only working presets remain
- `lite/traffic_control_lite/` remains in the repository as the simpler alternative version

## v2.0.0
Updated the full version in `full/traffic_control/` to v2.0.

### Added
- scene equipment / prop placement
- cones, barriers, and lights
- preview placement mode
- walk-and-look placement flow
- remove nearest prop
- clear my props
- configurable prop limit per player
- default prop limit set to 20

### Improved
- prop cleanup reconciliation
- player join prop sync
- server-side prop lifecycle compatibility for runtimes with limited native support

### Notes
- `lite/traffic_control_lite/` remains in the repository as the simpler alternative version
