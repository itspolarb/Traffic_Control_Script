# traffic_control v1.70

Creators: OpenAI & Polarbearr

`traffic_control` is a standalone FiveM traffic-management resource focused on two things:
- **Global traffic control** for the whole server
- **Local scene-based traffic control** for closures, slowdowns, and managed areas

This is the **official v1.70 release** line.

---

## What this resource does

### Global traffic control
You can change overall server traffic live without restarting the server.

Included global controls:
- Presets: `OFF`, `LOW`, `NORMAL`, `HIGH`
- Custom sliders for:
  - Vehicle density
  - Random vehicle density
  - Parked vehicle density
  - Ped density
  - Scenario ped density

The global system is designed to feel smooth. It does not just hard-delete everything instantly. Existing traffic can naturally clear out.

### Local traffic control
You can create local traffic-control scenes in specific areas.

Included scene modes:
- **Hard Closure**
- **Soft Closure**
- **Reduced Flow**
- **Ped Suppression**

These are intended for things like:
- drag-racing road closures
- event traffic control
- crash scenes
- construction zones
- temporary road management

### Built-in access management
The resource can manage traffic-control permissions from inside the menu after one bootstrap admin is set up.

---

## Main features

- One unified traffic menu
- Sections hidden automatically if the player does not have permission to use them
- Global presets and sliders
- Local scene creation and scene removal
- Runtime ACE/ACL permission handling
- Persistent authorized identifier storage in JSON
- Keyboard open keybind through FiveM key mapping
- Actor-only notifications by default

---

## Folder name

After extracting, rename the resource folder to:

```text
traffic_control
```

This matters because the ACE bootstrap in `server.cfg` references:

```cfg
resource.traffic_control
```

If the folder name does not match, the resource will not get the ACE command permissions it needs.

---

## Installation

### 1. Put the resource in your server resources folder

Example:

```text
resources/[standalone]/traffic_control
```

### 2. Make sure these files are in the resource folder

You should have:

```text
traffic_control/
├─ fxmanifest.lua
├─ config.lua
├─ server.lua
├─ client.lua
├─ README.md
└─ data/
   └─ authorized_identifiers.json
```

### 3. Add the resource to `server.cfg`

```cfg
ensure traffic_control
```

### 4. Add the ACE bootstrap lines to `server.cfg`

These are required so the resource can manage ACE/principal assignments at runtime.

```cfg
add_ace resource.traffic_control command.add_ace allow
add_ace resource.traffic_control command.add_principal allow
add_ace resource.traffic_control command.remove_principal allow
```

### 5. Set your bootstrap identifier in `config.lua`

Open `config.lua` and replace the placeholder identifier in `Config.BootstrapIdentifiers`.

Example:

```lua
Config.BootstrapIdentifiers = {
    'identifier.license:REPLACE_WITH_YOUR_LICENSE'
}
```

You can list more than one bootstrap identifier if you want.

Example:

```lua
Config.BootstrapIdentifiers = {
    'identifier.license:FIRST_ADMIN_LICENSE',
    'identifier.license:SECOND_ADMIN_LICENSE'
}
```

### 6. Restart the resource or server

If the server is already running, use:

```cfg
refresh
ensure traffic_control
```

---

## Permissions

This resource uses runtime ACE/ACL plus a saved JSON allowlist.

### Permission nodes used by the script

- `trafficcontrol.menu`
- `trafficcontrol.global`
- `trafficcontrol.local`
- `trafficcontrol.manage`
- `trafficcontrol.admin`

### What each permission means

#### `trafficcontrol.menu`
Lets the player open the traffic menu.

#### `trafficcontrol.global`
Lets the player use global traffic controls.

This includes:
- presets
- sliders
- custom density apply

#### `trafficcontrol.local`
Lets the player use local scene controls.

This includes:
- create scenes
- remove their own scenes
- clear their own scenes

#### `trafficcontrol.manage`
Reserved for broader scene management authority.

Use this for people who should be allowed to manage more than just their own scenes.

#### `trafficcontrol.admin`
Lets the player use access-management tools inside the menu.

This includes:
- grant operator access
- revoke operator access
- grant admin access
- revoke admin access

### Bootstrap behavior

When the resource starts, every identifier listed in `Config.BootstrapIdentifiers` is granted the admin traffic role.

That gives you an initial trusted user who can then grant access to other people from inside the menu.

---

## How to find your identifier

The exact identifier you use depends on your setup.

For this resource, ACE bootstrap identifiers should use the principal format, such as:

```text
identifier.license:xxxxxxxxxxxxxxxx
```

or, if you are using a Cfx.re/FiveM identifier:

```text
identifier.fivem:12345
```

Use the identifier format that matches how your server is set up and how you want to manage access.

---

## How to use the menu

### Open the menu
By default, the menu opens with:

```text
F5
```

The default key is controlled in `config.lua`:

```lua
Config.MenuKey = 'F5'
```

Users can also change the bound key in FiveM’s keybind settings because the menu uses `RegisterKeyMapping`.

---

## Menu layout

The menu is one unified interaction-style menu.

Sections are shown only if the player has permission for them.

Possible sections:
- Global Traffic
- Local Traffic Control
- Active Scenes
- Access Management
- Refresh

If a user does not have access to a section, it is hidden.

---

## Global Traffic section

Use this section to control server-wide traffic.

### Presets
Available presets:
- `OFF`
- `LOW`
- `NORMAL`
- `HIGH`

### Custom sliders
You can also fine-tune traffic with sliders.

Slider categories:
- Vehicle Density
- Random Vehicle Density
- Parked Vehicle Density
- Ped Density
- Scenario Peds

Use the sliders, then choose:

```text
Apply Custom Sliders
```

to make them live.

If you want to go back to defaults, use:

```text
Reset Sliders to NORMAL
```

---

## Local Traffic Control section

Use this section to create local traffic-management scenes.

### Scene settings
Before placing a scene, choose:
- Scene Mode
- Scene Radius

Then select:

```text
Create Scene At My Position
```

### Scene modes

#### Hard Closure
Best for:
- drag-racing road closures
- full shutdowns
- scenes where you want the strongest suppression

Recommended use:
- larger road closures
- active racing lanes
- strong traffic suppression

#### Soft Closure
Best for:
- lane control
- partial closures
- event traffic management

Recommended use:
- areas where traffic should be strongly reduced but not feel completely dead

#### Reduced Flow
Best for:
- event perimeters
- general slowdown areas
- “traffic is managed, but not shut down” scenes

Recommended use:
- broad local control without a full closure

#### Ped Suppression
Best for:
- reducing local pedestrian presence around a controlled scene

Recommended use:
- keeping the area cleaner around an active operation

### Managing your local scenes
Inside the local controls, you can also:
- clear all of your own scenes
- view active scenes
- remove specific scenes

---

## Active Scenes section

This section lists all currently active local traffic scenes.

For each scene, the menu shows:
- scene ID
- mode/label
- radius
- owner name

Selecting a scene lets you remove it.

---

## Access Management section

This section is only available to users with admin traffic permission.

From here you can:
- refresh player list
- grant operator access
- revoke operator access
- grant admin access
- revoke admin access

This means you only need to bootstrap one trusted admin in `config.lua`, and then that person can handle the rest from inside the resource.

---

## Commands

### Menu commands
- `/trafficmenu` — opens the traffic menu
- `/traffic menu` — opens the traffic menu

### Global traffic commands
- `/traffic off`
- `/traffic low`
- `/traffic normal`
- `/traffic high`
- `/traffic status`

These let you manage global traffic without opening the menu.

---

## Notifications

By default, action notifications are sent only to the user who triggered the action.

That means global changes and local scene changes do not spam the whole server by default.

---

## Data storage

Authorized identifiers are stored in:

```text
data/authorized_identifiers.json
```

This file is used so granted access survives resource restarts.

---

## Typical setup examples

### Example 1: One admin bootstrap only
In `config.lua`:

```lua
Config.BootstrapIdentifiers = {
    'identifier.license:YOUR_LICENSE_HERE'
}
```

In `server.cfg`:

```cfg
ensure traffic_control
add_ace resource.traffic_control command.add_ace allow
add_ace resource.traffic_control command.add_principal allow
add_ace resource.traffic_control command.remove_principal allow
```

That one bootstrap admin can then grant everyone else access from inside the menu.

### Example 2: Two bootstrap admins
In `config.lua`:

```lua
Config.BootstrapIdentifiers = {
    'identifier.license:FIRST_ADMIN_LICENSE',
    'identifier.license:SECOND_ADMIN_LICENSE'
}
```

---

## Troubleshooting

### The resource does not start
Check these first:
- folder name is exactly `traffic_control`
- `fxmanifest.lua` exists in the root of the folder
- `ensure traffic_control` is in `server.cfg`
- the ACE bootstrap lines are in `server.cfg`

### The menu does not open
Check:
- you have permission to open the menu
- your bootstrap identifier is correct
- the resource started successfully
- `Config.MenuKey` is set to a valid keyboard key string

### Global traffic works but local scenes do not
Check:
- the user has `trafficcontrol.local`
- the scene was actually created in the menu
- the area is close enough to the player for the client to process it

### Access changes do not persist
Check:
- `data/authorized_identifiers.json` exists
- the resource has permission to run `add_ace`, `add_principal`, and `remove_principal`
- the folder is writable by the server process

### Roads seem stuck after scene deletion
Try:
- removing the scene again
- restarting the resource once
- making sure there are no duplicate overlapping scenes still active in the same location

---

## Final notes

This version is intended to be the stable **official v1.70** release line.

It focuses on:
- strong global traffic control
- working scene-based local traffic control
- clean in-menu access management

It does **not** include the future object/prop spawner in this release line.

