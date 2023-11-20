---@class vehicleData
---@field model string
---@field plate string
---@field mods string

---@class playerData
---@field license string
---@field citizenId string


--- Creates a Vehicle DB Entity
---@param playerData playerData
---@param vehicleData vehicleData
local function createEntity(playerData, vehicleData)
    MySQL.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES (?,?,?,?,?,?,?)', {
        playerData.license,
        playerData.citizenId,
        vehicleData.model,
        joaat(vehicleData.model),
        vehicleData.mods or '{}',
        vehicleData.plate,
        0
    })
end

exports('CreateVehicleEntity', createEntity)

---@class FetchVehicleEntityQuery
---@field valueType 'citizenid'|'license'|'plate'
---@field value string

---@alias vehicleEntity table

--- Fetches DB Vehicle Entity
---@param query FetchVehicleEntityQuery
---@return vehicleEntity[]|nil
local function fetchEntity(query)
    if query.valueType ~= 'citizenid' and query.valueType ~= 'license' and query.valueType ~= 'plate' then return end
    return MySQL.await('SELECT * FROM player_vehicles WHERE ? = ?', {
        query.valueType,
        query.value
    })
end

exports('FetchVehicleEntity', fetchEntity)

---@class UpdateEntityVehicleQuery
---@field valueType string
---@field value string

--- Updates a DB Vehicle Entity
---@param query UpdateEntityVehicleQuery
---@param vehiclePlate string
local function updateEntity(query, vehiclePlate)
    MySQL.update('UPDATE player_vehicles SET ? = ?, WHERE plate = ?', {
        query.valueType,
        query.value,
        vehiclePlate
    })
end

exports('UpdateVehicleEntity', updateEntity)

--- Update Vehicle Entity Owner
---@param citizenId string
---@param license string
---@param vehiclePlate string
local function updateEntityOwner(citizenId, license, vehiclePlate)
    MySQL.update('UPDATE player_vehicles SET citizenid = ?, license = ? WHERE plate = ?', {
        citizenId,
        license,
        vehiclePlate
    })
end

exports("UpdateVehicleEntityOwner", updateEntityOwner)

--- Deletes a DB Vehicle Entity through searching for the number plate
---@param vehiclePlate string
local function deleteEntityFromPlate(vehiclePlate)
    MySQL.query('DELETE FROM player_vehicles WHERE plate = ?', {vehiclePlate})
end

exports('DeleteVehicleEntityFromPlate', deleteEntityFromPlate)

--- Deletes DB Vehicle entities(-y) through searching for the citizen id
---@param citizenId string 
local function deleteEntitiesByCitizenId(citizenId)
    MySQL.query('DELETE FROM player_vehicels WHERE citizenid = ?', {citizenId})
end

exports('DeleteVehicleEntitiesByCitizenId', deleteEntitiesByCitizenId)