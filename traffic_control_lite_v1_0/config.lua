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

Config.PreferredIdentifierTypes = {
    'license:',
    'license2:',
    'fivem:',
    'discord:'
}
