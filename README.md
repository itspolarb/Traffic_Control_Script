# Traffic Control Script Pack

A FiveM traffic-management script pack for servers that want practical live traffic control without constant config edits or restarts.

This repository keeps the same split layout:

- **`full/traffic_control/`** → the **full version**, now updated to **v2.1**
- **`lite/traffic_control_lite/`** → the **lite version**, kept for servers that want a simpler global-only setup

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
- row count, spacing, direction, and angle controls
- working cone and barrier presets
- configurable per-player prop limit
- death-safe menu / preview cleanup

Current full version: **v2.1**

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
- presets

---

## What v2.1 adds to the full version

The full v2.1 update expands the scene-equipment system introduced in v2.0. Major additions include:

- **single or row prop placement**
- configurable **row count**
- configurable **row spacing**
- configurable **row direction** (`Forward` / `Sideways`)
- configurable **row angle** with practical angle steps
- **cone presets** for quick lane and shoulder layouts
- **barrier presets** for each included barrier model
- configurable **per-player prop limit** with a default of `20`
- safer placement/menu cleanup when a player dies while using the system
- additional barrier model tuning so barrier walls line up correctly

v2.1 keeps the full version practical for traffic-control RP while avoiding the broken or unreliable presets that were removed during testing.

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
- Included props are intentionally basic and practical
- Prop placement is designed for RP utility, not full map-editor precision
- Server runtime native support can vary by artifact/runtime, so the server-side prop lifecycle is intentionally kept minimal for compatibility
- Prop cleanup uses synced state plus client reconciliation for visual reliability

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
