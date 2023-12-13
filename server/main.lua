---@class CreateEntityQuery
---@field license string
---@field citizenId string
---@field model string
---@field mods table
---@field plate string
---@field state number

--- Creates a Vehicle DB Entity
---@param query CreateEntityQuery
local function createEntity(query)
    MySQL.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES (?,?,?,?,?,?,?)', {
        query.license,
        query.citizenId,
        query.model,
        joaat(query.model),
        query.mods or '{}',
        query.plate,
        query.state or 0
    })
end

exports('CreateVehicleEntity', createEntity)

---@class FetchVehicleEntityQuery
---@field valueType 'citizenid'|'license'|'plate'
---@field value string

---@alias vehicleEntity table

--- Fetches DB Vehicle Entity
---@param query FetchVehicleEntityQuery
---@return vehicleData[]
local function fetchEntity(query)
    local vehicleData = {}
    if query.valueType ~= 'citizenid' and query.valueType ~= 'license' and query.valueType ~= 'plate' then return end
    local results = MySQL.query.await('SELECT * FROM player_vehicles WHERE ? = ?', {
        query.valueType,
        query.value
    })
    for _, data in pairs(results) do
        vehicleData[#vehicleData + 1] = {
            id = data.id,
            citizenid = data.citizenid,
            model = data.vehicle,
        }
    end
    return vehicleData
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

---@class SetEntityOwnerQuery
---@field citizenId string
---@field vehiclePlate string

--- Update Vehicle Entity Owner
---@param query SetEntityOwnerQuery
local function setEntityOwner(query)
    MySQL.update('UPDATE player_vehicles SET citizenid = ? WHERE plate = ?', {
        query.citizenId,
        query.vehiclePlate
    })
end

exports("SetVehicleEntityOwner", setEntityOwner)

--- Deletes a DB Vehicle Entity through searching for the number plate
---@param vehiclePlate string
local function deleteEntityByPlate(vehiclePlate)
    MySQL.query('DELETE FROM player_vehicles WHERE plate = ?', {vehiclePlate})
end

exports('DeleteVehicleEntityFromPlate', deleteEntityByPlate)

--- Deletes DB Vehicle entities(-y) through searching for the citizen id
---@param citizenId string 
local function deleteEntitiesByCitizenId(citizenId)
    MySQL.query('DELETE FROM player_vehicles WHERE citizenid = ?', {citizenId})
end

exports('DeleteVehicleEntitiesByCitizenId', deleteEntitiesByCitizenId)
