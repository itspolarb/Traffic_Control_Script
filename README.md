# Traffic Control Script Pack

This pack includes **two versions** of the same traffic control system so servers can choose the one that fits their needs best.

## Included Versions

### 1. Full Version (`traffic_control_full_v1_70`)
The full version includes:
- **Global Traffic Control**
  - OFF / LOW / NORMAL / HIGH presets
  - custom density sliders
- **Local Traffic Control**
  - scene-based local traffic control options
  - designed for road closures, event traffic, drag-race street control, and similar use cases
- **Access Management**
  - built-in user/admin management
  - runtime permission handling
- **Single Menu System**
  - one traffic management menu for the whole script

This is the version meant for servers that want the complete system.

### 2. Lite Version (`traffic_control_lite_v1_0`)
The lite version keeps the same core style and management flow, but removes the local scene system.

The lite version includes:
- **Global Traffic Control**
  - OFF / LOW / NORMAL / HIGH presets
  - custom density sliders
- **Access Management**
  - built-in user/admin management
  - runtime permission handling
- **Same Menu Style / Same General Workflow**

The lite version does **not** include:
- local traffic control scenes
- local closures
- local scene management options

This is the version for servers that only want full-map traffic control without the extra local scene tools.

---

# Main Difference Between Full and Lite

## Full
Use this if you want:
- full server traffic control
- local road/scene traffic control
- a more advanced traffic management setup
- future expansion into RP scene tools

## Lite
Use this if you want:
- a simpler script
- only global traffic control
- less complexity
- the same admin/user management flow without the local scene features

---

# Recommended Folder Names

After extracting, rename the folders like this:

- Full version → `traffic_control`
- Lite version → `traffic_control_lite`

That keeps resource names clear and helps the README/server.cfg examples line up correctly.

---

# Quick Install Summary

## Full Version
Use:
```cfg
ensure traffic_control
```

## Lite Version
Use:
```cfg
ensure traffic_control_lite
```

Only run the version you actually want to use.

---

# Permissions / Access

Both versions are built around the same general permission approach:
- bootstrap one trusted identifier first
- grant/revoke access from inside the script afterward
- keep day-to-day use inside the menu instead of manually editing access every time

---

# Which Version Should You Pick?

Choose **Full** if your server wants traffic management as a bigger system.

Choose **Lite** if your server only wants easy, clean, global traffic presets and sliders.

---

# Discord / Release Description

**Traffic Control Script Pack**

This release includes **two versions** of the traffic control script:

**Full Version**
- global traffic presets
- custom sliders
- local traffic control scenes
- user/admin access management
- one unified traffic management menu

**Lite Version**
- same global traffic presets
- same slider-based control
- same access management flow
- no local scene system
- simpler and easier for servers that only want global traffic control

The idea behind the pack is simple:
- use **Full** if your server wants the complete traffic management framework
- use **Lite** if your server only needs map-wide traffic control without the local scene tools

Both versions are built to avoid restarts for normal use and are designed to be manageable in-game once initial setup is done.
