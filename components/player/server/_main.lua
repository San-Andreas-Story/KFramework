KFramework.Server.Players = {}

local players = {}
local creatingCharacter = {}

--- Vérifie si un joueur possède un objet `_Player` enregistré dans le registre du component.
---@param source number Le Server ID du joueur à vérifier.
---@return boolean `true` si le joueur est enregistré, sinon `false`.
KFramework.Server.Players.exists = function(source)
    return players[tonumber(source)] ~= nil 
end

--- Pousse l'état public du personnage vers le client (StateBag), pour que Client.Players.get() reste à jour.
--- Exclut volontairement `position` (bruyant, inutile côté client) et `source` (redondant).
---@param source number
---@param player Player
local function syncState(source, player)
    Player(source).state:set("character", {
        name = player.name,
        loaded = player.loaded,
        metadata = player.metadata,
    }, true)
end

--- Récupère l'identifiant unique et persistant d'un joueur (ex: sa license Rockstar).
---@param source number Le Server ID du joueur.
---@return string|nil L'identifiant du joueur, ou `nil` s'il n'a pas pu être récupéré (joueur déconnecté, type d'identifiant absent...).
KFramework.Server.Players.getIdentifier = function(source)
    source = tonumber(source)
    if not KFramework.Server.Utils.isConnected(source) then return nil end
    return GetPlayerIdentifierByType(source, 'license2') or GetPlayerIdentifierByType(source, 'license')
end

--- Recherche un joueur actuellement connecté à partir de son identifiant persistant.
---@param identifier string L'identifiant du joueur à rechercher.
---@return number|nil Le Server ID du joueur s'il est actuellement connecté, sinon `nil`.
KFramework.Server.Players.getByIdentifier = function(identifier)
    for source, player in pairs(players) do
        if player.identifier == identifier then return source end
    end
    return nil

end

--- Récupère sous forme d'instantanés (snapshots) la liste de tous les joueurs actuellement connectés et enregistrés.
---@return table<number, table> Une table associative indexée par Server ID, contenant le snapshot de chaque joueur.
KFramework.Server.Players.getAll = function()
    local all = {}
    for source, player in pairs(players) do
        all[source] = player:snapshot()
    end
    return all

end

--- Recherche un personnage existant en base de données pour ce joueur : le charge s'il existe, sinon
--- déclenche l'ouverture du character creator côté client via `startCharacterCreator`.
---@param source number Le Server ID du joueur concerné.
---@return void
KFramework.Server.Players.loadCharacter = function(source)
    source = tonumber(source)
    local player = players[source]

    if not player then
        KFramework.logDev(("loadCharacter: aucun _Player enregistré pour la source %s."):format(source))
        return
    end

    KFramework.Server.Database.query('SELECT * FROM kf_characters WHERE identifier = ? LIMIT 1', { player.identifier }, function(row)
        if not KFramework.Server.Utils.isConnected(source) then return end

        local row = rows and rows[1]

        -- BUG corrigé : le callback reçoit directement `row` (déjà la 1ère ligne, ou nil).
        -- L'ancien code lisait une variable `rows` inexistante ; `row` valait donc toujours nil
        -- et renvoyait TOUS les joueurs vers le character creator à chaque connexion, même ceux
        -- ayant déjà un personnage.
        if not row then
            KFramework.Server.Players.startCharacterCreator(source)
            return
        end

        local opts = _Player.fromDB(row)
        opts.source = source
        opts.loaded = true

        local loadedPlayer = _Player(opts)
        players[source] = loadedPlayer
        syncState(source, loadedPlayer)

        KFramework.logDev(("Personnage chargé pour la source %s (charId %s)."):format(source, tostring(opts.charId)))
        KFramework.toInternal("Player:loaded", source, loadedPlayer:snapshot())

        -- Réapplique l'apparence sauvegardée côté client (voir applyAppearance ci-dessus).
        KFramework.Server.Players.applyAppearance(source, loadedPlayer.appearance)
    end)
end

--- Déclenche l'ouverture du character creator côté client pour un joueur n'ayant pas encore de personnage.
---@param source number Le Server ID du joueur concerné.
---@return void
KFramework.Server.Players.startCharacterCreator = function(source)
    source = tonumber(source)
    if not KFramework.Server.Utils.isConnected(source) then return end
    KFramework.toClient("Player:openCharacterCreator", source)
end

--- Réceptionne les données validées par le joueur dans le character creator, crée le personnage correspondant en
--- base de données, puis met à jour l'objet `_Player` du joueur (nom, position de spawn, métadonnées...).
---@param source number Le Server ID du joueur concerné.
---@param data table Les données du personnage saisies côté client (nom, apparence, etc. selon votre character creator).
---@return boolean `true` si le personnage a été créé et chargé avec succès, sinon `false`.
KFramework.Server.Players.finishCharacterCreator = function(source, data)
    source = tonumber(source)
    local player = players[source]
    if not player or type(data) ~= "table" then return false end
 
        if player:isLoaded() or creatingCharacter[source] then
        KFramework.Error(("Tentative de (re)création d'un personnage déjà chargé ou en cours de création pour la source %s."):format(source))
        return false
    end
    creatingCharacter[source] = true
 
    local identifier = player.identifier
    local positionJson = data.position and json.encode(data.position) or nil
    local metadataJson = data.metadata and json.encode(data.metadata) or nil
    local appearanceJson = data.appearance and json.encode(data.appearance) or nil
 
    KFramework.Server.Database.insert('INSERT INTO kf_characters (identifier, name, position, metadata, appearance) VALUES (?, ?, ?, ?, ?)',
        { identifier, data.name, positionJson, metadataJson, appearanceJson },
        function(insertId)
            creatingCharacter[source] = nil
            if not KFramework.Server.Utils.isConnected(source) then return end
 
            if not insertId then
                KFramework.Error(("Échec de création du personnage pour l'identifiant %s."):format(identifier))
                return
            end
 
            local newPlayer = _Player({
                source = source,
                identifier = identifier,
                charId = insertId,
                name = data.name,
                position = data.position,
                metadata = data.metadata,
                appearance = data.appearance,
                loaded = true,
            })
            players[source] = newPlayer
            syncState(source, newPlayer)
 
            KFramework.logDev(("Personnage créé pour la source %s (charId %s)."):format(source, insertId))
            KFramework.toInternal("Player:loaded", source, newPlayer:snapshot())
        end)
 
    return true
end

--- Renvoie au client l'apparence sauvegardée d'un personnage, afin que le skinchanger la réapplique.
--- Utile à la connexion : rien côté client ne persiste l'apparence entre deux sessions, donc sans
--- cet appel le joueur réapparaîtrait avec le ped par défaut à chaque reconnexion.
---@param source number Le Server ID du joueur concerné.
---@param appearance table|nil Les données d'apparence renvoyées par skinchanger:getSkin.
---@return void
KFramework.Server.Players.applyAppearance = function(source, appearance)
    if not appearance then return end
    source = tonumber(source)
    if not KFramework.Server.Utils.isConnected(source) then return end
    KFramework.toClient("skinchanger:loadSkin", source, appearance)
end

--- Sauvegarde en base de données les données actuelles du personnage d'un joueur.
---@param source number Le Server ID du joueur concerné.
---@return boolean `true` si la sauvegarde a réussi, `false` si le joueur n'existe pas, n'a pas de personnage chargé, ou si une sauvegarde est déjà en cours (`saving == true`).
KFramework.Server.Players.saveCharacter = function(source)
    source = tonumber(source)
    local player = players[source]

    if not player or not player:isLoaded() then return false end
    if not player:beginSave() then return false end
 
    local data = player:toDB()
    KFramework.Server.Database.execute('UPDATE kf_characters SET name = ?, position = ?, metadata = ? WHERE id = ?',
        { data.name, data.position, data.metadata, data.charId },
        function(rowsChanged)
            player:endSave()
            if not rowsChanged or rowsChanged == 0 then
                KFramework.Error(("Échec de la sauvegarde du personnage %s (source %s)."):format(tostring(data.charId), source))
            end
        end)
 
    return true
end


--- Sauvegarde en base de données les personnages de tous les joueurs actuellement connectés (ex: appelé par la
--- boucle de sauvegarde périodique, ou à l'arrêt de la ressource).
---@return number Le nombre de personnages sauvegardés avec succès.
KFramework.Server.Players.saveAllPlayers = function()
    local count = 0
    for source in pairs(players) do
        if KFramework.Server.Players.saveCharacter(source) then
            count = count + 1
        end
    end
    return count
end


--- Définit ou met à jour une métadonnée personnalisée associée au personnage d'un joueur.
---@param source number Le Server ID du joueur concerné.
---@param key string La clé de la métadonnée à enregistrer.
---@param value any La valeur à attribuer à la métadonnée.
---@return boolean `true` si la métadonnée a été définie avec succès, `false` si le joueur n'existe pas.
KFramework.Server.Players.setMeta = function(source, key, value)
    source = tonumber(source)
    local player = players[source]
    if not player then return false end
    player:setMeta(key, value)
    syncState(source, player)
    return true
end

--- Récupère une métadonnée spécifique ou l'ensemble des métadonnées associées au personnage d'un joueur.
---@param source number Le Server ID du joueur concerné.
---@param key string|nil (Optionnel) La clé de la métadonnée à récupérer. Si non spécifiée, retourne toutes les métadonnées.
---@return any|table|nil La valeur de la métadonnée, la table complète des métadonnées, ou `nil` si le joueur n'existe pas ou si la métadonnée n'est pas définie.
KFramework.Server.Players.getMeta = function(source, key)
    local player = players[tonumber(source)]
    if not player then return nil end
    return player:getMeta(key)
end

KFramework.onReceive("Players:finishCharacterCreator", function(data)
    local source = tonumber(source)
    local player = players[source]
    if not player then return end

    if player:isLoaded() or creatingCharacter[source] then
        KFramework.Error(("Le joueur %s a tenté de (re)créer un personnage déjà chargé ou en cours de création."):format(source))
        return
    end
    if type(data) ~= "table" then return end

    creatingCharacter[source] = true
    KFramework.Server.Players.finishCharacterCreator(source, data)
end)

--- Gestionnaire d'événement déclenché lorsqu'un joueur rejoint le serveur.
--- Crée l'objet `_Player` initial (source + identifiant récupéré via `getIdentifier`), l'ajoute au registre,
--- puis lance le chargement de son personnage via `loadCharacter`.
---@return void
AddEventHandler("playerJoining", function()
    local source = tonumber(source)
    local identifier = KFramework.Server.Players.getIdentifier(source)
 
    if not identifier then
        KFramework.Error(("Impossible de récupérer l'identifiant du joueur %s, connexion refusée."):format(source))
        DropPlayer(source, "Impossible de vérifier votre identité (identifiant manquant).")
        return
    end
 
    players[source] = _Player({ source = source, identifier = identifier, loaded = false })
    KFramework.Server.Players.loadCharacter(source)
end)

--- Gestionnaire d'événement déclenché lorsqu'un joueur se déconnecte du serveur.
--- Sauvegarde les données du personnage via `saveCharacter` avant de retirer le joueur du registre.
---@param reason string La raison de la déconnexion du joueur.
---@return void
AddEventHandler("playerDropped", function(reason)
    local source = tonumber(source)
    creatingCharacter[source] = nil  -- FIX: était _creating
    local player = players[source]  -- FIX: était _registry
    if not player then return end
 
    if player:isLoaded() then
        KFramework.Server.Players.saveCharacter(source)
    end
 
    players[source] = nil
end)

--- Boucle de sauvegarde périodique : appelle `saveAllPlayers` à intervalle régulier, afin de limiter la perte de
--- données en cas de crash ou d'arrêt brutal du serveur.
---@return void
CreateThread(function()
    while true do
        Wait(5 * 60 * 1000) -- 5 minutes ; ajuste selon ta tolérance à la perte de données en cas de crash
        local count = KFramework.Server.Players.saveAllPlayers()
        if count > 0 then
            KFramework.logDev(("Sauvegarde périodique : %d personnage(s) en cours de sauvegarde."):format(count))
        end
    end
end)


KFramework.loadedComponent('Players')