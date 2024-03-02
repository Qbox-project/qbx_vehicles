---@enum State
local State = {
    OUT = 0,
    GARAGED = 1,
    IMPOUNDED = 2
}

---@class VehicleEntity
---@field license string
---@field citizenid string
---@field vehicle string
---@field hash number
---@field mods table
---@field plate string
---@field fakeplate string
---@field garage string
---@field fuel number
---@field engine number
---@field body number
---@field state State
---@field depotprice number
---@field drivingdistance number
---@field status string

---@class CreateEntityQuery
---@field citizenId string The citizen id of the owner
---@field model string The model of the vehicle
---@field mods? table The modifications of the vehicle
---@field plate string The plate of the vehicle
---@field state? State The state of the vehicle

--- Creates a Vehicle DB Entity
---@param query CreateEntityQuery
---@return vehicleId integer
local function createEntity(query)
    return MySQL.insert.await('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES ((SELECT license FROM players WHERE citizenid = ?),?,?,?,?,?,?)', {
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

--- Fetches DB Vehicle Entity
---@param query FetchVehicleEntityQuery
---@return VehicleEntity[]
local function fetchEntities(query)
    local vehicleData = {}
    if query.valueType ~= 'citizenid' and query.valueType ~= 'license' and query.valueType ~= 'plate' then return {} end
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
---@return VehicleEntity[]
local function fetchEntitiesByCitizenId(citizenId)
    return fetchEntities({
        valueType = 'citizenid',
        value = citizenId
    })
end

exports('FetchEntitiesByCitizenId', fetchEntitiesByCitizenId)

---Fetches DB Vehicle Entity by License
---@param license string
---@return VehicleEntity[]
local function fetchEntitiesByLicense(license)
    return fetchEntities({
        valueType = 'license',
        value = license
    })
end

exports('FetchEntitiesByLicense', fetchEntitiesByLicense)

---Fetches DB Vehicle Entity by Plate
---@param plate string
---@return VehicleEntity[]
local function fetchEntitiesByPlate(plate)
    return fetchEntities({
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
    MySQL.update('UPDATE player_vehicles SET citizenid = ?, license = (SELECT license FROM players WHERE citizenid = ?) WHERE plate = ?', {
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

--- Deletes a DB Vehicle Entity through searching for the vehicle id
---@param id integer
local function deleteEntityById(id)
    MySQL.query('DELETE FROM player_vehicles WHERE id = ?', {id})
end

exports('DeleteEntityById', deleteEntityById)

--- Returns if the given plate exists
---@param plate string
---@return boolean
local function doesEntityPlateExist(plate)
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM player_vehicles WHERE plate = ?', {plate})
    return count > 0
end

exports('DoesEntityPlateExist', doesEntityPlateExist)