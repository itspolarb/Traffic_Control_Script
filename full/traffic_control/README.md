# traffic_control v2.0

Creators: OpenAI & Polarbearr

`traffic_control` is the full edition of the traffic-management framework.
It is built for servers that want both global traffic control and local scene-based traffic control, plus basic scene equipment props for RP use.

---

## What this version includes

### Global traffic control
- Presets: `OFF`, `LOW`, `NORMAL`, `HIGH`
- Custom sliders for:
  - Vehicle density
  - Random vehicle density
  - Parked vehicle density
  - Ped density
  - Scenario ped density
- Live application with no restart required

### Local traffic control
- Create scenes at your current position
- Radius-based scene creation
- Scene modes:
  - Hard Closure
  - Soft Closure
  - Reduced Flow
  - Ped Suppression
- Active scene list
- Scene removal
- Clear your scenes

### Scene equipment / props
- Cones
- Barriers
- Lights
- Preview placement mode
- Walk-and-look placement flow
- Remove nearest prop
- Clear your props
- Configurable per-player prop limit
- Default prop limit: `20`

### Access management
- Bootstrap identifier setup
- Operator access
- Admin access
- In-menu user management

---

## Folder name

After extracting, rename the resource folder to:

```text
traffic_control
```

This matters because the ACE bootstrap lines reference:

```cfg
resource.traffic_control
```

---

## Installation

### 1. Put the resource in your resources folder

Example:

```text
resources/[standalone]/traffic_control
```

### 2. Add to `server.cfg`

```cfg
ensure traffic_control
add_ace resource.traffic_control command.add_ace allow
add_ace resource.traffic_control command.add_principal allow
add_ace resource.traffic_control command.remove_principal allow
```

### 3. Set your bootstrap identifier in `config.lua`

Replace the placeholder inside `Config.BootstrapIdentifiers` with your own identifier.

### 4. Restart the resource

```cfg
refresh
ensure traffic_control
```

---

## Permissions

This version uses:

- `trafficcontrol.menu`
- `trafficcontrol.global`
- `trafficcontrol.local`
- `trafficcontrol.manage`
- `trafficcontrol.admin`

### `trafficcontrol.menu`
Lets the user open the menu.

### `trafficcontrol.global`
Lets the user use global presets and custom sliders.

### `trafficcontrol.local`
Lets the user create scenes and place props.

### `trafficcontrol.manage`
Lets the user manage more than their own scenes/props.

### `trafficcontrol.admin`
Lets the user manage access for other players.

---

## Notes

- Global traffic is applied client-side every frame because GTA/FiveM density natives are frame-based.
- Scenes are stored on the server and processed client-side by nearby players.
- Props are synced through shared state and cleaned up visually by clients when removed.
- Server-side prop lifecycle is intentionally minimal for compatibility with runtimes that do not expose every native the same way.

---

## Credits / transparency

### Concept, direction, and beta testing
- **Polarbearr**

### Writing, implementation, cleanup, and documentation
- **OpenAI (ChatGPT)**
