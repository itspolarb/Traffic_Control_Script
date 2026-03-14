# Traffic Control Script Pack

Traffic Control Script Pack is a FiveM traffic-management resource set built to give servers practical, in-game control over traffic density without relying on constant config edits or server restarts.

This project currently includes two versions:

- **Full** — global traffic control plus local scene-based traffic control
- **Lite** — global traffic control only, with the same general menu flow and access-management system

---

## What This Script Does

At its core, this script gives authorized users an in-game **Traffic Management** menu that can be used to control traffic behavior live.

Depending on which version you use, the script can provide:

### Global Traffic Control
- Global traffic presets:
  - Off
  - Low
  - Normal
  - High
- Custom density sliders for:
  - active street vehicles
  - random vehicle traffic
  - parked vehicles
  - walking peds
  - scenario/ambient peds
- Live application of traffic changes without restarting the server

### Access Management
- Runtime user/admin access management
- In-game access granting and revoking
- Bootstrap support so the script can be initialized by one trusted user and then managed from inside the menu afterward

### Unified In-Game Menu
- One main menu for traffic management
- Keyboard open keybind
- Controller navigation support while the menu is open
- Input blocking while the menu is open so users do not accidentally punch, shoot, or trigger other gameplay actions

### Full Version Only: Local Scene-Based Traffic Control
- Scene creation at the player’s position
- Scene radius selection
- Multiple scene modes
- Active scene listing and removal
- Scene cleanup / restoration behavior

---

## Full vs Lite

### Full Version
Use the **Full** version if you want the complete traffic-management framework.

It includes:
- global traffic presets
- custom global traffic sliders
- user/admin access management
- local traffic control scenes
- scene-based local traffic behavior

### Lite Version
Use the **Lite** version if you only want global traffic control.

It includes:
- global traffic presets
- custom global traffic sliders
- user/admin access management
- the same overall management flow for global controls

It does **not** include:
- local traffic scene creation
- local scene processing
- scene listing/removal

### Main Difference
- **Full** = global traffic + local scene traffic control
- **Lite** = global traffic only

---

## How It Works

The script is built around a synced state model.

### Global Traffic
Global traffic settings are stored in shared state and then applied client-side every frame. That means:
- a user with permission changes the global traffic mode
- the server stores the current mode/custom values
- all connected clients receive that state
- each client applies the density values locally every frame

This is the correct pattern for FiveM traffic-density control because the relevant traffic and ped density natives are frame-based.

### Local Scenes (Full Version)
Local scenes are stored as shared scene data:
- the server stores the active scenes
- clients receive the scene list
- nearby clients process the scene behavior locally

This means local scenes are shared and intended to affect all nearby players, not just the person who created them.

---

## Menu Overview

The Traffic Management menu is permission-aware. Users only see the sections they are allowed to use.

Depending on permissions, the menu can include:

- Global Traffic
- Local Traffic Control
- Active Scenes
- Access Management
- Refresh

### Global Traffic Menu
- Current preset display
- Preset: Off
- Preset: Low
- Preset: Normal
- Preset: High
- Custom Density Sliders

### Full Version: Local Traffic Control
- choose scene mode
- choose scene radius
- create scene at current position
- clear your own scenes

### Full Version: Active Scenes
- see active scenes
- open an individual scene
- remove a scene

### Access Management
- refresh player list
- view online players
- grant operator access
- revoke operator access
- grant admin access
- revoke admin access

---

## Scene Modes (Full Version)

The Full version includes scene-based traffic control modes.

### Hard Closure
Designed for:
- drag racing
- full street shutdowns
- accident scene road blocks
- road work shutdowns

Behavior:
- blocks new ambient traffic in the area
- removes traffic generators in the area
- can clear ambient AI traffic within the active zone

### Soft Closure
Designed for:
- lane-control style RP
- event traffic control
- shoulder work
- reduced local movement without fully killing the area

Behavior:
- lowers traffic heavily in the scene area
- still keeps the area less destructive than a full hard closure

### Reduced Flow
Designed for:
- event perimeters
- traffic calming areas
- controlled but not fully shut down traffic behavior

Behavior:
- lowers traffic density in the scene area without acting like a total shutdown

### Ped Suppression
Designed for:
- reducing local peds around a controlled scene

Behavior:
- lowers local ped presence while leaving the larger world intact

---

## Permissions

The script uses a runtime ACE/ACL management model.

The script still needs minimal bootstrap permissions in `server.cfg` so the resource is allowed to manage ACE objects and principals.

### Core Permission Concepts
The exact visibility of menu sections is based on permission state. In practical use, the important categories are:

- menu access
- global traffic access
- local scene access
- management/admin access

### Why Bootstrap Is Needed
The resource can manage access after startup, but FiveM still requires the resource to be allowed to execute the ACE/principal commands that make that possible.

---

## Install

## Folder Naming

After extracting, rename the resource folder to the correct name for the version you use.

### Full
Rename to:

```text
traffic_control
```

### Lite
Rename to:

```text
traffic_control_lite
```

This matters because the resource name must match the ACE bootstrap lines shown below.

---

## Full Version Install

1. Put the full version folder into your server resources directory
2. Rename the folder to:

```text
traffic_control
```

3. Add this to `server.cfg`:

```cfg
ensure traffic_control
add_ace resource.traffic_control command.add_ace allow
add_ace resource.traffic_control command.add_principal allow
add_ace resource.traffic_control command.remove_principal allow
```

---

## Lite Version Install

1. Put the lite version folder into your server resources directory
2. Rename the folder to:

```text
traffic_control_lite
```

3. Add this to `server.cfg`:

```cfg
ensure traffic_control_lite
add_ace resource.traffic_control_lite command.add_ace allow
add_ace resource.traffic_control_lite command.add_principal allow
add_ace resource.traffic_control_lite command.remove_principal allow
```

---

## Config Setup

Both versions include a config file.

The most important values to set are:

- bootstrap identifiers
- default traffic mode
- menu title
- notifications
- density presets
- scene defaults (full version)

### Bootstrap Identifier
Set your first trusted user in the bootstrap identifier list so the script can assign initial access/admin control on startup.

Use a placeholder until you replace it with your actual identifier.

Example pattern:

```lua
Config.BootstrapIdentifiers = {
    'identifier.fivem:PLACEHOLDER_ID'
}
```

---

## How To Use

### Opening the Menu
Use the configured keyboard keybind to open the Traffic Management menu.

By default, the script is built around a keyboard open bind with controller navigation available **while the menu is open**.

### Navigating the Menu
Once open:
- keyboard can navigate up/down/left/right
- controller can navigate while the menu is open
- confirm/select works from keyboard or controller
- cancel/back works from keyboard or controller

While the menu is open, gameplay inputs are suppressed so users do not accidentally:
- punch
- shoot
- trigger gameplay actions

### Using Global Traffic
1. Open the menu
2. Go to **Global Traffic**
3. Choose a preset or go into **Custom Density Sliders**
4. Apply the change

### Using Local Scenes (Full Version)
1. Open the menu
2. Go to **Local Traffic Control**
3. Choose a scene mode
4. Choose a radius
5. Create the scene at your current position

### Managing Access
1. Open the menu
2. Go to **Access Management**
3. Select an online player
4. Grant or revoke operator/admin access

---

## Sync Behavior

### Global Traffic
Global traffic changes are intended to affect the whole server, because the current mode/custom values are synced and then applied on all clients.

### Local Scenes
Local scenes are also synced as shared state, but their actual road/traffic suppression is processed client-side near the scene.

That means:
- the scene exists for everyone
- nearby players should be affected by it
- distant players are not expected to process it the same way because they are not near the scene

---

## Data Storage

The script stores authorization data in JSON so runtime-granted access can persist across restarts.

This is used because FiveM does not provide built-in persistent storage for dynamically managed ACE/principal changes.

---

## Troubleshooting

### The Resource Does Not Start
Check:
- folder name is correct
- `fxmanifest.lua` exists in the correct folder
- `ensure` line in `server.cfg` matches the actual folder/resource name

### The Menu Does Not Open
Check:
- the user has permission
- the correct resource is ensured
- the configured menu key exists in the config
- there are no client script errors in F8

### Global Traffic Changes Work For One Person But Not Another
This usually means:
- one client is not receiving/updating state properly
- or one client has an outdated/broken version of the resource

### Local Scenes Behave Strange
Local traffic control is the more complex side of the Full version. If something feels off, test:
- hard closure
- soft closure
- reduced flow
- scene removal/restoration

separately so you can isolate which scene mode is misbehaving.

---

## Transparency / Credits

This section is intentionally direct and fully transparent.

### Concept / Project Direction
- **Polarbearr** — concept direction, feature direction, beta testing, real-world use-case guidance

### Writing / Implementation
- **OpenAI (ChatGPT)** — code writing, rewrite passes, documentation drafting, iteration support

### Public References / Patterns Used
The script was written specifically for this project, but it was informed by publicly documented FiveM patterns and APIs, especially:

- FiveM traffic density natives and frame-based traffic application patterns
- FiveM ACE/ACL runtime command patterns
- FiveM key mapping patterns
- FiveM road suppression / generator suppression natives
- general FiveM menu/input handling patterns

This project was not built by copy-pasting one public traffic script and relabeling it. It was iterated directly for this use case, but it absolutely draws on normal public FiveM documentation concepts and expected native usage.

### What Was Not Claimed
Polarbearr does **not** claim authorship of the code itself in this release.
Polarbearr’s credit here is:
- concept
- direction
- testing
- shaping the project toward actual server use

OpenAI / ChatGPT wrote the implementation and documentation drafts used in this release process.

---

## Permission / Usage

You can do what you want with this.

This project is intentionally being released with a permissive, informal use policy:

- use it
- edit it
- fork it
- improve it
- release your own modified version
- adapt it for your server

Credit is appreciated, but the intent here is not to lock the script down.

If you build something better from it, go for it.

---

## Creators

- OpenAI
- Polarbearr
