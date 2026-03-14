# traffic_control_lite v1.0

Creators: OpenAI & Polarbearr

`traffic_control_lite` is the global-only edition of the traffic framework.
It keeps the same overall menu feel and built-in user-management flow as the full v1.70 release, but removes local scene traffic control.

## Includes

- Global traffic presets: OFF, LOW, NORMAL, HIGH
- Custom density sliders
- In-menu user/access management
- Runtime ACE/ACL bootstrap flow
- Persistent authorized identifier storage in JSON
- Keyboard-open traffic menu

## Does not include

- Local traffic scenes
- Hard / soft closures
- Reduced-flow scene bubbles
- Ped-suppression scenes

## Folder name

After extracting, rename the folder to:

```text
traffic_control_lite
```

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

## Menu sections

- Global Traffic
- Access Management
- Refresh

## Commands

- `/traffic off`
- `/traffic low`
- `/traffic normal`
- `/traffic high`
- `/traffic status`
- `/traffic menu`
- `/trafficmenu`

## Notes

- Changes apply live with no restart.
- Global traffic is handled with density controls rather than blunt world cleanup.
- Notifications are actor-only by default unless `Config.BroadcastGlobalChanges` is enabled.
