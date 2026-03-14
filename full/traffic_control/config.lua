Config = {}

Config.MenuTitle = 'Traffic Management'
Config.MenuKey = 'F5'
Config.Notifications = true
Config.BroadcastGlobalChanges = false
Config.Debug = false

-- ACE bootstrap/runtime ACL
Config.AdminPrincipal = 'group.trafficcontroladmin'
Config.OperatorPrincipal = 'group.trafficcontroloperator'
Config.BootstrapIdentifiers = {
    'identifier.license:REPLACE_WITH_YOUR_LICENSE'
}
Config.DataFile = 'data/authorized_identifiers.json'

Config.Permissions = {
    menu = 'trafficcontrol.menu',
    global = 'trafficcontrol.global',
    localZone = 'trafficcontrol.local',
    manage = 'trafficcontrol.manage',
    admin = 'trafficcontrol.admin'
}

Config.DefaultMode = 'normal'
Config.Modes = {
    off = {
        vehicleDensity = 0.0,
        randomVehicleDensity = 0.0,
        parkedVehicleDensity = 0.0,
        pedDensity = 0.0,
        scenarioPedDensity = 0.0
    },
    low = {
        vehicleDensity = 0.25,
        randomVehicleDensity = 0.20,
        parkedVehicleDensity = 0.30,
        pedDensity = 0.40,
        scenarioPedDensity = 0.40
    },
    normal = {
        vehicleDensity = 1.0,
        randomVehicleDensity = 1.0,
        parkedVehicleDensity = 1.0,
        pedDensity = 1.0,
        scenarioPedDensity = 1.0
    },
    high = {
        vehicleDensity = 1.35,
        randomVehicleDensity = 1.25,
        parkedVehicleDensity = 1.20,
        pedDensity = 1.10,
        scenarioPedDensity = 1.10
    }
}

Config.SliderMin = 0.0
Config.SliderMax = 2.0
Config.SliderStep = 0.05

Config.LocalZoneMinRadius = 20.0
Config.LocalZoneMaxRadius = 250.0
Config.LocalZoneStep = 5.0
Config.LocalZoneDefaultRadius = 80.0

Config.SceneModes = {
    hard_closure = {
        label = 'Hard Closure',
        description = 'Blocks new ambient traffic and lets existing traffic clear out naturally. Best for drag racing and full road closures.',
        recommendation = 'Recommended: 60-120m for drag racing, 80-150m for full closures.',
        clearAmbient = true,
        roadBlock = true,
        pedScale = 0.0
    },
    soft_closure = {
        label = 'Soft Closure',
        description = 'Strongly reduces local ambient flow without making the world feel dead. Best for lane work and event control.',
        recommendation = 'Recommended: 40-80m for construction, 60-120m for event traffic.',
        clearAmbient = false,
        roadBlock = false,
        pedScale = 0.35
    },
    reduced_flow = {
        label = 'Reduced Flow',
        description = 'Light local suppression that keeps the area alive while calming traffic near the scene.',
        recommendation = 'Recommended: 80-150m for event perimeters and controlled slowdowns.',
        clearAmbient = false,
        roadBlock = false,
        pedScale = 0.65
    },
    ped_suppression = {
        label = 'Ped Suppression',
        description = 'Reduces pedestrian activity around a controlled scene.',
        recommendation = 'Recommended: 25-70m around start lines, crowd control, or emergency work.',
        clearAmbient = false,
        roadBlock = false,
        pedScale = 0.05
    }
}

Config.PreferredIdentifierTypes = {
    'license:',
    'license2:',
    'fivem:',
    'discord:'
}
