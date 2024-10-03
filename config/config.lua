Config = {}
Config.SpawnpointCheck = false -- Checks if the vehicle spawnpoint is empty before spawning it.

-- The global setting for target however you can still combine target/TextUI by omitting Position or PedPosition in garage/impound data
Config.Target = false

---@alias VehicleType string

---@class BlipData
---@field Name string
---@field Sprite integer
---@field Size number
---@field Color integer

---@type table<VehicleType, table<'Garage' | 'Impound', BlipData>>
Config.Blips = {
    ['car'] = {
        Garage = {
            Name = 'Garage',
            Sprite = 357,
            Size = 0.5,
            Color = 17
        },
        Impound = {
            Name = 'Impound',
            Sprite = 357,
            Size = 0.5,
            Color = 3
        },
    },
}

---@class LocationData
---@field Visible boolean Blip visibility on map.
---@field Type VehicleType The vehicle type.
---@field Position? vector3 Needs to be defined if PedPosition isn't.
---@field PedPosition? vector4 Needs to be defined if Position isn't.
---@field Model? number | string Needs to be defined if PedPosition is defined.
---@field SpawnPosition vector4 The vehicle spawn position.
---@field Jobs? string | string[] Optionally limit to jobs.

---@class GarageData : LocationData

---@type GarageData[]
Config.Garages = {
    {
        Visible = false,
        Type = 'car',
        Position = vector3(-409.3608, 1169.8025, -1000.0),
        PedPosition = vector4(-409.3608, 1169.8025, 325.8362, 164.9862),
        Model = `s_m_m_armoured_01`,
        SpawnPosition = vector4(-408.2690, 1173.7101, 325.6436, 343.7200)
    },
}

Config.ImpoundPrice = 5000

---@class ImpoundData : LocationData

---@type ImpoundData[]
Config.Impounds = {
    {
        Visible = true,
        Type = 'car',
        Position = vector3(-412.7317, 1169.8618, 325.8526),
        PedPosition = vector4(-412.7317, 1169.8618, 325.8526, 166.2911),
        Model = `s_m_m_armoured_01`,
        SpawnPosition = vector4(-455.8376, 1143.3151, 325.9046, 343.2213)
    },
}