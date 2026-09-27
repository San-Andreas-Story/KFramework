KFramework.Server.Instance = {}

local public = 0
local listInstance = {}
local previousBuckets = {}

KFramework.Server.Instance.PUBLIC = public

local PRIVATE_START = 10000 
local nextId = PRIVATE_START 
local validStatus = { strict = true, relaxed = true, inactive = true }

--- Récupère l'instance marquée comme publique.
---@return table L'instance publique configurée.
KFramework.Server.Instance.getPublicInstance = function()
    return (public)
end

--- Récupère l'instance (routing bucket) associée à un joueur donné.
---@param _src number/string L'identifiant source (Server ID) du joueur.
---@return number Le numéro du routing bucket dans lequel se trouve le joueur.
KFramework.Server.Instance.getPlayerInstance = function(_src)
    return (GetPlayerRoutingBucket(_src))
end

--- Vérifie si une instance existe par son identifiant ou s'il s'agit de l'instance publique.
---@param idInstance number/string L'identifiant unique de l'instance à vérifier.
---@return boolean `true` si l'instance existe ou correspond à l'instance publique, sinon `false`.
KFramework.Server.Instance.exists = function(idInstance)
    return idInstance == public or listInstance[idInstance] ~= nil
end

---L'instance a-t-elle été créée directement par le framework, par opposition
---à une instance créée via l'API par une ressource tierce (ex: un script de braquage, de garage...) ?
---@param idInstance number
---@return boolean
KFramework.Server.Instance.isManaged = function(idInstance)
    local instance = listInstance[idInstance]
    if not instance then return false end
    return instance.creatorResource == GetCurrentResourceName()
end

--- Vérifie si une instance est privée (différente de l'instance publique).
---@param idInstance number/string L'identifiant unique de l'instance à vérifier.
---@return boolean `true` si l'instance est privée, sinon `false`.
KFramework.Server.Instance.isPrivate = function(idInstance)
    return idInstance ~= public
end

--- Crée une nouvelle instance (routing bucket) avec des options de configuration spécifiques.
---@param opts table|nil Les options de création de l'instance (name, status, population, resource, persistent, ttl).
---@return number|table L'identifiant (ID) de la nouvelle instance créée, ou l'instance existante si un nom identique a été trouvé.
KFramework.Server.Instance.createInstance = function(opts)
    opts = opts or {}

    if opts.name then
        local existing = KFramework.Server.Instance.getByName(opts.name)
        if existing then return (existing) end
    end

    local id = nextId
    nextId = nextId + 1

    local status = validStatus[opts.status] and opts.status or "strict"
    local population = opts.population == true

    SetRoutingBucketEntityLockdownMode(id, status)
    SetRoutingBucketPopulationEnabled(id, population)

    listInstance[id] = _Instance({
        id = id, name = opts.name, status = status, population = population,
        creatorResource = opts.resource or GetInvokingResource() or GetCurrentResourceName(),
        persistent = opts.persistent == true,
    })

    if opts.ttl and opts.ttl > 0 then
        KFramework.Server.Instance.setTTL(id, opts.ttl)
    end

    KFramework.logDev(("Instance créée : %d (%s, %s)"):format(id, tostring(opts.name), status))
    KFramework.toInternal("Instance:created", id, opts.name)
    return (id)
end

--- Récupère l'identifiant d'une instance à partir de son nom.
---@param nameInstance string Le nom de l'instance à rechercher.
---@return number|nil L'identifiant (ID) de l'instance si elle existe, sinon `nil`.
KFramework.Server.Instance.getByName = function(nameInstance)
    for idInstance, instanceData in pairs(listInstance) do
        if instanceData.name == nameInstance then
            return idInstance
        end
    end
    return nil
end

--- Récupère une instance existante par son nom ou en crée une nouvelle si elle n'existe pas.
---@param nameInstance string Le nom de l'instance à récupérer ou créer.
---@param opts table|nil Les options de création à appliquer si l'instance doit être créée.
---@return number L'identifiant (ID) de l'instance trouvée ou créée.
---@return boolean `true` si une nouvelle instance a été créée, `false` si l'instance existait déjà.
KFramework.Server.Instance.getOrCreate = function(nameInstance, opts)
    local id = KFramework.Server.Instance.getByName(nameInstance)
    if id then return id, false end

    opts = opts or {}
    opts.name = nameInstance
    return KFramework.Server.Instance.createInstance(opts), true
end

--- Détruit une instance, réassigne ses joueurs vers l'instance publique et nettoie ses entités.
---@param idInstance number/string L'identifiant unique de l'instance à détruire.
---@return boolean `true` si l'instance a été détruite avec succès, `false` si elle n'existe pas ou est déjà en cours de destruction.
KFramework.Server.Instance.destroy = function(idInstance)
    local instance = listInstance[idInstance]
    if not instance or instance.destroying then return false end
    instance.destroying = true
    instance.ttlTimer = nil

    for _, srcPlayer in ipairs(KFramework.Utils.copyList(instance.players)) do
        if KFramework.Server.Utils.isConnected(srcPlayer) and GetPlayerRoutingBucket(srcPlayer) == idInstance then
            KFramework.Server.Instance.setPlayerInstance(srcPlayer, public)
        end
    end

    KFramework.Server.Instance.clearEntities(idInstance)
    SetRoutingBucketEntityLockdownMode(idInstance, "inactive")
    listInstance[idInstance] = nil

    KFramework.logDev("Instance détruite avec succès : " .. idInstance)
    KFramework.toInternal("Instance:destroyed", idInstance)
    return true
end

--- Vérifie si une instance est vide et la détruit si elle n'est pas configurée comme persistante.
---@param idInstance number/string L'identifiant unique de l'instance à vérifier et éventuellement détruire.
---@return boolean `true` si l'instance a été détruite, sinon `false`.
KFramework.Server.Instance.destroyIfEmpty = function(idInstance)
    local instance = listInstance[idInstance]
    if not instance or instance.destroying then return false end
    instance:pruneStalePlayers()
    if not instance:isEmpty() then return false end
    KFramework.toInternal("Instance:empty", idInstance)
    if instance.persistent then return false end
    return KFramework.Server.Instance.destroy(idInstance)
end

--- Configure un temporisateur d'expiration (TTL) sur une instance pour déclencher sa destruction automatique.
---@param idInstance number/string L'identifiant unique de l'instance concernée.
---@param seconds number Le délai en secondes avant l'expiration et la destruction de l'instance.
---@return boolean `true` si le TTL a été configuré ou annulé avec succès, `false` si l'instance n'existe pas.
KFramework.Server.Instance.setTTL = function(idInstance, seconds)
    local instance = listInstance[idInstance]
    if not instance then return false end
    return instance:setTTL(seconds, function(id) KFramework.Server.Instance.destroy(id) end)
end

--- Récupère les instantanés (snapshots) de l'ensemble des instances actuellement existantes dans le système.
---@return table<number|string, table> Une table clé-valeur associant chaque ID d'instance à son instantané d'informations.
KFramework.Server.Instance.getAll = function()
    local all = {}
    for id, instance in pairs(listInstance) do
        all[id] = instance:snapshot()
    end
    return (all)
end

--- Déplace un joueur (et son véhicule s'il en est le conducteur) vers un routing bucket / instance cible.
--- Gère la mise à jour des données d'instance, l'état du State Bag du joueur, le suivi de l'ancien bucket, 
--- ainsi que l'émission des événements internes appropriés et le nettoyage éventuel des instances devenues vides.
---@param _src number/string L'identifiant source (Server ID) du joueur à déplacer.
---@param idInstance number/string L'identifiant unique de l'instance/bucket cible.
---@return boolean `true` si le déplacement est réussi ou si le joueur y était déjà, `false` en cas d'échec (joueur déconnecté ou instance inexistante).
KFramework.Server.Instance.setPlayerInstance = function(_src, idInstance)
    _src = tonumber(_src)
    if not KFramework.Server.Utils.isConnected(_src) then return false end

    local targetInstance = listInstance[idInstance]
    if idInstance ~= public and (not targetInstance or targetInstance.destroying) then
        KFramework.logDev("Erreur : L'instance " .. tostring(idInstance) .. " n'existe pas.")
        return false
    end

    local oldBucket = GetPlayerRoutingBucket(_src)
    if oldBucket == idInstance then return true end

    local vehicle = 0
    local ped = GetPlayerPed(_src)
    if DoesEntityExist(ped) then
        local veh = GetVehiclePedIsIn(ped, false)
        if DoesEntityExist(veh) and GetPedInVehicleSeat(veh, -1) == ped then vehicle = veh end
    end

    SetPlayerRoutingBucket(_src, idInstance)
    if vehicle ~= 0 then SetEntityRoutingBucket(vehicle, idInstance) end

    local old = listInstance[oldBucket]
    if old then old:removePlayer(_src) end
    if targetInstance then targetInstance:addPlayer(_src) end

    previousBuckets[_src] = oldBucket
    Player(_src).state:set("instance", idInstance, true)

    KFramework.logDev(("Joueur %s déplacé du bucket %d vers %d"):format(_src, oldBucket, idInstance))

    KFramework.toInternal("Instance:changed", _src, oldBucket, idInstance)
    if oldBucket ~= public then KFramework.toInternal("Instance:playerLeft", oldBucket, _src) end
    if idInstance ~= public then KFramework.toInternal("Instance:playerEntered", idInstance, _src) end

    KFramework.Server.Instance.destroyIfEmpty(oldBucket)
    return true
end

--- Récupère la liste des identifiants (Server IDs) des joueurs présents dans une instance spécifique.
---@param idInstance number/string L'identifiant unique de l'instance concernée.
---@return table Une copie de la liste des identifiants des joueurs, ou une table vide si l'instance n'existe pas.
KFramework.Server.Instance.getPlayers = function(idInstance)
    local instance = listInstance[idInstance]
    if not instance then return {} end
    return instance:getPlayers()
end

--- Récupère le nombre total de joueurs actuellement présents dans une instance spécifique.
---@param idInstance number/string L'identifiant unique de l'instance concernée.
---@return number Le nombre de joueurs présents, ou `0` si l'instance n'existe pas.
KFramework.Server.Instance.getPlayerCount = function(idInstance)
    local instance = listInstance[idInstance]
    if not instance then return 0 end
    return instance:getPlayerCount()
end

--- Vérifie si un joueur se trouve dans une instance spécifique ou dans une instance privée quelconque.
---@param _src number/string L'identifiant source (Server ID) du joueur.
---@param idInstance number/string|nil (Optionnel) L'ID de l'instance cible. Si non fourni, vérifie si le joueur est dans n'importe quelle instance privée.
---@return boolean `true` si le joueur correspond au critère d'instance, sinon `false`.
KFramework.Server.Instance.isPlayerInInstance = function(_src, idInstance)
    _src = tonumber(_src)
    if not KFramework.Server.Utils.isConnected(_src) then return false end
    local currentBucket = GetPlayerRoutingBucket(_src)
    if idInstance then return currentBucket == idInstance end
    return currentBucket ~= public
end

--- Restaure un joueur dans son instance (routing bucket) précédente, ou le renvoie dans l'instance publique par défaut.
---@param _src number/string L'identifiant source (Server ID) du joueur à restaurer.
---@return boolean `true` si la restauration s'est effectuée avec succès, sinon `false`.
KFramework.Server.Instance.restorePlayerInstance = function(_src)
    _src = tonumber(_src)
    local targetBucket = previousBuckets[_src] or public
    if not KFramework.Server.Instance.exists(targetBucket) then targetBucket = public end

    local success = KFramework.Server.Instance.setPlayerInstance(_src, targetBucket)
    previousBuckets[_src] = nil -- APRÈS l'appel : sinon setPlayerInstance le réécrit et le prochain restore fait ping-pong

    if success then
        KFramework.logDev(("Joueur %s restauré dans son bucket précédent (%d)"):format(_src, targetBucket))
    end
    return success
end

--- Déplace tous les joueurs d'une instance source vers une instance de destination.
---@param fromId number/string L'identifiant unique de l'instance source.
---@param toId number/string L'identifiant unique de l'instance de destination.
---@return number Le nombre de joueurs ayant été transférés avec succès.
KFramework.Server.Instance.movePlayers = function(fromId, toId)
    local sourceInstance = listInstance[fromId]
    if not sourceInstance or #sourceInstance.players == 0 then
        KFramework.logDev(("movePlayers: Aucune instance ou aucun joueur trouvé dans le bucket %s."):format(tostring(fromId)))
        return 0
    end

    local playersToMove = KFramework.Utils.copyList(sourceInstance.players)
    local movedCount = 0

    for _, srcPlayer in ipairs(playersToMove) do
        if KFramework.Server.Instance.setPlayerInstance(srcPlayer, toId) then
            movedCount = movedCount + 1
        end
    end

    KFramework.logDev(("movePlayers: %d joueur(s) transféré(s) du bucket %d vers le bucket %d."):format(movedCount, fromId, toId))
    return movedCount
end

--- Déplace une liste de joueurs vers une instance donnée.
---@param srcList table Une liste (tableau) d'identifiants sources (Server IDs) des joueurs à déplacer.
---@param idInstance number/string L'identifiant de l'instance de destination (ou l'instance publique).
---@return number Le nombre de joueurs ayant été déplacés avec succès.
KFramework.Server.Instance.setPlayersInstance = function(srcList, idInstance)
    if type(srcList) ~= "table" then
        KFramework.logDev("setPlayersInstance: Le paramètre 'srcList' doit être une table.")
        return 0
    end

    local movedCount = 0
    for _, srcPlayer in ipairs(srcList) do
        if KFramework.Server.Instance.setPlayerInstance(srcPlayer, idInstance) then
            movedCount = movedCount + 1
        end
    end

    KFramework.logDev(("setPlayersInstance: %d/%d joueur(s) déplacé(s) vers le bucket %s."):format(movedCount, #srcList, tostring(idInstance)))
    return movedCount
end

--- Replace un joueur dans l'instance publique par défaut.
---@param _src number/string L'identifiant source (Server ID) du joueur.
---@return boolean `true` si le déplacement s'est effectué avec succès, sinon `false`.
KFramework.Server.Instance.setOnPublicInstance = function(_src)
    return (KFramework.Server.Instance.setPlayerInstance(_src, public))
end

--- Déplace une entité spécifique vers une instance (routing bucket) donnée.
---@param entity number L'identifiant (handle) de l'entité à déplacer.
---@param idInstance number/string L'identifiant de l'instance de destination.
---@return boolean `true` si l'entité a été déplacée avec succès, `false` si l'entité ou l'instance n'existe pas.
KFramework.Server.Instance.setEntityInstance = function(entity, idInstance)
    if not DoesEntityExist(entity) then
        KFramework.logDev("setEntityInstance: L'entité spécifiée n'existe pas.")
        return false
    end

    if not KFramework.Server.Instance.exists(idInstance) then
        KFramework.logDev(("setEntityInstance: L'instance %s n'existe pas."):format(tostring(idInstance)))
        return false
    end

    SetEntityRoutingBucket(entity, idInstance)
    return true
end

--- Récupère l'identifiant de l'instance (routing bucket) dans laquelle se trouve une entité.
---@param entity number L'identifiant (handle) de l'entité.
---@return number|nil L'identifiant du routing bucket de l'entité, ou `nil` si l'entité n'existe pas.
KFramework.Server.Instance.getEntityInstance = function(entity)
    if not DoesEntityExist(entity) then
        KFramework.logDev("getEntityInstance: L'entité spécifiée n'existe pas.")
        return nil
    end
    return GetEntityRoutingBucket(entity)
end

--- Récupère toutes les entités (véhicules, peds non-joueurs, objets) présentes dans une instance spécifique.
---@param idInstance number/string L'identifiant unique de l'instance concernée.
---@return table Un tableau contenant la liste des entités triées par catégorie (`vehicles`, `peds`, `objects`) et le nombre `total`, ou un tableau d'entités vide si l'instance n'existe pas.
KFramework.Server.Instance.getEntities = function(idInstance)
    local instance = listInstance[idInstance]
    if not instance then return { vehicles = {}, peds = {}, objects = {}, total = 0 } end
    return instance:getEntities()
end

--- Supprime et purge toutes les entités présente dans une instance donnée (exclut l'instance publique).
---@param idInstance number/string L'identifiant unique de l'instance concernée.
---@return number Le nombre total d'entités supprimées, ou `0` s'il s'agit du bucket public ou si l'instance n'existe pas.
KFramework.Server.Instance.clearEntities = function(idInstance)
    if idInstance == public then return 0 end
    local instance = listInstance[idInstance]
    if not instance then return 0 end
    return instance:clearEntities()
end

--- Modifie le mode de confinement des entités (lockdown mode) pour une instance donnée.
---@param idInstance number/string L'identifiant unique de l'instance concernée (l'instance publique ne peut pas être modifiée).
---@param status string Le mode de confinement à appliquer (`"strict"`, `"relaxed"` ou `"inactive"`).
---@return boolean `true` si le mode de confinement a été appliqué, `false` si l'instance est publique ou si le statut est invalide.
KFramework.Server.Instance.setLockdown = function(idInstance, status)
    if idInstance == public then return false end -- "strict" sur le public casserait tous les scripts qui spawnent côté client
    if not validStatus[status] then
        KFramework.logDev(("setLockdown: Statut '%s' invalide (attendu: 'strict', 'relaxed', 'inactive')."):format(tostring(status)))
        return false
    end

    SetRoutingBucketEntityLockdownMode(idInstance, status)
    if listInstance[idInstance] then listInstance[idInstance].status = status end
    return true
end

--- Active ou désactive la génération de population (peds et trafic ambiants) pour une instance spécifique.
---@param idInstance number/string L'identifiant unique de l'instance concernée (l'instance publique ne peut pas être modifiée).
---@param enabled boolean `true` pour activer la population ambiante, `false` pour la désactiver.
---@return boolean `true` si le réglage de la population a été appliqué, `false` si l'instance est publique.
KFramework.Server.Instance.setPopulation = function(idInstance, enabled)
    if idInstance == public then return false end

    local isEnabled = enabled and true or false
    SetRoutingBucketPopulationEnabled(idInstance, isEnabled)
    if listInstance[idInstance] then listInstance[idInstance].population = isEnabled end
    return true
end

--- Récupère les informations détaillées (snapshot) d'une instance spécifique, avec option d'inclure la liste de ses entités.
---@param idInstance number/string L'identifiant unique de l'instance concernée.
---@param withEntities boolean|nil (Optionnel) Si `true`, inclut les entités présentes dans l'instance dans les informations retournées.
---@return table|nil Une table contenant l'instantané des informations de l'instance (et ses entités si demandé), ou `nil` si l'instance n'existe pas.
KFramework.Server.Instance.getInfo = function(idInstance, withEntities)
    local instance = listInstance[idInstance]
    if not instance then
        KFramework.logDev(("getInfo: L'instance %s n'existe pas."):format(tostring(idInstance)))
        return nil
    end

    local info = instance:snapshot()
    if withEntities then info.entities = KFramework.Server.Instance.getEntities(idInstance) end
    return (info)
end

--- Définit ou met à jour une métadonnée spécifique sur une instance donnée.
---@param idInstance number/string L'identifiant unique de l'instance concernée.
---@param key string La clé de la métadonnée à enregistrer ou modifier.
---@param value any La valeur à attribuer à la métadonnée.
---@return boolean `true` si la métadonnée a été mise à jour avec succès, `false` si l'instance n'existe pas.
KFramework.Server.Instance.setMeta = function(idInstance, key, value)
    local instance = listInstance[idInstance]
    if not instance then
        KFramework.logDev(("setMeta: L'instance %s n'existe pas."):format(tostring(idInstance)))
        return false
    end
    instance:setMeta(key, value)   -- au lieu de instance.metadata = ... / instance.metadata[key] = ...
    KFramework.logDev(("setMeta: Métadonnée '%s' mise à jour sur l'instance %d"):format(key, idInstance))
    return true
end

--- Récupère une métadonnée spécifique ou l'ensemble des métadonnées associées à une instance donnée.
---@param idInstance number/string L'identifiant unique de l'instance concernée.
---@param key string|nil (Optionnel) La clé de la métadonnée. Si omit, retourne la table complète des métadonnées.
---@return any|table|nil La valeur de la métadonnée, l'ensemble des métadonnées, ou `nil` si l'instance n'existe pas ou si la clé n'est pas définie.
KFramework.Server.Instance.getMeta = function(idInstance, key)
    local instance = listInstance[idInstance]
    if not instance then return nil end
    return instance:getMeta(key)
end

--- Déclenche un événement client (event) pour l'ensemble des joueurs présents dans une instance donnée.
---@param idInstance number/string L'identifiant unique de l'instance concernée.
---@param eventName string Le nom de l'événement client à déclencher.
---@param ... any (Optionnel) Les arguments à transmettre à l'événement client.
---@return boolean `true` si l'événement a été envoyé à au moins un joueur connecté dans l'instance, sinon `false`.
KFramework.Server.Instance.emitToInstance = function(idInstance, eventName, ...)
    local instance = listInstance[idInstance]
    if not instance then
        KFramework.logDev(("emitToInstance: L'instance %s n'existe pas."):format(tostring(idInstance)))
        return false
    end

    if #instance.players == 0 then return false end

    local sent = 0
    for _, srcPlayer in ipairs(instance.players) do
        if KFramework.Server.Utils.isConnected(srcPlayer) then
            TriggerClientEvent(eventName, srcPlayer, ...)
            sent = sent + 1
        end
    end

    KFramework.logDev(("emitToInstance: Événement '%s' envoyé à %d joueur(s) dans le bucket %d."):format(eventName, sent, idInstance))
    return sent > 0
end

--- Gestionnaire d'événement exécuté lorsqu'un joueur se déconnecte du serveur.
--- Nettoie le suivi de l'ancien bucket du joueur, le retire de toutes les instances non-publiques dans lesquelles il était présent,
--- et déclenche la destruction des instances désormais vides.
---@return void
AddEventHandler("playerDropped", function()
    local _src = source
    _src = tonumber(_src)
    previousBuckets[_src] = nil

    local touched = {}
    for idInstance, instance in pairs(listInstance) do
        if idInstance ~= public then
            for _, playerSrc in ipairs(instance.players) do
                if playerSrc == _src then touched[#touched + 1] = idInstance break end
            end
        end
    end

    for _, idInstance in ipairs(touched) do
        listInstance[idInstance]:removePlayer(_src)
        KFramework.logDev(("playerDropped: Joueur %s retiré de l'instance %d"):format(_src, idInstance))
        KFramework.Server.Instance.destroyIfEmpty(idInstance)
    end
end)

--- Gestionnaire d'événement déclenché lorsqu'une ressource est arrêtée.
--- Nettoie et détruit toutes les instances créées par la ressource qui s'arrête, ou détruit toutes les instances du système si la ressource actuelle elle-même s'arrête.
---@param resName string Le nom de la ressource en cours d'arrêt.
AddEventHandler("onResourceStop", function(resName)
    local ours = resName == GetCurrentResourceName()

    local toDestroy = {}
    for id, instance in pairs(listInstance) do
        if ours or instance.creatorResource == resName then
            toDestroy[#toDestroy + 1] = id
        end
    end
    for _, id in ipairs(toDestroy) do
        KFramework.Server.Instance.destroy(id)
    end
end)

--- TODO : Pour remettre les joueurs a leurs connections dans leurs apparte ou tous autres instances

KFramework.loadedComponent('Instance')