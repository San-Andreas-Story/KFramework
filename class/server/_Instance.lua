--- Classe représentant la structure et l'instanciation d'un objet Instance.
---@class Instance
---@field id number/string L'identifiant unique de l'instance.
---@field name string|nil Le nom personnalisé attribué à l'instance.
---@field status string Le mode de confinement des entités (`"strict"`, `"relaxed"`, `"inactive"`).
---@field population boolean Indique si la population ambiante est activée.
---@field persistent boolean Indique si l'instance persiste même lorsqu'elle est vide.
---@field creatorResource string Le nom de la ressource FiveM ayant créé l'instance.
---@field ttlTimer table|nil Référence vers le timer de suppression (TTL).
---@field players table Liste des identifiants sources (Server IDs) des joueurs présents.
---@field metadata table|nil Métadonnées personnalisées associées à l'instance.
---@field destroying boolean État indiquant si l'instance est en cours de destruction.
_Instance = {}
_Instance.__index = _Instance

--- Constructeur permettant d'instancier un objet `_Instance` via appel de table.
---@param data table Table contenant les propriétés initiales de l'instance (`id`, `name`, `status`, `population`, `persistent`, `creatorResource`, `metadata`).
---@return Instance La nouvelle instance de classe `_Instance` créée.
setmetatable(_Instance, {
    __call = function(_, data)
        local self = setmetatable({}, _Instance)
        self.id = data.id
        self.name = data.name
        self.status = data.status or "strict"
        self.population = data.population == true 
        self.persistent = data.persistent == true 
        self.creatorResource = data.creatorResource
        self.ttlTimer = nil 
        self.players = {}
        self.metadata = data.metadata 
        self.destroying = false 
        return self 
    end
})

--- Ajoute un joueur à l'instance courante s'il n'y est pas déjà présent.
---@param _src number/string L'identifiant source (Server ID) du joueur à ajouter.
---@return void
function _Instance:addPlayer(_src)
    if self:hasPlayer(_src) then return end
    table.insert(self.players, _src)
end

--- Retire un joueur de l'instance courante.
---@param _src number/string L'identifiant source (Server ID) du joueur à retirer.
---@return void
function _Instance:removePlayer(_src)
    for i = #self.players, 1, -1 do
        if self.players[i] == _src then table.remove(self.players, i) end
    end
end

--- Retourne une copie de la liste des joueurs présents dans l'instance courante.
---@return table Une copie de la liste des identifiants (Server IDs) des joueurs.
function _Instance:getPlayers()
    return KFramework.Utils.copyList(self.players)
end

--- Purge la liste des joueurs de l'instance en supprimant ceux qui sont déconnectés ou qui ne sont plus dans ce routing bucket.
---@return void
function _Instance:pruneStalePlayers()
    for i = #self.players, 1, -1 do
        local srcPlayer = self.players[i]
        if not KFramework.Server.Utils.isConnected(srcPlayer) or GetPlayerRoutingBucket(srcPlayer) ~= self.id then
            table.remove(self.players, i)
        end
    end
end

--- Configure un temporisateur d'expiration (TTL) pour l'instance, déclenchant un callback à son terme.
---@param seconds number Le délai en secondes avant expiration. Si <= 0, annule le temporisateur.
---@param onExpire function La fonction de rappel exécutée à l'expiration (reçoit l'ID de l'instance en argument).
---@field ttlTimer number|nil Jeton (compteur) du TTL actif, sert à invalider un ancien timer si un nouveau TTL est défini entre-temps.
---@return boolean `true` si le TTL a été configuré ou réinitialisé, `false` si la fonction de rappel est invalide.
function _Instance:setTTL(seconds, onExpire)
    if type(seconds) ~= "number" or seconds <= 0 then
        self.ttlTimer = nil
        return true
    end
    if type(onExpire) ~= "function" then return false end
    self.ttlTimer = (self.ttlTimer or 0) + 1
    local token = self.ttlTimer
    SetTimeout(seconds * 1000, function()
        if self.ttlTimer == token and not self.destroying then
            onExpire(self.id)
        end
    end)
    return true
end

--- Récupère toutes les entités (véhicules, peds non-joueurs, objets) présentes dans l'instance courante.
---@return table Un tableau contenant la liste des entités triées par catégorie (`vehicles`, `peds`, `objects`) et le nombre `total`.
function _Instance:getEntities()
    local entities = { vehicles = {}, peds = {}, objects = {}, total = 0 }
    for _, veh in ipairs(GetAllVehicles()) do
        if GetEntityRoutingBucket(veh) == self.id then
            table.insert(entities.vehicles, veh); entities.total = entities.total + 1
        end
    end
    for _, ped in ipairs(GetAllPeds()) do
        if not IsPedAPlayer(ped) and GetEntityRoutingBucket(ped) == self.id then
            table.insert(entities.peds, ped); entities.total = entities.total + 1
        end
    end
    for _, obj in ipairs(GetAllObjects()) do
        if GetEntityRoutingBucket(obj) == self.id then
            table.insert(entities.objects, obj); entities.total = entities.total + 1
        end
    end
    return entities
end

--- Supprime et purge toutes les entités (véhicules, peds non-joueurs, objets) présentes dans l'instance courante.
---@return number Le nombre total d'entités ayant été supprimées.
function _Instance:clearEntities()
    local entities = self:getEntities()
    local deletedCount = 0
    for _, list in ipairs({ entities.vehicles, entities.peds, entities.objects }) do
        for _, entity in ipairs(list) do
            if DoesEntityExist(entity) then DeleteEntity(entity); deletedCount = deletedCount + 1 end
        end
    end
    return deletedCount
end

--- Vérifie si un joueur spécifique est présent dans l'instance courante.
---@param _src number/string L'identifiant source (Server ID) du joueur.
---@return boolean `true` si le joueur fait partie de l'instance, sinon `false`.
function _Instance:hasPlayer(_src)
    for _, s in ipairs(self.players) do
        if s == _src then return true end
    end
    return false
end

--- Retourne le nombre total de joueurs enregistrés dans l'instance courante.
---@return number Le nombre de joueurs actuellement présents dans l'instance.
function _Instance:getPlayerCount()
    return #self.players
end

--- Indique si l'instance courante est vide (ne contient aucun joueur).
---@return boolean `true` si aucun joueur n'est présent dans l'instance, sinon `false`.
function _Instance:isEmpty()
    return #self.players == 0
end

--- Définit ou met à jour une métadonnée sur l'instance courante.
---@param key string La clé de la métadonnée.
---@param value any La valeur à associer à la clé.
---@return void
function _Instance:setMeta(key, value)
    self.metadata = self.metadata or {}
    self.metadata[key] = value
end

--- Récupère une métadonnée spécifique ou l'ensemble des métadonnées de l'instance courante.
---@param key string|nil (Optionnel) La clé de la métadonnée. Si omitted, retourne la table complète des métadonnées.
---@return any|table|nil La valeur de la métadonnée, l'ensemble des métadonnées, ou `nil` si aucune métadonnée n'est définie.
function _Instance:getMeta(key)
    if not self.metadata then return nil end
    if not key then return self.metadata end
    return self.metadata[key]
end

--- Génère un instantané (snapshot) de l'état actuel de l'instance sous forme de table.
---@return table Une table contenant les données d'état, la liste des joueurs, le nombre de joueurs et les métadonnées.
function _Instance:snapshot()
    return {
        id = self.id,
        name = self.name,
        status = self.status,
        population = self.population,
        persistent = self.persistent,
        creatorResource = self.creatorResource,
        players = KFramework.Utils.copyList(self.players),
        playerCount = #self.players,
        hasTTL = self.ttlTimer ~= nil,
        metadata = self.metadata,
    }
end

--- Prépare et formate les données de l'instance pour leur sauvegarde en base de données.
---@return table Une table structurée contenant le nom, le statut, la persistance et les métadonnées sérialisées en JSON.
function _Instance:toDB()
    return {
        name = self.name,
        status = self.status,
        persistent = self.persistent,
        metadata = self.metadata and json.encode(self.metadata) or nil,
    }
end

--- Désérialise et formate un enregistrement issu de la base de données pour reconstruire les paramètres d'une instance.
---@param row table La ligne d'enregistrement extraite de la base de données.
---@return table Une table contenant le nom, le statut, la persistance convertie en booléen et les métadonnées décodées.
function _Instance.fromDB(row)
    return {
        name = row.name,
        status = row.status,
        persistent = row.persistent == 1 or row.persistent == true,
        metadata = row.metadata and json.decode(row.metadata) or nil,
    }
end
