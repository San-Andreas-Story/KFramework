KFramework.Client.Instance = {}

local public = 0
local currentInstance = LocalPlayer.state.instance or public
local instanceCallbacks = {}

--- Récupère l'identifiant de l'instance/bucket actuel du joueur local.
---@return number/string L'identifiant de l'instance courante du joueur local, ou l'ID de l'instance publique par défaut.
KFramework.Client.Instance.get = function()
    return (LocalPlayer.state.instance or public)
end

--- Vérifie si le joueur local est actuellement dans l'instance publique.
---@return boolean `true` si le joueur local est dans l'instance publique, sinon `false`.
KFramework.Client.Instance.isPublic = function()
    return KFramework.Client.Instance.get() == public
end

--- Vérifie si le joueur local est actuellement dans une instance privée (non publique).
---@return boolean `true` si le joueur local est dans une instance privée, sinon `false`.
KFramework.Client.Instance.isPrivate = function()
    return KFramework.Client.Instance.get() ~= public
end

--- Enregistre une fonction de rappel (callback) déclenchée lors d'un changement d'instance du joueur local.
---@param callback function La fonction à exécuter lors d'un changement d'instance.
---@return function|nil Une fonction de nettoyage (unsubscribe) permettant de désinscrire le callback, ou `nil` si le callback est invalide.
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

--- Gestionnaire de changement d'état du State Bag pour la clé "instance" du joueur local.
--- Détecte les modifications d'instance attribuées côté serveur, met à jour la variable locale `currentInstance`,
--- puis exécute de manière sécurisée tous les callbacks enregistrés via `KFramework.Client.Instance.onChange`.
---@param bagName string Le nom du State Bag ayant subi une modification (ex: "player:src").
---@param _ string La clé modifiée ("instance").
---@param value any La nouvelle valeur affectée au State Bag (ID de l'instance).
---@return void
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