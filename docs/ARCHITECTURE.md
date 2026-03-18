# Traffic Control Script — Architecture Deep Dive

This document provides a full technical breakdown of how the Traffic Control system works internally, including data flow, entity handling, and FiveM native usage.
---

## 1. What the script is

At a high level, this resource does two different jobs:

1. It gives authorized players an in-world **traffic management menu**.
2. It lets those players create and manage two classes of runtime state:
   - **Traffic scenes** that suppress or alter ambient traffic and peds in an area.
   - **Physical props** such as cones, barriers, work lights, warning lights, generators, rows, tapers, and multi-prop preset scenes.

The resource is therefore not just a prop placer. It is a combined:

- traffic-density controller,
- local scene suppressor,
- scene equipment deployment tool,
- preset scene deployment system,
- permissions and ACL manager.

---

## 2. Resource structure

The full resource is composed of these main files:

- `fxmanifest.lua`
- `config.lua`
- `client.lua`
- `server.lua`

### 2.1 `fxmanifest.lua`
This declares the resource metadata and load order.

It defines:

- `fx_version 'cerulean'`
- `game 'gta5'`
- `lua54 'yes'`
- shared script: `config.lua`
- server script: `server.lua`
- client script: `client.lua`

That means both client and server can read the same configuration values, but only the server executes authoritative scene and prop creation logic.

---

## 3. Core design philosophy

The script is built around a few core ideas:

### 3.1 Client previews, server placement
The client is responsible for showing the user what they are about to place.
The server is responsible for creating the real placed props that should persist for everyone.

That split is important because it means:

- previews can be lightweight and local,
- actual placed props are authoritative,
- other players receive synced state from the server,
- ownership and permissions can be enforced centrally.

### 3.2 Data-driven presets
Most placement logic is data-driven through `Config.PropPresets`, not hardcoded per scene.

This allows the script to support:

- single prop placement,
- repeated row placement,
- tapers,
- grouped preset rows,
- true multi-prop scenes via `layout` tables.

### 3.3 Orientation fixes are model-specific
GTA props are not all authored with the same “forward” direction. A cone can look fine with one heading, while a barrier or warning light can appear sideways or like a hurdle.

The script solves that through `Config.PropModelTuning`, which applies per-model corrections such as:

- `headingOffset`
- `spacingMultiplier`

This is one of the most important architectural pieces in the whole system.

---

## 4. Configuration breakdown (`config.lua`)

The config file acts as the declarative center of the resource.

### 4.1 Menu and UX configuration
These values control the basic user experience:

- `Config.MenuTitle`
- `Config.MenuKey`
- `Config.Notifications`
- `Config.Debug`

### 4.2 Prop placement limits and defaults
These values govern placement behavior:

- `Config.PropLimitPerPlayer`
- `Config.PropPlaceDistance`
- `Config.PropMoveStep`
- `Config.PropRotateStep`
- `Config.PreviewVerticalOffset`

These directly affect how the preview behaves when the user is rotating or moving a placement anchor.

### 4.3 Row placement settings
Rows are parameterized through:

- `Config.PropRowDefaultCount`
- `Config.PropRowMinCount`
- `Config.PropRowMaxCount`
- `Config.PropRowDefaultSpacing`
- `Config.PropRowMinSpacing`
- `Config.PropRowMaxSpacing`
- `Config.PropRowSpacingStep`
- `Config.PropRowDefaultAngle`
- `Config.PropRowMinAngle`
- `Config.PropRowMaxAngle`
- `Config.PropRowAngleStep`

These values power both manual row placement and row-like presets.

### 4.4 Model tuning
`Config.PropModelTuning` contains the special handling needed for props whose natural GTA axis is inconvenient for scene building.

Examples in the current config include:

- `prop_barrier_work05`
- `prop_barrier_work06a`
- `prop_mp_barrier_02b`
- `prop_worklight_03b`
- `prop_warninglight_01`

The currently used fields are:

#### `headingOffset`
Adds a correction to the final heading so the placed model visually faces the intended direction.

#### `spacingMultiplier`
Allows a model to effectively occupy more width than the nominal row spacing would suggest, useful for barriers.

### 4.5 Permission and ACL config
These settings define who can use what:

- `Config.AdminPrincipal`
- `Config.OperatorPrincipal`
- `Config.BootstrapIdentifiers`
- `Config.DataFile`
- `Config.Permissions`

This is used by the server ACL bootstrap logic to bind ACE permissions to stored identifiers.

### 4.6 Global traffic modes
`Config.Modes` defines named global density presets such as:

- `off`
- `low`
- `normal`
- `high`

Each contains:

- `vehicleDensity`
- `randomVehicleDensity`
- `parkedVehicleDensity`
- `pedDensity`
- `scenarioPedDensity`

These values are pushed every client frame to shape the ambient world.

### 4.7 Local traffic scene modes
`Config.SceneModes` defines local suppression profiles:

- `hard_closure`
- `soft_closure`
- `reduced_flow`
- `ped_suppression`

Each mode includes metadata and runtime behavior flags such as:

- `label`
- `description`
- `recommendation`
- `clearAmbient`
- `roadBlock`
- `pedScale`

This drives how local scenes manipulate nearby traffic and pedestrians.

### 4.8 Prop catalog
`Config.Props` is the source catalog for the manual placement menu.

Current categories include:

- `cones`
- `barriers`
- `lights`

Each category holds entries like:

```lua
{ label = 'Small Cone', model = 'prop_roadcone02a' }
```

These definitions are later referenced when starting a preview or converting presets back into source props.

### 4.9 Prop presets
`Config.PropPresets` is the core of the grouped scene and row preset system.

The script currently supports two preset families:

#### Row-style presets
These define repeated placement with a single model:

- `group`
- `label`
- `model`
- `count`
- `spacing`
- `direction`
- `angle`
- `anchor`

Examples:

- 3 Cone Line
- Left Cone Taper (5)
- 5 Barrier Wall (Work 05)
- 3 Warning Lights

#### Multi-prop scene presets
These define `layout` tables with per-piece offsets:

- `group`
- `label`
- `description`
- `anchor`
- `layout`

Each `layout` piece contains:

- `model`
- `forwardOffset`
- `lateralOffset`
- `headingOffset`

Examples:

- Drag Strip Markers (1/8 Mile)
- Shoulder Work Pack
- Mini Road Closure

---

## 5. Client-side architecture (`client.lua`)

The client script handles five major responsibilities:

1. local state caching,
2. UI and input,
3. ambient traffic suppression application,
4. preview entity management,
5. sending authoritative placement requests to the server.

---

## 6. Client state model

The client maintains several major local state tables.

### 6.1 `state`
This mirrors server-synced world state:

- current global traffic mode,
- optional custom density values,
- active scenes,
- actor name,
- placed props.

### 6.2 `permissions`
This stores the client’s current permission payload from the server:

- `hasAccess`
- `isAdmin`
- `menu`
- `global`
- `localZone`
- `manage`
- `admin`

### 6.3 Preview state
Preview behavior is controlled by these variables:

- `previewProps`
- `previewPropModels`
- `previewModelHash`
- `previewLayoutPieces`
- `previewAnchor`
- `previewCategory`
- `previewIndex`
- `previewDistance`
- `previewHeading`

These are the temporary, client-only representations of what the user is aiming and rotating.

### 6.4 Draft / working menu state
The menu writes into a draft layer before the user confirms anything:

- `sceneModeDraft`
- `localRadiusDraft`
- `customDraft`
- `propPlacementTypeDraft`
- `propRowCountDraft`
- `propRowSpacingDraft`
- `propRowDirectionDraft`
- `propRowAngleDraft`
- `propAnchorModeDraft`
- `propHeadingOffsetDraft`
- `propPatternAnchorModeDraft`

This is what allows the menu to feel interactive without immediately touching live world state.

---

## 7. Notification system

The `notify` helper uses GTA feed notifications to display messages.

### Native used
#### `BeginTextCommandThefeedPost`
Begins construction of a feed notification.

#### `AddTextComponentSubstringPlayerName`
Adds the message body.

#### `EndTextCommandThefeedPostTicker`
Displays the result in the feed.

This is used throughout the script for access denials, placement confirmations, and errors.

---

## 8. Global traffic control loop

### 8.1 Function: `applyGlobalTraffic`
Every frame, the client calculates the active global settings using either:

- the selected named mode from `Config.Modes`, or
- the current custom density override.

It then applies those values using these natives:

#### `SetVehicleDensityMultiplierThisFrame`
Controls density of regular road vehicles for the current frame.

#### `SetRandomVehicleDensityMultiplierThisFrame`
Controls density of randomly generated traffic.

#### `SetParkedVehicleDensityMultiplierThisFrame`
Controls parked vehicle density.

#### `SetPedDensityMultiplierThisFrame`
Controls pedestrian density.

#### `SetScenarioPedDensityMultiplierThisFrame`
Controls scenario-based peds such as world ambient scripted behavior.

These natives are frame-based, so they must be called continuously in a loop.

---

## 9. Local scene suppression system

### 9.1 Scene concept
A “scene” is a radius-based local traffic control zone centered at the location where a player created it.

The client receives active scenes from the server and applies suppression when the player is near enough.

### 9.2 Function: `suppressScene(scene)`
This is the runtime heart of the local traffic system.

It first:

- reads the mode data from `Config.SceneModes`,
- checks the local player’s distance from the scene,
- early-outs if the player is far away.

If the player is close enough, it may do some or all of the following.

#### A. Temporarily block roads in the area
If the scene mode has `roadBlock = true`, the client uses:

##### `SetRoadsInArea`
Temporarily disables roads within a volume.

##### `RemoveVehiclesFromGeneratorsInArea`
Stops nearby generator-spawned traffic from continuing to create vehicles in the blocked region.

#### B. Reduce local density further
Within an inner activation radius, it reapplies reduced density multipliers using the same frame-based density natives listed above.

#### C. Delete slow ambient AI vehicles for hard closures
If `clearAmbient = true`, the client scans all vehicles from:

##### `GetGamePool('CVehicle')`
Returns all vehicle entities currently in the game pool.

Each vehicle is checked with helper logic to ensure it is ambient AI, not player-driven or network-owned.

Relevant natives used in that filtering include:

##### `GetVehicleModelNumberOfSeats`
Used to loop seats.

##### `GetPedInVehicleSeat`
Gets seat occupants.

##### `IsPedAPlayer`
Distinguishes player occupants from NPCs.

##### `NetworkGetEntityIsNetworked`
Rejects networked vehicles from ambient cleanup.

##### `GetEntitySpeed`
Checks whether an ambient AI vehicle is moving slowly enough to be safely deleted.

If a vehicle is a suitable ambient AI target, the script calls:

##### `SetEntityAsMissionEntity`
Takes control of the entity.

##### `DeleteVehicle`
Removes the ambient vehicle from the world.

### 9.3 Scene cleanup
When a scene disappears from synced state, the client calls `restoreSceneRoads(scene)`.

That uses:

#### `SetRoadsBackToOriginal`
Restores the original road state in the previously blocked volume.

This is what prevents blocked roads from staying broken after scene removal.

---

## 10. Prop definition and tuning helpers

### 10.1 `propDefinition(category, index)`
Looks up an entry inside `Config.Props`.

This is how the script resolves a menu choice into the base model data.

### 10.2 `modelTuningFor(model)`
Looks up per-model tuning in `Config.PropModelTuning`.

It accepts either:

- a model hash, or
- a model string.

It resolves strings using `joaat(model)` and then checks both keyed forms.

This helper is referenced during preview orientation and spacing-sensitive placement logic.

---

## 11. Grouped preset menu logic

### 11.1 `presetGroupNames()`
Builds a deduplicated list of preset groups from `Config.PropPresets`, defaults missing groups to `Other`, and sorts them alphabetically.

### 11.2 `presetsByGroup(groupName)`
Returns all presets belonging to a given group.

This is what powers the grouped preset scene menu introduced in 2.2.

---

## 12. Preview lifecycle

The preview system is one of the most important parts of the resource.

### 12.1 Why previews are local
Preview entities are created on the client only. They are not the “real” placed props.

That means the player can:

- rotate them,
- change spacing,
- switch rows and presets,
- cancel placement,

without affecting the world for anyone else.

### 12.2 `stopPreview()`
This deletes all preview entities and resets all preview-tracking variables.

Relevant native:

#### `DeleteEntity`
Used to delete preview entities.

### 12.3 `ensurePreviewProps(model)`
This function ensures the correct number of preview entities exist for the current placement mode.

Behavior:

- if the preview already matches the desired model and count, it reuses it,
- otherwise it deletes the old preview props and rebuilds them.

Entities are created using:

#### `CreateObjectNoOffset`
Creates an object at exact coordinates without automatic coordinate adjustment.

The preview then applies:

#### `SetEntityCollision(ent, false, false)`
Disables collision so the preview does not interfere with the player or scene.

#### `SetEntityAlpha(ent, 180, false)`
Makes the preview semi-transparent.

#### `PlaceObjectOnGroundProperly`
Drops the preview to a sensible ground surface.

#### `FreezeEntityPosition(ent, true)`
Prevents movement and physics drift.

### 12.4 `startPreview(category, index, anchorMode)`
This begins a single-model preview.

It:

1. clears any old preview,
2. resolves the prop definition from `Config.Props`,
3. loads the model with `RequestModel`,
4. waits until `HasModelLoaded` succeeds or times out,
5. builds the preview objects via `ensurePreviewProps`,
6. initializes preview heading from player heading,
7. stores the selected category and index.

Relevant natives used here:

#### `RequestModel`
Requests the model into memory.

#### `HasModelLoaded`
Checks whether model loading has completed.

#### `GetGameTimer`
Used for a simple timeout loop.

#### `GetEntityHeading`
Initializes preview heading from the player’s current facing.

### 12.5 `ensureLayoutPreviewProps(pieces)`
This is similar to `ensurePreviewProps`, but for multi-prop scene layouts where each piece can have a different model.

Instead of creating repeated copies of one model, it loops `pieces`, loads each piece model independently, and creates one preview entity per layout entry.

### 12.6 `startLayoutPreview(preset)`
Starts preview for a true multi-prop preset scene.

It:

- validates that `preset.layout` exists,
- creates per-piece preview entities,
- deep-copies the layout into `previewLayoutPieces`,
- initializes heading and anchor mode.

This is how multi-prop scenes become first-class citizens in the same preview system.

---

## 13. Preview positioning math

### 13.1 Anchor point
Every preview is built around an anchor point projected in front of the player.

The script computes this using:

#### `GetEntityCoords(PlayerPedId())`
Gets current player coordinates.

#### `GetEntityForwardVector(ped)`
Gets the player’s forward vector.

The anchor becomes:

- current player position
- plus forward vector times `previewDistance`

So the player is effectively aiming a scene placement point in front of themselves.

### 13.2 Ground snapping
The script attempts to place the preview anchor on the ground using:

#### `GetGroundZFor_3dCoord`
Resolves the ground Z at the target point.

If a ground value is found, the preview anchor Z is updated.

### 13.3 Layout scenes: forward and lateral offsets
For multi-prop layouts, the script converts each piece’s:

- `forwardOffset`
- `lateralOffset`

into world-space coordinates using the current `previewHeading`.

Internally it derives heading vectors with standard trigonometry:

- forward axis from heading,
- right axis from heading.

Then it computes:

- anchor + forwardOffset * forwardVector
- plus lateralOffset * rightVector

This is why the whole scene rotates as one rigid layout.

### 13.4 Row placement math
For regular rows, the script uses:

- row count,
- row spacing,
- row direction,
- row angle,
- anchor mode.

`currentRowBaseAngle()` determines the effective angle by starting from `previewHeading` and then applying:

- +90 degrees if the row is sideways,
- plus any explicit row angle.

Then it computes row direction vectors with `math.sin` and `math.cos`.

### 13.5 Centered vs start anchoring
The row preview can anchor in two ways.

#### Centered anchor
The row is centered around the anchor point.

#### Start anchor
The first element begins at the anchor and all others extend forward from there.

This is controlled by the `propPatternAnchorModeDraft` and preset `anchor` values.

---

## 14. Final preview heading calculation

Heading is not simply “player heading.”

For correct visuals, the script combines multiple heading layers.

### 14.1 Layout scenes
For a layout piece, final preview heading is:

- `previewHeading`
- plus the piece’s own `headingOffset`
- plus the model tuning `headingOffset`

This is the line that makes mixed scenes practical, because it supports both:

- scene-level rotation,
- per-piece local rotation,
- per-model correction.

### 14.2 Row scenes
For repeated rows, final preview heading is:

- `currentRowBaseAngle()`
- plus model tuning heading offset,
- plus `propHeadingOffsetDraft`

This is how barriers and lights can be displayed correctly in rows and tapers.

---

## 15. Placement confirmation and transfer to server

### 15.1 `buildPlacementPoints()`
When the user confirms placement, the client does **not** recalculate the layout from scratch.

Instead, it reads the actual world transform of the preview entities using:

#### `GetEntityCoords(ent)`
Gets the final world coordinates of each preview prop.

#### `GetEntityHeading(ent)`
Gets the final heading currently applied to each preview prop.

It packs these into a `placements` table like:

- `model`
- `x`
- `y`
- `z`
- `heading`

This design is extremely important because it means the server receives fully baked world placements, not just abstract parameters. That keeps the server placement path simple and makes preview and final placement match closely.

### 15.2 `confirmPreview()`
This sends placement to the server through the event:

- `traffic_control:placeProp`

It passes:

- a model marker,
- anchor coords,
- heading,
- placement type,
- row settings,
- and the final `placements` array.

If the preview was a layout, the placement type is effectively treated as a placement batch. If it was a standard row or single object, the same event can still handle it.

After sending the request, the client clears the preview and reopens or closes the menu as needed.

### 15.3 Native used to communicate
#### `TriggerServerEvent`
Used to send all authoritative state-change requests from client to server.

---

## 16. Menu and input system

The menu is implemented manually in `client.lua` rather than through an external UI framework.

### 16.1 Rendering
The script uses draw natives such as:

#### `DrawRect`
Draws menu panels and row backgrounds.

#### `BeginTextCommandDisplayText`
Starts a text draw call.

#### `EndTextCommandDisplayText`
Finishes drawing text.

#### `SetTextFont`
#### `SetTextScale`
#### `SetTextColour`
#### `SetTextJustification`
#### `SetTextWrap`
#### `SetTextOutline`
#### `SetTextDropshadow`
Used for text appearance and layout.

### 16.2 Input suppression
When the menu or preview is active, the script blocks conflicting gameplay controls with:

#### `DisableAllControlActions`
#### `DisableControlAction`
#### `EnableControlAction`
#### `DisablePlayerFiring`

This prevents the player from accidentally shooting, entering vehicles, or triggering unrelated game actions while navigating the menu or placing props.

### 16.3 Menu opening
The script registers:

#### `RegisterCommand('+trafficmenu', ...)`
#### `RegisterCommand('-trafficmenu', ...)`
#### `RegisterKeyMapping`

That means the menu can be opened through a keybind, defaulting to the configured key.

---

## 17. Applying presets

### 17.1 `applyPropPreset(preset)`
This function is the gateway from a menu-selected preset into the live preview system.

It distinguishes two preset categories.

#### A. True layout preset
If `preset.layout` exists and has entries:

- `propPlacementTypeDraft` becomes `layout`
- `propRowCountDraft` is set to layout piece count
- preview starts through `startLayoutPreview(preset)`

#### B. Row-style preset
If there is no layout:

- placement type is taken from the preset or defaults to row,
- count, spacing, direction, angle, anchor, and heading offset are loaded,
- the preset’s model is resolved back into `Config.Props` via category and index,
- preview starts through `startPreview(category, index, anchorMode)`

The fallback lookup by model string is how presets remain reusable even if they do not explicitly specify a category/index pair.

---

## 18. Client-side synced prop cleanup

The client receives a list of placed props from the server. When server state changes, removed props need to be reflected locally.

### 18.1 `findClosestWorldObjectForProp(prop)`
This attempts to find the closest object in the client world matching the expected model hash and location.

It scans:

#### `GetGamePool('CObject')`
Returns client-known object entities.

It compares:

- model hash,
- distance to stored coordinates.

### 18.2 `cleanupRemovedProp(removedProp)`
If a prop vanishes from synced state, this function attempts to delete the corresponding world object on the client side.

Relevant natives:

- `DoesEntityExist`
- `DeleteObject`
- `DeleteEntity`

This helps keep client world state tidy when server props are removed.

---

## 19. Client event handlers

The client subscribes to several server-originated events.

### 19.1 `traffic_control:setState`
Receives authoritative synced world state:

- global mode,
- custom traffic values,
- scenes,
- props.

It also compares old scenes and props to new ones, restoring roads and cleaning removed props when necessary.

### 19.2 `traffic_control:updatePlayerList`
Receives the player list used for access management UI.

### 19.3 `traffic_control:setPermissions`
Receives the current permission payload for the local player.

### 19.4 `traffic_control:openMenu`
Opens the menu if the local player is authorized.

### 19.5 Death handlers
The script listens for:

- `baseevents:onPlayerDied`
- `baseevents:onPlayerKilled`

and force-closes the UI and preview when the player is no longer in a valid interaction state.

---

## 20. Main client thread

The script runs its core per-frame logic in a `CreateThread` loop.

### Native used
#### `CreateThread`
Creates a long-lived client thread.

#### `Wait(0)`
Yields to the next frame while still running effectively every frame.

### Responsibilities of this loop
Every frame it:

1. applies global traffic density,
2. checks whether the player is available,
3. applies local scene suppression for each active scene,
4. updates preview entities if preview is active,
5. handles preview input,
6. otherwise draws the menu and handles menu navigation.

This loop is the central runtime orchestrator of the client script.

---

## 21. Server-side architecture (`server.lua`)

The server script is authoritative for:

- permission assignment and persistence,
- scene creation/removal,
- prop creation/removal,
- state synchronization to clients.

---

## 22. Server state model

The server stores:

### 22.1 `globalState`
Contains:

- current global mode,
- optional custom density values,
- actor name.

### 22.2 `scenes`
A map of all active local traffic scenes keyed by scene ID.

### 22.3 `props`
A map of all placed props keyed by prop ID.

Each prop record stores:

- id,
- model,
- x, y, z,
- heading,
- owner identifier,
- owner name,
- entity handle.

### 22.4 `authData`
Persistent access-control data with:

- `admins`
- `operators`

This data is read from and saved to the JSON file configured by `Config.DataFile`.

---

## 23. ACL and access control system

This resource has a real access model rather than a single “everyone can use it” toggle.

### 23.1 Reading and writing the auth file
The server uses:

#### `LoadResourceFile`
Reads the authorization JSON.

#### `SaveResourceFile`
Writes the JSON back to disk.

### 23.2 ACE wiring
The script applies runtime ACE rules through:

#### `ExecuteCommand`
Used to run:

- `add_ace`
- `add_principal`
- `remove_principal`

This lets the script bootstrap and persist operator/admin access without hardcoding every player into server.cfg.

### 23.3 Player identifier resolution
`getPreferredIdentifier(source)` inspects the player’s identifiers using:

#### `GetPlayerIdentifiers`
Returns all identifiers for a player.

It prioritizes prefixes from `Config.PreferredIdentifierTypes` and returns a normalized principal such as:

- `identifier.license:...`

### 23.4 Permission checks
`playerHas(source, ace)` uses:

#### `IsPlayerAceAllowed`
This is the central gate for every protected event and command.

### 23.5 Permission payloads
The server builds a compact permissions table and sends it to the client through `traffic_control:setPermissions`.

This lets the client hide or show features without trusting the client to make access decisions.

---

## 24. Server prop creation and persistence model

### 24.1 `createOwnedProp(...)`
This is the canonical constructor for a placed prop record.

It:

1. allocates a new prop ID,
2. stores owner and transform data,
3. inserts the record into `props`,
4. calls `createServerProp(prop)`.

### 24.2 `createServerProp(prop)`
This is where a real placed object is spawned on the server.

It uses:

#### `CreateObjectNoOffset`
Creates a networked server-side object at exact coordinates.

The current code passes it in networked mode so the object exists for all clients.

Then it applies:

#### `SetEntityHeading`
Applies the final stored heading.

#### `SetEntityOrphanMode`
When available, this is set to `2` so the object persists more safely independent of original ownership conditions.

After spawning, the script re-reads object coordinates using:

#### `GetEntityCoords`
This lets the stored prop position reflect the object’s settled location more accurately.

### 24.3 `destroyServerProp(prop)`
If the object exists, the server removes it using:

#### `DeleteEntity`
This deletes the networked object.

---

## 25. Server placement paths

The server has three practical placement modes.

### 25.1 Single prop placement
The simplest path. One prop is created with one world position and one heading.

### 25.2 Row placement
`placePropRow(...)` computes a row from abstract row parameters.

It calculates:

- a base angle from heading and direction,
- row direction vectors from trigonometry,
- centered row offsets,
- per-piece positions.

It then calls `createOwnedProp` for each row element.

This server row path is used when the placement request does not include explicit precomputed placements.

### 25.3 Explicit placement batches / layouts
`placePropPoints(...)` is the most flexible path.

It takes precomputed placement records and simply creates each one using the world-space coordinates and heading the client already baked.

This is what makes multi-prop layout scenes straightforward on the server side. The server does not need to know layout geometry; it just trusts the authorized client preview result after validating limits and permissions.

---

## 26. Prop limit enforcement

The server enforces per-player prop ownership limits in `traffic_control:placeProp`.

It:

1. counts how many props the requesting player already owns,
2. determines how many new props the request would add,
3. compares total against `Config.PropLimitPerPlayer`,
4. rejects placement if it would exceed the limit.

This is critical because the client preview can show anything, but the server remains authoritative about what can actually be spawned.

---

## 27. State synchronization

### 27.1 `sceneList()` and `propList()`
These convert internal maps into sorted arrays so the client receives deterministic state order.

### 27.2 `syncState(actorName)`
Pushes the authoritative world state to all clients using:

#### `TriggerClientEvent('traffic_control:setState', -1, payload)`

This is called after:

- global mode changes,
- custom density updates,
- scene creation/removal,
- prop placement/removal,
- scene clearing,
- prop clearing.

This keeps every client’s local scene and prop cache aligned with the server.

---

## 28. Scene creation and management events

### 28.1 `traffic_control:createScene`
The server validates access, gets the player’s current position, clamps the radius, and creates a scene record.

Relevant natives:

#### `GetPlayerPed`
Gets the source player’s ped.

#### `GetEntityCoords`
Gets the player’s current world position.

The scene is then stored and synchronized to everyone.

### 28.2 `traffic_control:removeScene`
Removes a scene by ID if the caller is authorized to manage it.

### 28.3 `traffic_control:clearMyScenes`
Removes all scenes owned by the caller, or all manageable scenes if the caller has management rights.

---

## 29. Prop removal events

### 29.1 `traffic_control:removeNearestProp`
This finds the closest removable prop within a threshold and deletes it.

The server determines distance from the player by using:

- `GetPlayerPed`
- `GetEntityCoords`
- and, if the prop entity exists, the entity’s actual coordinates rather than stale stored coordinates.

This is a nice detail because it improves removal accuracy if a prop settled slightly differently after spawning.

### 29.2 `traffic_control:clearMyProps`
Deletes all props owned by the caller, or all manageable props if the player has elevated access.

---

## 30. Access administration events

The server includes runtime tools for granting and revoking access by player ID.

### 30.1 `traffic_control:grantByPlayerId`
Finds the target player’s preferred identifier and adds them as either:

- admin, or
- operator

It updates ACLs immediately, saves the JSON data file, rebuilds the player list, and refreshes the target player’s permissions.

### 30.2 `traffic_control:revokeByPlayerId`
Removes admin or operator access and rewrites ACL/persistence state in the opposite direction.

This is how the script supports live access administration rather than requiring a server restart.

---

## 31. Commands

The server registers:

### `trafficmenu`
Opens the client UI if the caller has menu access.

### `traffic`
Supports subcommands like:

- `status`
- `menu`
- named global presets such as `off`, `low`, `normal`, `high`

The command path is permission-gated on the server.

The client separately registers the keymapped `+trafficmenu` command for direct menu toggling.

---

## 32. Resource lifecycle behavior

### 32.1 On resource start (server)
The server:

- reads the auth data file,
- reapplies stored ACLs,
- ensures base ACEs are configured.

### 32.2 On resource stop (server)
The server deletes all server-spawned props.

This prevents abandoned objects from lingering after the resource is stopped.

### 32.3 On resource stop (client)
The client:

- clears preview entities,
- restores roads for active scenes.

This is important cleanup behavior so local scene suppression does not survive shutdown on the client.

---

## 33. Important implementation details and nuances

### 33.1 Why previews read back actual entity transforms
The script does not trust its own preview math at confirm time as a purely theoretical layout. Instead, it reads back the actual preview entity coordinates and headings.

That means the final server placement mirrors what the player truly saw, including:

- ground snapping,
- model heading corrections,
- layout-specific heading offsets.

That is a smart and robust design choice.

### 33.2 Why model tuning matters so much
Without model tuning:

- barriers in rows can look like hurdles,
- warning lights can face the wrong way,
- tapers can visually break despite mathematically correct spacing.

By separating this into `Config.PropModelTuning`, the script avoids baking fragile fixes into every preset.

### 33.3 Why the system scales well
The script scales because it uses a layered approach:

- base prop catalog,
- row parameterization,
- grouped presets,
- explicit layout scenes,
- model correction layer,
- authoritative server placement.

That makes it easy to add more presets without rewriting the placement engine.

### 33.4 Why some state exists both client-side and server-side
Client-side state exists for:

- UX,
- preview rendering,
- local menu interaction.

Server-side state exists for:

- authority,
- synchronization,
- persistence during runtime,
- ownership and permissions.

That split is essential in FiveM resources that mix world objects and user interaction.

---

## 34. Exact native inventory by purpose

Below is a consolidated native breakdown based on the current full resource.

### 34.1 Client-side world and entity natives
- `CreateObjectNoOffset`
- `DeleteEntity`
- `DeleteObject`
- `DeleteVehicle`
- `DoesEntityExist`
- `FreezeEntityPosition`
- `GetEntityCoords`
- `GetEntityForwardVector`
- `GetEntityHeading`
- `GetEntityModel`
- `GetEntitySpeed`
- `GetGroundZFor_3dCoord`
- `PlaceObjectOnGroundProperly`
- `SetEntityAlpha`
- `SetEntityAsMissionEntity`
- `SetEntityCollision`
- `SetEntityCoordsNoOffset`
- `SetEntityHeading`

### 34.2 Client-side population and road natives
- `RemoveVehiclesFromGeneratorsInArea`
- `SetParkedVehicleDensityMultiplierThisFrame`
- `SetPedDensityMultiplierThisFrame`
- `SetRandomVehicleDensityMultiplierThisFrame`
- `SetRoadsBackToOriginal`
- `SetRoadsInArea`
- `SetScenarioPedDensityMultiplierThisFrame`
- `SetVehicleDensityMultiplierThisFrame`

### 34.3 Client-side pool and ped/vehicle inspection natives
- `GetGamePool`
- `GetPedInVehicleSeat`
- `GetVehicleModelNumberOfSeats`
- `IsPedAPlayer`
- `IsPedFatallyInjured`
- `IsEntityDead`
- `NetworkGetEntityIsNetworked`
- `PlayerPedId`

### 34.4 Client-side model loading natives
- `RequestModel`
- `HasModelLoaded`
- `GetGameTimer`

### 34.5 Client-side UI and input natives
- `BeginTextCommandDisplayText`
- `BeginTextCommandThefeedPost`
- `AddTextComponentSubstringPlayerName`
- `DrawRect`
- `EndTextCommandDisplayText`
- `EndTextCommandThefeedPostTicker`
- `SetTextColour`
- `SetTextDropshadow`
- `SetTextFont`
- `SetTextJustification`
- `SetTextOutline`
- `SetTextScale`
- `SetTextWrap`
- `DisableAllControlActions`
- `DisableControlAction`
- `DisablePlayerFiring`
- `EnableControlAction`
- `IsControlJustPressed`
- `IsDisabledControlJustPressed`

### 34.6 Client-side runtime and networking primitives
- `CreateThread`
- `Wait`
- `RegisterCommand`
- `RegisterKeyMapping`
- `RegisterNetEvent`
- `TriggerServerEvent`
- `AddEventHandler`

### 34.7 Server-side file and ACL natives
- `LoadResourceFile`
- `SaveResourceFile`
- `ExecuteCommand`
- `IsPlayerAceAllowed`
- `GetPlayerIdentifiers`

### 34.8 Server-side player and networking natives
- `GetPlayerName`
- `GetPlayers`
- `GetPlayerPed`
- `TriggerClientEvent`
- `RegisterNetEvent`
- `RegisterCommand`
- `SetTimeout`
- `AddEventHandler`

### 34.9 Server-side object/entity natives
- `CreateObjectNoOffset`
- `DeleteEntity`
- `DoesEntityExist`
- `GetEntityCoords`
- `SetEntityHeading`
- `SetEntityOrphanMode`

---

## 35. End-to-end example: placing a multi-prop drag preset

This is the best way to understand the full flow.

### Step 1: User opens menu
The client opens the custom draw-based menu through the keymapping or command.

### Step 2: User selects a grouped preset
The preset is resolved from `Config.PropPresets`.

### Step 3: `applyPropPreset` sees a `layout`
Because the drag preset has a `layout`, the client enters layout preview mode.

### Step 4: Client loads all piece models
Each piece is loaded with `RequestModel` and checked with `HasModelLoaded`.

### Step 5: Preview entities are created
One preview object per layout piece is created with `CreateObjectNoOffset`, collision disabled, alpha reduced, and frozen.

### Step 6: Preview loop positions them every frame
The anchor point is projected in front of the player. Each piece’s forward and lateral offsets are rotated into world coordinates. Each piece heading becomes:

- previewHeading,
- plus piece heading offset,
- plus model tuning heading offset.

### Step 7: Player rotates until aligned
Input changes `previewHeading` in very fine increments according to `Config.PropRotateStep`.

### Step 8: User confirms
The client reads actual preview entity transforms and builds the final placement list.

### Step 9: Client sends placement batch to server
A `TriggerServerEvent('traffic_control:placeProp', ...)` call sends the baked placements.

### Step 10: Server validates limit and ownership
The server counts the player’s currently owned props and ensures the new scene does not exceed the prop cap.

### Step 11: Server spawns real networked objects
For each placement record, the server creates a real object, applies heading, records its owner, and stores it in the authoritative prop table.

### Step 12: Server syncs state to all clients
All clients receive the updated prop list through `traffic_control:setState`.

That is the full life cycle from menu selection to shared world object deployment.

---

## 36. Practical extension points

If you want to extend the script further, these are the cleanest insertion points.

### Add more props
Edit `Config.Props`.

### Add more row presets
Add entries to `Config.PropPresets` that use:

- `model`
- `count`
- `spacing`
- `direction`
- `angle`

### Add more multi-prop scenes
Add entries to `Config.PropPresets` with a `layout` array.

### Correct strange model orientations
Add or adjust `Config.PropModelTuning[model].headingOffset`.

### Increase deployment capacity
Raise `Config.PropLimitPerPlayer`.

### Add persistence across server restarts
The current script persists access-control data, but not active scene/prop world state. That could be added on the server side by serializing `scenes` and `props` and reconstructing them on startup.

---

## 37. Known architectural boundaries

A few things are worth calling out clearly.

### 37.1 Active props are authoritative only for the current runtime
The current script does not appear to serialize active props or active scenes to disk for restart persistence.

### 37.2 Preview is client-local by design
Other players do not see what you are previewing until placement is confirmed.

### 37.3 The client does a lot of visual computation
This is appropriate for the use case, but it means placement feel is heavily dependent on the local preview loop and control handling.

### 37.4 State sync is broad, not delta-based
The server currently pushes full scene and prop lists to clients when state changes. That is simple and reliable, though not as bandwidth-efficient as fine-grained delta replication.

---

## 38. Summary

The Traffic Control Script is a layered FiveM traffic and scene deployment framework built around:

- client-side previews,
- server-side authoritative placement,
- config-driven prop catalogs,
- grouped row presets,
- multi-prop layout scenes,
- per-model orientation tuning,
- ACE-based permissions,
- frame-by-frame ambient traffic suppression.

The core reason it works well is that it treats placement as a pipeline:

1. choose data,
2. preview locally,
3. bake exact transforms,
4. validate server-side,
5. spawn authoritative objects,
6. sync world state to everyone.

That makes it both practical for roleplay/event use and flexible enough to keep growing.

---

## 39. Suggested filename

A good filename for this document in the repo would be:

- `ARCHITECTURE.md`
- `DEVELOPER_GUIDE.md`
- `SCRIPT_BREAKDOWN.md`

If you want it to live under a docs folder, a clean path would be:

- `docs/ARCHITECTURE.md`

---

## Author note

This document was written to reflect the structure and behavior of the current full Traffic Control Script package at the time of the 2.2 release preparation.
