assert(lib.checkDependency('qbx_core', '1.2.0', true))

---@class ErrorResult
---@field code string
---@field message string

---@enum State
local State = {
    OUT = 0,
    GARAGED = 1,
    IMPOUNDED = 2
}

local triggerEventHooks = require '@qbx_core.modules.hooks'

---Returns true if the given plate exists
---@param plate string
---@return boolean
local function doesEntityPlateExist(plate)
    local result = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ? LIMIT 1', {plate})
    return result ~= nil
end

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
---@field citizenid? string
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
    local placeholders = {}
    local whereClauseCrumbs = {}
    if filters.vehicleId then
        whereClauseCrumbs[#whereClauseCrumbs+1] = 'id = ?'
        placeholders[#placeholders+1] = filters.vehicleId
    end
    if filters.citizenid then
        whereClauseCrumbs[#whereClauseCrumbs+1] = 'citizenid = ?'
        placeholders[#placeholders+1] = filters.citizenid
    end
    if filters.garage then
        whereClauseCrumbs[#whereClauseCrumbs+1] = 'garage = ?'
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
            whereClauseCrumbs[#whereClauseCrumbs+1] = string.format('(%s)', table.concat(statePlaceholders, ' OR '))
        end
    end

    return string.format(' WHERE %s', table.concat(whereClauseCrumbs, ' AND ')), placeholders
end

---@param filters? PlayerVehiclesInternalFilters
---@return PlayerVehicle[]
local function getPlayerVehiclesInternal(filters)
    local query = 'SELECT id, citizenid, vehicle, mods, garage, state, depotprice FROM player_vehicles'
    local whereClause, placeholders = buildWhereClause(filters)
    lib.print.debug(query .. whereClause)
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
    assert(vehicleId ~= nil, "required field vehicleId was nil")
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
    assert(request.model ~= nil, 'missing required field: model')

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

    if not triggerEventHooks('createPlayerVehicle', { citizenid = request.citizenid, garage = request.garage, props = props }) then
        return nil, {
            code = 'hook_cancelled',
            message = 'a createPlayerVehicle event hook cancelled this operation'
        }
    end

    return MySQL.insert.await('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state, garage) VALUES ((SELECT license FROM players WHERE citizenid = @citizenid), @citizenid, @vehicle, @hash, @mods, @plate, @state, @garage)', {
        citizenid = request.citizenid,
        vehicle = request.model,
        hash = props.model,
        mods = json.encode(props),
        plate = props.plate,
        state = request.garage and State.GARAGED or State.OUT,
        garage = request.garage
    })
end

exports('CreatePlayerVehicle', createPlayerVehicle)

---@param vehicleId integer
---@param citizenid? string
---@return boolean success, ErrorResult? errorResult
local function setPlayerVehicleOwner(vehicleId, citizenid)
    assert(vehicleId ~= nil, "required field vehicleId was nil")
    if not triggerEventHooks('changeVehicleOwner', { vehicleId = vehicleId, newCitizenId = citizenid }) then
        return false, {
            code = 'hook_cancelled',
            message = 'a changeVehicleOwner event hook cancelled this operation'
        }
    end
    MySQL.update.await('UPDATE player_vehicles SET citizenid = @citizenid, license = (SELECT license FROM players WHERE citizenid = @citizenid) WHERE id = @id', {
        citizenid = citizenid,
        id = vehicleId
    })
    return true
end

exports('SetPlayerVehicleOwner', setPlayerVehicleOwner)

---@param idType 'citizenid'|'license'|'plate'|'vehicleId'
---@param idValue string | number
---@return boolean success, ErrorResult? errorResult
local function deletePlayerVehicles(idType, idValue)
    assert(idType == 'citizenid' or idType == 'license' or idType == 'plate' or idType == 'vehicleId', json.encode(idType) .. ' is not a valid idType')

    local column = idType == 'vehicleId' and 'id' or idType
    MySQL.query.await('DELETE FROM player_vehicles WHERE ' .. column .. ' = ?', {
        idValue
    })
    return true
end

exports('DeletePlayerVehicles', deletePlayerVehicles)

---Find the vehicleId with the given plate if it exists.
---@param plate string
---@return integer? vehicleId
local function getVehicleIdByPlate(plate)
    return MySQL.scalar.await('SELECT id FROM player_vehicles WHERE plate = ?', {
        qbx.string.trim(plate)
    })
end

exports('GetVehicleIdByPlate', getVehicleIdByPlate)

---@class SaveVehicleOptions
---@field garage? string
---@field state? State
---@field depotPrice? integer
---@field props? table ox_lib properties table

---@param vehicleId integer
---@param options SaveVehicleOptions
---@return string query, table placeholders
local function buildSaveVehicleQuery(vehicleId, options)
    local crumbs = {}
    local placeholders = {}

    if options.state then
        crumbs[#crumbs+1] = 'state = ?'
        placeholders[#placeholders+1] = options.state
    end

    if options.depotPrice then
        crumbs[#crumbs+1] = 'depotprice = ?'
        placeholders[#placeholders+1] = options.depotPrice
    end

    if options.garage then
        crumbs[#crumbs+1] = 'garage = ?'
        placeholders[#placeholders+1] = options.garage
    end

    if options.props then
        crumbs[#crumbs+1] = 'mods = ?'
        placeholders[#placeholders+1] = json.encode(options.props)

        if options.props.plate then
            crumbs[#crumbs+1] = 'plate = ?'
            placeholders[#placeholders+1] = options.props.plate
        end

        if options.props.fuelLevel then
            crumbs[#crumbs+1] = 'fuel = ?'
            placeholders[#placeholders+1] = options.props.fuelLevel
        end

        if options.props.engineHealth then
            crumbs[#crumbs+1] = 'engine = ?'
            placeholders[#placeholders+1] = options.props.engineHealth
        end

        if options.props.bodyHealth then
            crumbs[#crumbs+1] = 'body = ?'
            placeholders[#placeholders+1] = options.props.bodyHealth
        end
    end

    placeholders[#placeholders+1] = vehicleId

    return string.format('UPDATE player_vehicles SET %s WHERE id = ?', table.concat(crumbs, ',')), placeholders
end

---@param vehicle number entity
---@param options SaveVehicleOptions
---@return boolean success, ErrorResult? errorResult
local function saveVehicle(vehicle, options)
    local vehicleId = Entity(vehicle).state.vehicleid or getVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
    if not vehicleId then
        return false, {
            code = 'not_owned',
            message = 'vehicle does not have a vehicleId and plate is not in the player_vehicles table'
        }
    end

    local query, placeholders = buildSaveVehicleQuery(vehicleId, options)
    MySQL.update.await(query, placeholders)
    TriggerEvent('qbx_vehicles:server:vehicleSaved', vehicleId)
    return true
end

exports('SaveVehicle', saveVehicle)