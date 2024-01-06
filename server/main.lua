---@enum State
local State = {
    OUT = 0,
    GARAGED = 1,
    IMPOUNDED = 2
}

---@class CreateEntityQuery
---@field citizenId string The citizen id of the owner
---@field model string The model of the vehicle
---@field mods? table The modifications of the vehicle
---@field plate string The plate of the vehicle
---@field state? enum The state of the vehicle

--- Creates a Vehicle DB Entity
---@param query CreateEntityQuery
local function createEntity(query)
    MySQL.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES ((SELECT license FROM players WHERE citizenid = ?),?,?,?,?,?,?)', {
        query.citizenId,
        query.citizenId,
        query.model,
        joaat(query.model),
        query.mods and json.encode(query.mods) or nil,
        query.plate,
        query.state or State.OUT
    })
end

exports('CreateVehicleEntity', createEntity)

---@class FetchVehicleEntityQuery
---@field valueType 'citizenid'|'license'|'plate'
---@field value string

---@alias VehicleEntity table

--- Fetches DB Vehicle Entity
---@param query FetchVehicleEntityQuery
---@return VehicleData[]
local function fetchEntities(query)
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
local function fetchEntitiesByCitizenId(citizenId)
    fetchEntities({
        valueType = 'citizenid',
        value = citizenId
    })
end

exports('FetchEntitiesByCitizenId', fetchEntitiesByCitizenId)

---Fetches DB Vehicle Entity by License
---@param license string
---@return vehicleData[]
local function fetchEntitiesByLicense(license)
    fetchEntities({
        valueType = 'license',
        value = license
    })
end

exports('FetchEntitiesByLicense', fetchEntitiesByLicense)

---Fetches DB Vehicle Entity by Plate
---@param plate string
---@return vehicleData[]
local function fetchEntitiesByPlate(plate)
    fetchEntities({
        valueType = 'plate',
        value = plate
    })
end

exports('FetchEntitiesByPlate', fetchEntitiesByPlate)

---@class SetEntityOwnerQuery
---@field citizenId string
---@field plate string

--- Update Vehicle Entity Owner
---@param query SetEntityOwnerQuery
local function setEntityOwner(query)
    MySQL.update('UPDATE player_vehicles INNER JOIN (SELECT license FROM players WHERE citizenid = ?) AS subquery ON subquery.license = player_vehicles.license SET player_vehicles.citizenid = ?, player_vehicles.license = subquery.license WHERE player_vehicles.plate = ?', {
        query.citizenId,
        query.citizenId,
        query.plate
    })
end

exports("SetVehicleEntityOwner", setEntityOwner)

--- Deletes a DB Vehicle Entity through searching for the number plate
---@param plate string
local function deleteEntityByPlate(plate)
    MySQL.query('DELETE FROM player_vehicles WHERE plate = ?', {plate})
end

exports('DeleteEntityByPlate', deleteEntityByPlate)
