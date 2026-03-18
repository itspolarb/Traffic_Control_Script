Config = {}

Config.MenuTitle = 'Traffic Management'
Config.MenuKey = 'F5'
Config.Notifications = true
Config.BroadcastGlobalChanges = false
Config.Debug = false
Config.PropLimitPerPlayer = 20

Config.PropRowDefaultCount = 5
Config.PropRowMinCount = 2
Config.PropRowMaxCount = 10
Config.PropRowDefaultSpacing = 2.5
Config.PropRowMinSpacing = 0.5
Config.PropRowMaxSpacing = 10.0
Config.PropRowSpacingStep = 0.25

Config.PropRowDefaultAngle = 0.0
Config.PropRowMinAngle = -180.0
Config.PropRowMaxAngle = 180.0
Config.PropRowAngleStep = 0.1

Config.PropModelTuning = {
    prop_barrier_work05 = {
        spacingMultiplier = 1.35,
        headingOffset = 90.0
    },
    prop_barrier_work06a = {
        spacingMultiplier = 1.35,
        headingOffset = 90.0
    },
    prop_mp_barrier_02b = {
        spacingMultiplier = 1.20,
        headingOffset = 90.0
    },
    prop_worklight_03b = {
        headingOffset = 90.0
    },
    prop_warninglight_01 = {
        headingOffset = 90.0
    }
}

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

-- Basic prop placement config
Config.PropPlaceDistance = 3.0
Config.PropMoveStep = 0.10
Config.PropRotateStep = 0.1
Config.PreviewVerticalOffset = 0.0

Config.Props = {
    cones = {
        { label = 'Small Cone', model = 'prop_roadcone02a' },
        { label = 'Large Cone', model = 'prop_mp_cone_04' }
    },
    barriers = {
        { label = 'Work Barrier 05', model = 'prop_barrier_work05' },
        { label = 'Work Barrier 06A', model = 'prop_barrier_work06a' },
        { label = 'MP Barrier', model = 'prop_mp_barrier_02b' }
    },
    lights = {
        { label = 'Work Light', model = 'prop_worklight_03b' },
        { label = 'Warning Light', model = 'prop_warninglight_01' },
        { label = 'Generator', model = 'prop_generator_03b' }
    }
}


Config.PropPresets = {
    {
        group = 'Cone Layouts',
        label = '3 Cone Line',
        model = 'prop_roadcone02a',
        count = 3,
        spacing = 2.0,
        direction = 'forward',
        angle = 0.0,
        anchor = 'center'
    },
    {
        group = 'Cone Layouts',
        label = '5 Cone Lane',
        model = 'prop_roadcone02a',
        count = 5,
        spacing = 2.5,
        direction = 'forward',
        angle = 0.0,
        anchor = 'center'
    },
    {
        group = 'Cone Layouts',
        label = '10 Cone Shoulder',
        model = 'prop_roadcone02a',
        count = 10,
        spacing = 2.5,
        direction = 'forward',
        angle = 0.0,
        anchor = 'center'
    },
    {
        group = 'Cone Tapers',
        label = 'Left Cone Taper (5)',
        model = 'prop_roadcone02a',
        count = 5,
        spacing = 2.5,
        direction = 'forward',
        angle = -15.0,
        anchor = 'center'
    },
    {
        group = 'Cone Tapers',
        label = 'Right Cone Taper (5)',
        model = 'prop_roadcone02a',
        count = 5,
        spacing = 2.5,
        direction = 'forward',
        angle = 15.0,
        anchor = 'center'
    },

    {
        group = 'Barrier Walls',
        label = '3 Barrier Wall (Work 05)',
        model = 'prop_barrier_work05',
        count = 3,
        spacing = 2.5,
        direction = 'sideways',
        angle = 0.0,
        anchor = 'center'
    },
    {
        group = 'Barrier Walls',
        label = '5 Barrier Wall (Work 05)',
        model = 'prop_barrier_work05',
        count = 5,
        spacing = 2.5,
        direction = 'sideways',
        angle = 0.0,
        anchor = 'center'
    },
    {
        group = 'Barrier Tapers',
        label = 'Left Barrier Sweep (5)',
        model = 'prop_barrier_work05',
        count = 5,
        spacing = 2.5,
        direction = 'sideways',
        angle = -15.0,
        anchor = 'center'
    },
    {
        group = 'Barrier Tapers',
        label = 'Right Barrier Sweep (5)',
        model = 'prop_barrier_work05',
        count = 5,
        spacing = 2.5,
        direction = 'sideways',
        angle = 15.0,
        anchor = 'center'
    },

    {
        group = 'Barrier Walls',
        label = '3 Barrier Wall (Work 06A)',
        model = 'prop_barrier_work06a',
        count = 3,
        spacing = 2.5,
        direction = 'sideways',
        angle = 0.0,
        anchor = 'center'
    },
    {
        group = 'Barrier Walls',
        label = '5 Barrier Wall (Work 06A)',
        model = 'prop_barrier_work06a',
        count = 5,
        spacing = 2.5,
        direction = 'sideways',
        angle = 0.0,
        anchor = 'center'
    },
    {
        group = 'Barrier Tapers',
        label = 'Left 06A Barrier Sweep (5)',
        model = 'prop_barrier_work06a',
        count = 5,
        spacing = 2.5,
        direction = 'sideways',
        angle = -15.0,
        anchor = 'center'
    },
    {
        group = 'Barrier Tapers',
        label = 'Right 06A Barrier Sweep (5)',
        model = 'prop_barrier_work06a',
        count = 5,
        spacing = 2.5,
        direction = 'sideways',
        angle = 15.0,
        anchor = 'center'
    },

    {
        group = 'Barrier Walls',
        label = '3 Barrier Wall (MP)',
        model = 'prop_mp_barrier_02b',
        count = 3,
        spacing = 2.5,
        direction = 'sideways',
        angle = 0.0,
        anchor = 'center'
    },
    {
        group = 'Barrier Walls',
        label = '5 Barrier Wall (MP)',
        model = 'prop_mp_barrier_02b',
        count = 5,
        spacing = 2.5,
        direction = 'sideways',
        angle = 0.0,
        anchor = 'center'
    },
    {
        group = 'Barrier Tapers',
        label = 'Left MP Barrier Sweep (5)',
        model = 'prop_mp_barrier_02b',
        count = 5,
        spacing = 2.5,
        direction = 'sideways',
        angle = -15.0,
        anchor = 'center'
    },
    {
        group = 'Barrier Tapers',
        label = 'Right MP Barrier Sweep (5)',
        model = 'prop_mp_barrier_02b',
        count = 5,
        spacing = 2.5,
        direction = 'sideways',
        angle = 15.0,
        anchor = 'center'
    },

    {
        group = 'Lights & Safety',
        label = '3 Warning Lights',
        model = 'prop_warninglight_01',
        count = 3,
        spacing = 3.0,
        direction = 'forward',
        angle = 0.0,
        anchor = 'center'
    },
    {
        group = 'Lights & Safety',
        label = '5 Warning Lights',
        model = 'prop_warninglight_01',
        count = 5,
        spacing = 3.0,
        direction = 'forward',
        angle = 0.0,
        anchor = 'center'
    },
    {
        group = 'Lights & Safety',
        label = '3 Work Lights',
        model = 'prop_worklight_03b',
        count = 3,
        spacing = 4.0,
        direction = 'forward',
        angle = 0.0,
        anchor = 'center'
    },
    {
        group = 'Lights & Safety',
        label = '5 Work Lights',
        model = 'prop_worklight_03b',
        count = 5,
        spacing = 4.0,
        direction = 'forward',
        angle = 0.0,
        anchor = 'center'
    },

    {
        group = 'Multi-Prop Scenes',
        label = 'Drag Strip Markers (1/8 Mile)',
        description = 'Small cones at 0, 60ft, 330ft, and 660ft with centered warning lights spaced between markers.',
        anchor = 'start',
        layout = {
            { model = 'prop_roadcone02a', forwardOffset = 0.0, lateralOffset = 0.0, headingOffset = 0.0 },
            { model = 'prop_roadcone02a', forwardOffset = 18.288, lateralOffset = 0.0, headingOffset = 0.0 },
            { model = 'prop_roadcone02a', forwardOffset = 100.584, lateralOffset = 0.0, headingOffset = 0.0 },
            { model = 'prop_roadcone02a', forwardOffset = 201.168, lateralOffset = 0.0, headingOffset = 0.0 },

            { model = 'prop_warninglight_01', forwardOffset = 9.0, lateralOffset = 0.0, headingOffset = 0.0 },
            { model = 'prop_warninglight_01', forwardOffset = 27.0, lateralOffset = 0.0, headingOffset = 0.0 },
            { model = 'prop_warninglight_01', forwardOffset = 45.0, lateralOffset = 0.0, headingOffset = 0.0 },
            { model = 'prop_warninglight_01', forwardOffset = 69.0, lateralOffset = 0.0, headingOffset = 0.0 },
            { model = 'prop_warninglight_01', forwardOffset = 87.0, lateralOffset = 0.0, headingOffset = 0.0 },
            { model = 'prop_warninglight_01', forwardOffset = 114.0, lateralOffset = 0.0, headingOffset = 0.0 },
            { model = 'prop_warninglight_01', forwardOffset = 132.0, lateralOffset = 0.0, headingOffset = 0.0 },
            { model = 'prop_warninglight_01', forwardOffset = 150.0, lateralOffset = 0.0, headingOffset = 0.0 },
            { model = 'prop_warninglight_01', forwardOffset = 168.0, lateralOffset = 0.0, headingOffset = 0.0 },
            { model = 'prop_warninglight_01', forwardOffset = 186.0, lateralOffset = 0.0, headingOffset = 0.0 }
        }
    },
    {
        group = 'Multi-Prop Scenes',
        label = 'Shoulder Work Pack',
        description = 'Cone line with two work lights pulled in tighter to the shoulder cones.',
        anchor = 'center',
        layout = {
            { model = 'prop_roadcone02a', forwardOffset = -6.0, lateralOffset = -1.0, headingOffset = 0.0 },
            { model = 'prop_roadcone02a', forwardOffset = -3.0, lateralOffset = -1.0, headingOffset = 0.0 },
            { model = 'prop_roadcone02a', forwardOffset = 0.0, lateralOffset = -1.0, headingOffset = 0.0 },
            { model = 'prop_roadcone02a', forwardOffset = 3.0, lateralOffset = -1.0, headingOffset = 0.0 },
            { model = 'prop_roadcone02a', forwardOffset = 6.0, lateralOffset = -1.0, headingOffset = 0.0 },
            { model = 'prop_worklight_03b', forwardOffset = -1.5, lateralOffset = 0.2, headingOffset = 0.0 },
            { model = 'prop_worklight_03b', forwardOffset = 1.5, lateralOffset = 0.2, headingOffset = 0.0 }
        }
    },
    {
        group = 'Multi-Prop Scenes',
        label = 'Mini Road Closure',
        description = 'Three barriers with a cone on each end for a fast hard-stop setup.',
        anchor = 'center',
        layout = {
            { model = 'prop_roadcone02a', forwardOffset = 0.0, lateralOffset = -4.0, headingOffset = 0.0 },
            { model = 'prop_barrier_work05', forwardOffset = 0.0, lateralOffset = -1.8, headingOffset = -90.0 },
            { model = 'prop_barrier_work05', forwardOffset = 0.0, lateralOffset = 0.0, headingOffset = -90.0 },
            { model = 'prop_barrier_work05', forwardOffset = 0.0, lateralOffset = 1.8, headingOffset = -90.0 },
            { model = 'prop_roadcone02a', forwardOffset = 0.0, lateralOffset = 4.0, headingOffset = 0.0 }
        }
    }
}


Config.PreferredIdentifierTypes = {
    'license:',
    'license2:',
    'fivem:',
    'discord:'
}
