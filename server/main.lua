---@class ErrorResult
---@field code string
---@field message string

---@enum State
local State = {
    OUT = 0,
    GARAGED = 1,
    IMPOUNDED = 2
}

---@alias IdType 'citizenid'|'license'|'plate'|'vehicleId'

---@param idType IdType
---@return ErrorResult?
local function validateIdType(idType)
    if idType ~= 'citizenid' and idType ~= 'license' and idType ~= 'plate' and idType ~= 'vehicleId' then
        return {
            code = 'bad_request',
            message = 'idType:' .. json.encode(idType) .. ' is not a valid idType'
        }
    end
end

---Returns true if the given plate exists
---@param plate string
---@return boolean
local function doesEntityPlateExist(plate)
    local result = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ? LIMIT 1', {plate})
    return result ~= nil
end

exports('DoesEntityPlateExist', doesEntityPlateExist)
exports('DoesPlayerVehiclePlateExist', doesEntityPlateExist)

---@class PlayerVehicle
---@field id number
---@field citizenid? string
---@field modelName string
---@field garage string
---@field state State
---@field depotPrice integer
---@field props table ox_lib properties table

---@class PlayerVehiclesFilters
---@field citizenId? string
---@field states? State|State[]
---@field garage? string

---@class PlayerVehiclesInternalFilters: PlayerVehiclesFilters
---@field vehicleId? number

---@param filters? PlayerVehiclesInternalFilters
---@return string whereClause, any[] placeholders
local function buildWhereClause(filters)
    if not filters then
        return '', {}
    end
    local query = ' WHERE 1=1'
    local placeholders = {}
    if filters.vehicleId then
        query = query .. ' AND id = ?'
        placeholders[#placeholders+1] = filters.vehicleId
    end
    if filters.citizenId then
        query = query .. ' AND citizenid = ?'
        placeholders[#placeholders+1] = filters.citizenId
    end
    if filters.garage then
        query = query .. ' AND garage = ?'
        placeholders[#placeholders+1] = filters.garage
    end
    if filters.states then
        if type(filters.states) ~= 'table' then
            ---@diagnostic disable-next-line: assign-type-mismatch
            filters.states = {filters.states}
        end
        if #filters.states > 0 then
            local statePlaceholders = {}
            for i = 1, #filters.states do
                placeholders[#placeholders+1] = filters.states[i]
                statePlaceholders[i] = 'state = ?'
            end
            query = query .. string.format(' AND (%s)', table.concat(statePlaceholders, ' OR '))
        end
    end
    return query, placeholders
end

---@param filters? PlayerVehiclesInternalFilters
---@return PlayerVehicle[]
local function getPlayerVehiclesInternal(filters)
    local query = 'SELECT id, citizenid, vehicle, mods, garage, state, depotprice FROM player_vehicles'
    local whereClause, placeholders = buildWhereClause(filters)
    local results = MySQL.query.await(query .. whereClause, placeholders)
    local ownedVehicles = {}
    for _, data in pairs(results) do
        ownedVehicles[#ownedVehicles+1] = {
            id = data.id,
            citizenid = data.citizenid,
            modelName = data.vehicle,
            garage = data.garage,
            state = data.state,
            depotPrice = data.depotprice,
            props = json.decode(data.mods)
        }
    end
    return ownedVehicles
end

---@param filters? PlayerVehiclesFilters
---@return PlayerVehicle[]
local function getPlayerVehicles(filters)
    ---@diagnostic disable-next-line: param-type-mismatch
    return getPlayerVehiclesInternal(filters)
end

exports('GetPlayerVehicles', getPlayerVehicles)

---@param vehicleId number
---@param filters? PlayerVehiclesFilters
---@return PlayerVehicle?
local function getPlayerVehicle(vehicleId, filters)
    if not filters then filters = {} end
    ---@diagnostic disable-next-line: inject-field
    filters.vehicleId = vehicleId
    ---@diagnostic disable-next-line: param-type-mismatch
    return getPlayerVehiclesInternal(filters)[1]
end

exports('GetPlayerVehicle', getPlayerVehicle)

---@class CreatePlayerVehicleRequest
---@field model string model name
---@field citizenid? string owner of the vehicle
---@field garage? string
---@field props? table ox_lib properties to set. See https://github.com/overextended/ox_lib/blob/master/resource/vehicleProperties/client.lua#L3

---@param request CreatePlayerVehicleRequest
---@return integer? vehicleId, ErrorResult? errorResult
local function createPlayerVehicle(request)
    if not request.model then
        return nil, {
            code = 'bad_request',
            message = 'missing required field model'
        }
    end

    local props = request.props or {}
    if not props.plate then
        repeat
            props.plate = qbx.generateRandomPlate()
        until doesEntityPlateExist(props.plate) == false
    end
    props.engineHealth = props.engineHealth or 1000
    props.bodyHealth = props.bodyHealth or 1000
    props.fuelLevel = props.fuelLevel or 100
    props.model = joaat(request.model)

    return MySQL.insert.await('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state, garage) VALUES ((SELECT license FROM players WHERE citizenid = ?),?,?,?,?,?,?,?)', {
        request.citizenid,
        request.citizenid,
        request.model,
        props.model,
        json.encode(props),
        props.plate,
        request.garage and State.GARAGED or State.OUT,
        request.garage
    })
end

exports('CreatePlayerVehicle', createPlayerVehicle)

---@param vehicleId integer
---@param citizenId? string
---@return boolean success, ErrorResult? errorResult
local function setPlayerVehicleOwner(vehicleId, citizenId)
    MySQL.update.await('UPDATE player_vehicles SET citizenid = ?, license = (SELECT license FROM players WHERE citizenid = ?) WHERE id = ?', {
        citizenId,
        citizenId,
        vehicleId
    })
    return true
end

exports('SetPlayerVehicleOwner', setPlayerVehicleOwner)

---@param idType IdType
---@param idValue string
---@return boolean success, ErrorResult? errorResult
local function deletePlayerVehicles(idType, idValue)
    local err = validateIdType(idType)
    if err then return false, err end

    local column = idType == 'vehicleId' and 'id' or idType
    MySQL.query.await('DELETE FROM player_vehicles WHERE ? = ?', {
        column,
        idValue
    })
    return true
end

exports('DeletePlayerVehicles', deletePlayerVehicles)

---@class VehicleEntity
---@field id number
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
---@deprecated
---@param query CreateEntityQuery
---@return integer vehicleId
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

---@class SetEntityOwnerQuery
---@field citizenId string
---@field plate string

--- Update Vehicle Entity Owner
---@deprecated
---@param query SetEntityOwnerQuery
local function setEntityOwner(query)
    MySQL.update('UPDATE player_vehicles SET citizenid = ?, license = (SELECT license FROM players WHERE citizenid = ?) WHERE plate = ?', {
        query.citizenId,
        query.citizenId,
        query.plate
    })
end

exports("SetVehicleEntityOwner", setEntityOwner)

--- Deletes a DB Vehicle Entity through searching for the vehicle id
---@deprecated
---@param id integer
local function deleteEntityById(id)
    MySQL.query('DELETE FROM player_vehicles WHERE id = ?', {id})
end

exports('DeleteEntityById', deleteEntityById)