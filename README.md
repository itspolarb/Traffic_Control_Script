# Traffic Control Script Pack

A FiveM traffic-management script pack for servers that want practical live traffic control without constant config edits or restarts.

This repository includes two versions:

- **`full/traffic_control/`** → the **full version**, updated to **v2.2**
- **`lite/traffic_control_lite/`** → the **lite version**, a simpler global-only option

---

## Repository structure

```text
Traffic_Control_Script/
├─ README.md
├─ CHANGELOG.md
├─ LICENSE
├─ full/
│  └─ traffic_control/
└─ lite/
   └─ traffic_control_lite/
```

## Full vs Lite

### Full version (`full/traffic_control/`)
Use the full version if you want the complete framework:
- global traffic presets
- custom density sliders
- local traffic-control scenes
- active scene list and scene removal
- access management
- scene equipment / prop placement
- cones, barriers, and lights
- single prop placement
- row prop placement
- grouped preset scenes
- multi-prop scene support
- fine placement rotation
- configurable per-player prop limit

Current full version: **v2.2**

### Lite version (`lite/traffic_control_lite/`)
Use the lite version if you want a simpler setup focused on global traffic control only.

Lite keeps:
- global traffic presets
- custom density sliders
- in-menu access management

Lite does **not** include:
- local scene creation
- local scene processing
- scene equipment props
- row placement
- preset scenes
- multi-prop scene support

---

## What v2.2 adds to the full version

The full v2.2 update expands the scene-equipment system with a more organized preset workflow and support for one-click scene deployment.

### Added
- **grouped preset scene menu**
- **multi-prop scene support**
- preset scenes including:
  - **Drag Strip Markers (1/8 Mile)**
  - **Shoulder Work Pack**
  - **Mini Road Closure**

### Changed
- presets moved out of the single-prop menu into their own **Preset Scenes** menu
- placement rotation tuned for finer control
- prop limit increased for larger preset scenes

### Fixed
- warning/work light row orientation
- barrier taper orientation issues
- preset preview/menu stability issues
- assorted preset alignment issues

---

## Install

### Full version
Install the resource from:

```text
full/traffic_control/
```

Add this to `server.cfg`:

```cfg
ensure traffic_control
add_ace resource.traffic_control command.add_ace allow
add_ace resource.traffic_control command.add_principal allow
add_ace resource.traffic_control command.remove_principal allow
```

Then open `full/traffic_control/config.lua` and replace the bootstrap identifier with your own.

### Lite version
Install the resource from:

```text
lite/traffic_control_lite/
```

Add this to `server.cfg`:

```cfg
ensure traffic_control_lite
add_ace resource.traffic_control_lite command.add_ace allow
add_ace resource.traffic_control_lite command.add_principal allow
add_ace resource.traffic_control_lite command.remove_principal allow
```

---

## Permissions

Both versions use ACE-based permissions:

- `trafficcontrol.menu`
- `trafficcontrol.global`
- `trafficcontrol.local`
- `trafficcontrol.manage`
- `trafficcontrol.admin`

### Operator access
Operators can access:
- menu
- local traffic control
- prop placement in the full version

### Admin access
Admins can access:
- menu
- global traffic
- local traffic
- prop placement in the full version
- management functions
- admin functions

---

## Known limitations

### Full version
- included props are intentionally practical rather than map-editor level
- preset scenes are designed for quick RP deployment, not full custom save/load yet
- server runtime native support can vary by artifact/runtime, so the server-side prop lifecycle is intentionally kept minimal for compatibility
- prop cleanup uses synced state plus client reconciliation for visual reliability

### Lite version
- intentionally more limited
- does not replace the full version feature set
- exists as a separate simpler option for servers that want less complexity

---

## Credits / transparency

### Concept, direction, and beta testing
- **Polarbearr**

### Writing, implementation, cleanup, and documentation
- **OpenAI (ChatGPT)**

This project was written specifically for this release, but it naturally uses standard FiveM scripting patterns and common public concepts such as traffic density control, ACE/ACL access control, key mapping, synced state handling, and prop/object management patterns.

---

## Usage / permission

You can do what you want with this project.
That includes use, edit, fork, improve, and redistribution of modified versions.

Credit is appreciated, but the goal of this release is utility and openness.
