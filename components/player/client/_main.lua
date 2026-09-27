KFramework.Client.Players = {}

local currentCharacter = LocalPlayer.state.character
local characterCallbacks = {}

--- Récupère l'état actuel du personnage du joueur local (depuis le state bag synchronisé par le serveur).
---@return table|nil Une table représentant l'état du personnage local, ou `nil` si aucun personnage n'est encore chargé.
KFramework.Client.Players.get = function()
    return LocalPlayer.state.character
end

--- Vérifie si le personnage du joueur local est chargé et jouable.
---@return boolean `true` si le personnage local est chargé, sinon `false`.
KFramework.Client.Players.isLoaded = function()
    local character = KFramework.Client.Players.get()
    return character ~= nil and character.loaded == true

end

--- Enregistre une fonction de rappel (callback) déclenchée lors d'un changement d'état du personnage du joueur local.
---@param callback function La fonction à exécuter lors d'un changement d'état.
---@return function|nil Une fonction de nettoyage (unsubscribe) permettant de désinscrire le callback, ou `nil` si le callback est invalide.
KFramework.Client.Players.onChange = function(callback)
    if type(callback) ~= "function" then return nil end
 
    characterCallbacks[#characterCallbacks + 1] = callback
 
    return function()
        for i = #characterCallbacks, 1, -1 do
            if characterCallbacks[i] == callback then
                table.remove(characterCallbacks, i)
            end
        end
    end

end

--- Gestionnaire de changement d'état du State Bag pour la clé "character" du joueur local.
--- Détecte les modifications poussées par le serveur (chargement du personnage, mise à jour de métadonnées...),
--- met à jour l'état local, puis exécute de manière sécurisée tous les callbacks enregistrés via
--- `KFramework.Client.Players.onChange`.
---@return void
AddStateBagChangeHandler("character", nil, function(bagName, _, value)
    if bagName ~= ("player:%d"):format(GetPlayerServerId(PlayerId())) then
        return
    end
 
    local oldCharacter = currentCharacter
    currentCharacter = value
 
    KFramework.logDev("État du personnage local modifié.")
 
    for _, cb in ipairs({ table.unpack(characterCallbacks) }) do
        local ok, err = pcall(cb, currentCharacter, oldCharacter)
        if not ok then
            print(("^1[KFramework] Erreur dans un callback Players.onChange : %s^7"):format(tostring(err)))
        end
    end
end)


--- Affiche l'interface NUI du character creator au joueur local. Appelé en réponse à l'event serveur déclenché
--- par `KFramework.Server.Players.startCharacterCreator`.
---@param data table Les données initiales à transmettre à l'interface (options d'apparence disponibles, etc.).
---@return void
KFramework.Client.Players.openCharacterCreator = function(data)
    KFramework.logDev("openCharacterCreator appelé — TODO: brancher ton UI ici.")
    KFramework.toInternal('skinchanger:loadDefaultModel', true)
end

KFramework.Client.Players.getAppearanceOptions = function(cb)
    KFramework.toInternal('skinchanger:getData', cb)
end

KFramework.Client.Players.setAppearanceValue = function(key, value)
    KFramework.toInternal('skinchanger:change', key, value)
end

--- Envoie au serveur les données du personnage saisies par le joueur dans le character creator, pour validation
--- et création (traité côté serveur par `KFramework.Server.Players.finishCharacterCreator`).
---@param data table Les données du personnage saisies dans l'interface NUI (nom, apparence, etc.).
---@return void
KFramework.Client.Players.submitCharacterCreator = function(data)
    if type(data) ~= "table" then return end
 
    if data.appearance == nil then
        KFramework.toInternal('skinchanger:getSkin', function(skin)
            data.appearance = skin
            KFramework.toServer("Players:finishCharacterCreator", data)
        end)
        return
    end
 
    KFramework.toServer("Players:finishCharacterCreator", data)
end

--- Récupère le nom du personnage du joueur local.
---@return string|nil Le nom du personnage local, ou `nil` si aucun personnage n'est chargé.
KFramework.Client.Players.getName = function()
    local character = KFramework.Client.Players.get()
    return character and character.name or nil
end

--- Récupère une métadonnée spécifique ou l'ensemble des métadonnées du personnage du joueur local.
---@param key string|nil (Optionnel) La clé de la métadonnée à récupérer. Si non spécifiée, retourne toutes les métadonnées.
---@return any|table|nil La valeur de la métadonnée, la table complète des métadonnées, ou `nil` si aucun personnage n'est chargé ou si la métadonnée n'existe pas.
KFramework.Client.Players.getMeta = function(key)
    local character = KFramework.Client.Players.get()
    if not character or not character.metadata then return nil end
    if not key then return character.metadata end
    return character.metadata[key]
end

KFramework.toInternal("Player:openCharacterCreator", function(data)
    KFramework.Client.Players.openCharacterCreator(data or {})
end)


KFramework.loadedComponent('Players')