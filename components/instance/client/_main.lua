KFramework.Client.Instance = {}

local public = 0
local currentInstance = LocalPlayer.state.instance or public
local instanceCallbacks = {}

KFramework.Client.Instance.get = function()
    return (LocalPlayer.state.instance or public)
end

KFramework.Client.Instance.isPublic = function()
    return KFramework.Client.Instance.get() == public
end

KFramework.Client.Instance.isPrivate = function()
    return KFramework.Client.Instance.get() ~= public
end

KFramework.Client.Instance.onChange = function(callback)
    if type(callback) ~= "function" then return nil end

    instanceCallbacks[#instanceCallbacks + 1] = callback

    return function()
        for i = #instanceCallbacks, 1, -1 do 
            if instanceCallbacks[i] == callback then 
                table.remove(instanceCallbacks, i)
            end
        end
    end
end

AddStateBagChangeHandler("instance", nil, function(bagName, _, value)
    if bagName ~= ("player:%d"):format(GetPlayerServerId(PlayerId())) then 
        return 
    end

    local newInstanceId = type(value) == "number" and value or public
    local oldInstanceId = currentInstance

    if newInstanceId == oldInstanceId then 
        return 
    end

    currentInstance = newInstanceId
    KFramework.logDev(("Instance client modifiée : %s -> %s"):format(oldInstanceId, newInstanceId))

    --Event pour intéragir avec le client des instances :  TriggerEvent("KFramework:Client:Instance:changed", newInstanceId, oldInstanceId)

    for _, cb in ipairs({ table.unpack(instanceCallbacks) }) do
        local ok, err = pcall(cb, newInstanceId, oldInstanceId)
        if not ok then
            print(("^1[KFramework] Erreur dans un callback Instance.onChange : %s^7"):format(tostring(err)))
        end
    end
end)

KFramework.loadedComponent('Instance')