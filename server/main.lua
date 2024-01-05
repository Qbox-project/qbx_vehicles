---@class CreateEntityQuery
---@field license string The license of the owner
---@field citizenId string The citizen id of the owner
---@field model string The model of the vehicle
---@field mods? table The modifications of the vehicle
---@field plate string The plate of the vehicle
---@field state? number The state of the vehicle

--- Creates a Vehicle DB Entity
---@param query CreateEntityQuery
local function createEntity(query)
    MySQL.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES (?,?,?,?,?,?,?)', {
        query.license,
        query.citizenId,
        query.model,
        joaat(query.model),
        query.mods and json.encode(query.mods) or nil,
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

---Fetches DB Vehicle Entity by CiizenId
---@param citizenId string
---@return vehicleData[]
local function fetchEntityByCitizenId(citizenId)
    fetchEntity({
        valueType = 'citizenid',
        value = citizenId
    })
end

exports('FetcEntityByCitizenId', fetchEntityByCitizenId)

---Fetches DB Vehicle Entity by License
---@param license string
---@return vehicleData[]
local function fetchEntityByLicense(license)
    fetchEntity({
        valueType = 'license',
        value = license
    })
end

exports('FetchEntityByLicense', fetchEntityByLicense)

---Fetches DB Vehicle Entity by Plate
---@param plate string
---@return vehicleData[]
local function fetchEntityByPlate(plate)
    fetchEntity({
        valueType = 'plate',
        value = plate
    })
end

exports('FetchEntityByPlate', fetchEntityByPlate)

---@class UpdateEntityVehicleQuery
---@field valueType string
---@field value string

--- Updates a DB Vehicle Entity
---@param query UpdateEntityVehicleQuery
---@param plate string
local function updateEntity(query, plate)
    MySQL.update('UPDATE player_vehicles SET ? = ?, WHERE plate = ?', {
        query.valueType,
        query.value,
        plate
    })
end

exports('UpdateVehicleEntity', updateEntity)

---@class SetEntityOwnerQuery
---@field citizenId string
---@field license string
---@field plate string

--- Update Vehicle Entity Owner
---@param query SetEntityOwnerQuery
local function setEntityOwner(query)
    MySQL.update('UPDATE player_vehicles INNER JOIN players ON players.citizenid = @citizenid SET player_vehicles.citizenid = @citizenid player_vehicles.license = players.license WHERE player_vehicles.plate = @plate', {
        citizenid = query.citizenId,
        license = query.license,
        plate = query.plate,
    })
end

exports("SetVehicleEntityOwner", setEntityOwner)

--- Deletes DB Vehicle entities(-y) through searching for the citizen id
---@param citizenId string 
local function deleteEntitiesByCitizenId(citizenId)
    MySQL.query('DELETE FROM player_vehicles WHERE citizenid = ?', {citizenId})
end

exports('DeleteEntitiesByCitizenId', deleteEntitiesByCitizenId)

--- Deletes a DB Vehicle Entity through searching for the number plate
---@param plate string
local function deleteEntityByPlate(plate)
    MySQL.query('DELETE FROM player_vehicles WHERE plate = ?', {plate})
end

exports('DeleteEntityByPlate', deleteEntityByPlate)

--- Deletes DB Vehicle entities(-y) through searching for the license
---@param license string 
local function deleteEntitiesByLicense(license)
    MySQL.query('DELETE FROM player_vehicles WHERE license = ?', {license})
end

exports('DeleteEntitiesByLicense', deleteEntitiesByLicense)
