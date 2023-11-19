---@class InsertVehicleEntityQuery
---@field license string
---@field citizenId string
---@field model string
---@field plate string
---@field mods string

--- Creates a Vehicle DB Entity
---@param query InsertVehicleEntityQuery Insert Vehicle Entity Request
local function createEntity(query)
    MySQL.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES (?,?,?,?,?,?,?)', {
        query.license,
        query.citizenId,
        query.model,
        joaat(query.model),
        query.mods or '{}',
        query.plate,
        0
    })
end

exports('CreateEntity', createEntity)

---@class FetchVehicleEntityQuery
---@field valueType 'citizenid'|'license'|'plate'
---@field value string

---@alias vehicleEntity table

--- Fetch Entity
---@param query FetchVehicleEntityQuery
---@return vehicleEntity[]
local function fetchEntity(query)
    if query.valueType ~= 'citizenid' and query.valueType ~= 'license' and query.valueType ~= 'plate' then return end
    return MySQL.await('SELECT * FROM player_vehicles WHERE ? = ?', {
        query.valueType,
        query.value
    })
end

exports('FetchEntity', fetchEntity)

---@class UpdateEntityVehicleQuery
---@field valueType string
---@field value string

--- Updates a DB Entity
---@param query UpdateEntityVehicleQuery
---@param vehiclePlate string
local function updateEntity(query, vehiclePlate)
    MySQL.update('UPDATE player_vehicles SET ? = ?, WHERE plate = ?', {
        query.valueType,
        query.value,
        vehiclePlate
    })
end

exports('UpdateEntity', updateEntity)

--- Deletes a DB Entity
---@param vehiclePlate string
local function deleteEntity(vehiclePlate)
    MySQL.query('DELETE FROM player_vehicles WHERE plate = ?', {vehiclePlate})
end

exports('DeleteEntity', deleteEntity)