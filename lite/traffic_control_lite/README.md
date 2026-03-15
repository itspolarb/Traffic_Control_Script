# traffic_control_lite

Creators: OpenAI & Polarbearr

`traffic_control_lite` is the **lite/global-only edition** of the Traffic Control Script Pack.

It is kept in the repository alongside the full **v2.1** release for servers that want the same basic traffic-management style and access-management workflow, but **do not need local scene control or scene equipment props**.

---

## What it is

The lite version is built for servers that only want:
- global traffic presets
- custom density sliders
- in-menu access management
- a simpler overall setup

It keeps the menu-driven workflow without the extra scene and prop systems from the full version.

---

## Includes

- Global traffic presets:
  - OFF
  - LOW
  - NORMAL
  - HIGH
- Custom density sliders
- In-menu user/access management
- Runtime ACE/ACL bootstrap flow
- Persistent authorized identifier storage in JSON
- Keyboard-open traffic menu

---

## Does not include

- Local traffic scenes
- Hard Closure scenes
- Soft Closure scenes
- Reduced Flow scenes
- Ped Suppression scenes
- Scene equipment / prop placement
- Cones, barriers, or lights
- Remove nearest prop
- Clear my props
- Row placement
- Presets

---

## Position in the repo

This repository includes two versions:

- **`full/traffic_control/`** → full version, updated to **v2.1**
- **`lite/traffic_control_lite/`** → lite version, global-only option

Use the lite version if your server wants a simpler traffic setup and does not need the full local scene / equipment workflow.

---

## Folder name

After extracting, the resource folder should be named:

```text
traffic_control_lite
```

---

## Install

1. Put the resource in your server resources folder.
2. Add this to `server.cfg`:

```cfg
ensure traffic_control_lite
```

3. Add the ACE bootstrap lines to `server.cfg`:

```cfg
add_ace resource.traffic_control_lite command.add_ace allow
add_ace resource.traffic_control_lite command.add_principal allow
add_ace resource.traffic_control_lite command.remove_principal allow
```

4. Open `config.lua` and replace the placeholder bootstrap identifier in `Config.BootstrapIdentifiers`.

Example:

```lua
Config.BootstrapIdentifiers = {
    'identifier.license:REPLACE_WITH_YOUR_LICENSE'
}
```

5. Restart the server or run:

```cfg
refresh
ensure traffic_control_lite
```

---

## Permissions

This lite version uses:

- `trafficcontrol.menu`
- `trafficcontrol.global`
- `trafficcontrol.admin`

### `trafficcontrol.menu`
Lets the user open the menu.

### `trafficcontrol.global`
Lets the user change global traffic presets and apply custom sliders.

### `trafficcontrol.admin`
Lets the user manage access for other players from inside the menu.

---

## Menu sections

- Global Traffic
- Access Management
- Refresh

---

## Commands

- `/traffic off`
- `/traffic low`
- `/traffic normal`
- `/traffic high`
- `/traffic status`
- `/traffic menu`
- `/trafficmenu`

---

## Notes

- Changes apply live with no restart.
- Global traffic is handled with density controls rather than blunt world cleanup.
- Notifications are actor-only by default unless `Config.BroadcastGlobalChanges` is enabled.
- This version remains the simpler alternative to the full **v2.1** release.

---

## Credits / transparency

### Concept, direction, and beta testing
- **Polarbearr**

### Writing, implementation, cleanup, and documentation
- **OpenAI (ChatGPT)**

---

## Usage / permission

You can do what you want with this project.

That includes:
- use
- edit
- fork
- improve
- redistribute your modified version

Credit is appreciated, but the goal is utility and openness.
