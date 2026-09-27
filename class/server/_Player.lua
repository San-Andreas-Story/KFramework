--- Classe représentant un joueur connecté et son personnage actif.
---@class Player
---@field source number L'identifiant source (Server ID) du joueur.
---@field identifier string L'identifiant unique et persistant du joueur (ex: sa license).
---@field charId number|nil L'identifiant du personnage actif en base de données (nil tant qu'aucun personnage n'est chargé/créé).
---@field name string|nil Le nom du personnage actif.
---@field position table|nil Les dernières coordonnées connues du personnage (pour la sauvegarde).
---@field metadata table|nil Métadonnées personnalisées associées au personnage.
---@field loaded boolean Indique si le personnage est chargé et jouable.
---@field saving boolean Verrou anti-sauvegarde concurrente.
_Player = {}
_Player.__index = _Player

--- Constructeur permettant d'instancier un objet `_Player` via appel de table.
---@param data table Table contenant les propriétés initiales (`source`, `identifier`, `charId`, `name`, `position`, `metadata`, `loaded`).
---@return Player Le nouvel objet `_Player` créé.
setmetatable(_Player, {
    __call = function(_, data)
        local self = setmetatable({}, _Player)
        self.source = tonumber(data.source)
        self.identifier = data.identifier
        self.charId = data.charId
        self.name = data.name
        self.position = data.position
        self.metadata = data.metadata
        self.loaded = data.loaded == true
        self.saving = false
        return self
    end
})

--- Définit si le personnage courant est chargé et prêt à être joué.
---@param bool boolean `true` si le personnage est chargé et jouable, `false` sinon.
---@return void
function _Player:setLoaded(bool)
    self.loaded = bool == true
end

--- Vérifie si le personnage courant est chargé et jouable.
---@return boolean `true` si le personnage est chargé, sinon `false`.
function _Player:isLoaded()
    return self.loaded == true
end

--- Définit le nom du personnage actif.
---@param name string Le nom à attribuer au personnage.
---@return void
function _Player:setName(name)
    self.name = name
end

--- Récupère le nom du personnage actif.
---@return string|nil Le nom du personnage, ou `nil` si aucun nom n'est encore défini.
function _Player:getName()
    return self.name
end

--- Met à jour les dernières coordonnées connues du personnage (utilisées notamment lors de la sauvegarde en base de données).
---@param coords table Une table de coordonnées (ex: `{x = 0.0, y = 0.0, z = 0.0, heading = 0.0}`).
---@return void
function _Player:setPosition(coords)
    if type(coords) ~= "table" then return end
    self.position = { x = coords.x, y = coords.y, z = coords.z, heading = coords.heading }
end

--- Récupère les dernières coordonnées connues du personnage.
---@return table|nil Une table de coordonnées, ou `nil` si aucune position n'a encore été enregistrée.
function _Player:getPosition()
    return self.position
end

--- Définit ou met à jour une métadonnée personnalisée sur le personnage courant.
---@param key string La clé de la métadonnée.
---@param value any La valeur à associer à la clé.
---@return void
function _Player:setMeta(key, value)
    self.metadata = self.metadata or {}
    self.metadata[key] = value

end

--- Récupère une métadonnée spécifique ou l'ensemble des métadonnées du personnage courant.
---@param key string|nil (Optionnel) La clé de la métadonnée à récupérer. Si non spécifiée, retourne la table complète des métadonnées.
---@return any|table|nil La valeur de la métadonnée, la table complète des métadonnées, ou `nil` si aucune métadonnée n'est définie.
function _Player:getMeta(key)
    if not self.metadata then return nil end
    if not key then return self.metadata end
    return self.metadata[key]

end

--- Pose un verrou indiquant qu'une sauvegarde est en cours sur ce personnage.
--- Sert à éviter un enregistrement concurrent (ex: une sauvegarde périodique et une déconnexion qui se chevauchent).
---@return boolean `true` si le verrou a été posé avec succès, `false` s'il était déjà posé (l'appelant doit alors annuler ou reporter sa sauvegarde).
function _Player:beginSave()
    if self.saving then return false end
    self.saving = true
    return true
end

--- Lève le verrou de sauvegarde posé par `beginSave`, une fois l'écriture en base de données terminée.
---@return void
function _Player:endSave()
    self.saving = false
end

--- Génère un instantané (snapshot) de l'état actuel du personnage sous forme de table.
---@return table Une table contenant les données publiques du personnage (source, identifiant, nom, statut de chargement, métadonnées...).
function _Player:snapshot()
    return {
        source = self.source,
        identifier = self.identifier,
        charId = self.charId,
        name = self.name,
        position = self.position,
        loaded = self.loaded,
        metadata = self.metadata,
    }

end

--- Prépare et formate les données du personnage pour leur sauvegarde en base de données.
---@return table Une table structurée contenant les champs à écrire en base (nom, position, métadonnées sérialisées en JSON...).
function _Player:toDB()
        return {
        identifier = self.identifier,
        charId = self.charId,
        name = self.name,
        position = self.position and json.encode(self.position) or nil,
        metadata = self.metadata and json.encode(self.metadata) or nil,
    }

end

--- Désérialise et formate un enregistrement issu de la base de données pour reconstruire les paramètres d'un personnage.
--- Fonction "statique" (notez le `.` et non `:`) : comme `_Instance.fromDB`, elle ne s'appelle PAS sur un objet `_Player`
--- existant (`joueur:fromDB(row)` serait incorrect) mais directement via `_Player.fromDB(row)`, car son rôle est de
--- préparer les données AVANT la création de l'objet, pas de modifier un objet déjà construit.
---@param row table La ligne d'enregistrement extraite de la base de données.
---@return table Une table contenant le nom, la position et les métadonnées décodées, prête à être passée au constructeur `_Player(data)`.
function _Player.fromDB(row)
    return {
        identifier = row.identifier,
        charId = row.charId or row.id,
        name = row.name,
        position = row.position and json.decode(row.position) or nil,
        metadata = row.metadata and json.decode(row.metadata) or nil,
        loaded = false,
    }

end

--- Réinitialise les données du personnage actif (nom, position, métadonnées, charId) tout en conservant l'identité
--- de connexion du joueur (`source`, `identifier`). Utile en cas de suppression/recréation de personnage sans
--- déconnecter le joueur du serveur.
---@return void
function _Player:resetCharacter()
    self.charId = nil
    self.name = nil
    self.position = nil
    self.metadata = nil
    self.loaded = false
end