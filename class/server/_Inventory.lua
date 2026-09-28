--- Classe représentant un inventaire (poches d'un joueur, coffre de véhicule, stash, sol...) et la gestion de son contenu.
--- Le contenu (`items`) est indexé par numéro de slot : `items[3] = { name = "water", count = 2, metadata = nil }`.
--- Le poids et les définitions des items (label, poids, stackable, usable...) proviennent de la table globale `_Items`
--- (voir `config/items.lua`) : cette classe ne stocke jamais elle-même ces informations statiques.
---@class Inventory
---@field id string L'identifiant unique de l'inventaire (ex: "player:12", "trunk:AB-123-CD", "drop:42").
---@field type string Le type d'inventaire ("player", "stash", "trunk", "drop", "shop"...).
---@field owner string|number|nil L'identifiant du propriétaire selon le type (charId, plaque, nom du stash...).
---@field label string|nil Le nom affiché de l'inventaire (ex: "Poches", "Coffre").
---@field slots number Le nombre maximal d'emplacements (slots) de l'inventaire.
---@field maxWeight number Le poids maximal supporté par l'inventaire, en grammes.
---@field items table<number, table> Table indexée par numéro de slot, contenant les stacks d'items (`{name, count, metadata}`).
---@field openedBy table<number, boolean> Ensemble des sources ayant actuellement cet inventaire ouvert (anti-duplication).
---@field temporary boolean Indique si l'inventaire ne doit jamais être persisté en base (ex: sol, loot ponctuel).
---@field metadata table|nil Métadonnées personnalisées associées à l'inventaire.
_Inventory = {}
_Inventory.__index = _Inventory

--- Récupère la définition statique d'un item depuis la table de configuration globale `_Items`.
---@param name string Le nom technique de l'item.
---@return table|nil La définition de l'item (label, weight, stackable, usable...), ou `nil` si elle n'existe pas.
local function getItemDef(name)
    return _Items and _Items[name] or nil
end

--- Constructeur permettant d'instancier un objet `_Inventory` via appel de table.
---@param data table Table contenant les propriétés initiales (`id`, `type`, `owner`, `label`, `slots`, `maxWeight`, `items`, `temporary`, `metadata`).
---@return Inventory Le nouvel objet `_Inventory` créé.
setmetatable(_Inventory, {
    __call = function(_, data)
        local self = setmetatable({}, _Inventory)
        self.id = data.id
        self.type = data.type or "player"
        self.owner = data.owner
        self.label = data.label
        self.slots = tonumber(data.slots) or (_Config.inventory and _Config.inventory.defaultSlots) or 40
        self.maxWeight = tonumber(data.maxWeight) or (_Config.inventory and _Config.inventory.defaultWeight) or 30000
        self.items = data.items or {}
        self.openedBy = {}
        self.temporary = data.temporary == true
        self.metadata = data.metadata
        return self
    end
})

--- Calcule le poids total actuellement utilisé dans l'inventaire, à partir des définitions d'items (`_Items`).
---@return number Le poids total, en grammes.
function _Inventory:getWeight()
    local total = 0
    for _, stack in pairs(self.items) do
        local def = getItemDef(stack.name)
        if def then
            total = total + ((def.weight or 0) * stack.count)
        end
    end
    return total
end

--- Calcule le poids encore disponible dans l'inventaire avant d'atteindre `maxWeight`.
---@return number Le poids restant disponible, en grammes (jamais négatif).
function _Inventory:getFreeWeight()
    local free = self.maxWeight - self:getWeight()
    return free > 0 and free or 0
end

--- Recherche le premier emplacement (slot) libre de l'inventaire.
---@return number|nil Le numéro du premier slot libre, ou `nil` si l'inventaire est plein.
function _Inventory:getFreeSlot()
    for slot = 1, self.slots do
        if not self.items[slot] then return slot end
    end
    return nil
end

--- Vérifie si l'inventaire est totalement plein (aucun emplacement libre).
---@return boolean `true` si tous les emplacements sont occupés, sinon `false`.
function _Inventory:isFull()
    return self:getFreeSlot() == nil
end

--- Vérifie si l'inventaire ne contient aucun item.
---@return boolean `true` si l'inventaire est vide, sinon `false`.
function _Inventory:isEmpty()
    return next(self.items) == nil
end

--- Vérifie si l'inventaire peut accueillir une quantité donnée d'un item (poids et emplacement disponibles).
---@param name string Le nom technique de l'item.
---@param count number La quantité à ajouter.
---@return boolean `true` si l'item peut être ajouté, sinon `false`.
---@return string|nil La raison du refus (`"unknown_item"`, `"too_heavy"`, `"no_slot"`), ou `nil` si l'ajout est possible.
function _Inventory:canHold(name, count)
    local def = getItemDef(name)
    if not def then return false, "unknown_item" end

    count = tonumber(count) or 1
    if self:getWeight() + ((def.weight or 0) * count) > self.maxWeight then
        return false, "too_heavy"
    end

    -- Un item stackable "nu" (sans metadata) peut toujours rejoindre un stack existant, même si l'inventaire est plein.
    if def.stackable then
        for _, stack in pairs(self.items) do
            if stack.name == name and not stack.metadata then return true end
        end
    end

    if self:isFull() then return false, "no_slot" end
    return true
end

--- Récupère le contenu d'un emplacement précis de l'inventaire.
---@param slot number Le numéro de l'emplacement.
---@return table|nil Le stack présent (`{name, count, metadata}`), ou `nil` si l'emplacement est vide.
function _Inventory:getSlot(slot)
    return self.items[slot]
end

--- Ajoute une quantité d'un item à l'inventaire : empile d'abord sur un stack existant compatible
--- (item stackable, sans metadata distinctive), puis utilise des emplacements libres pour le reste.
---@param name string Le nom technique de l'item à ajouter.
---@param count number|nil La quantité à ajouter (par défaut 1).
---@param metadata table|nil Métadonnées propres à ce stack (rend l'item non-empilable avec un stack "nu").
---@return boolean `true` si la quantité demandée a été intégralement ajoutée, sinon `false`.
---@return string|nil La raison de l'échec (`"unknown_item"`, `"invalid_count"`, `"too_heavy"`, `"no_slot"`), ou `nil` en cas de succès.
function _Inventory:addItem(name, count, metadata)
    count = tonumber(count) or 1
    if count <= 0 then return false, "invalid_count" end

    local def = getItemDef(name)
    if not def then return false, "unknown_item" end

    local ok, reason = self:canHold(name, count)
    if not ok then return false, reason end

    local remaining = count

    if def.stackable and not metadata then
        for slot = 1, self.slots do
            if remaining <= 0 then break end
            local stack = self.items[slot]
            if stack and stack.name == name and not stack.metadata then
                stack.count = stack.count + remaining
                remaining = 0
            end
        end
    end

    while remaining > 0 do
        local slot = self:getFreeSlot()
        if not slot then return false, "no_slot" end

        if def.stackable then
            self.items[slot] = { name = name, count = remaining, metadata = metadata }
            remaining = 0
        else
            self.items[slot] = { name = name, count = 1, metadata = metadata }
            remaining = remaining - 1
        end
    end

    return true
end

--- Retire une quantité d'un item de l'inventaire, depuis un emplacement précis ou automatiquement
--- (en piochant dans le(s) premier(s) stack(s) correspondant(s) trouvé(s)).
---@param name string Le nom technique de l'item à retirer.
---@param count number|nil La quantité à retirer (par défaut 1).
---@param slot number|nil (Optionnel) L'emplacement précis depuis lequel retirer l'item.
---@return boolean `true` si la quantité demandée a été intégralement retirée, sinon `false` (rien n'est modifié dans ce cas).
function _Inventory:removeItem(name, count, slot)
    count = tonumber(count) or 1
    if count <= 0 then return false end
    if self:getItemCount(name) < count then return false end

    if slot then
        local stack = self.items[slot]
        if not stack or stack.name ~= name or stack.count < count then return false end
        stack.count = stack.count - count
        if stack.count <= 0 then self.items[slot] = nil end
        return true
    end

    local remaining = count
    for s = 1, self.slots do
        if remaining <= 0 then break end
        local stack = self.items[s]
        if stack and stack.name == name then
            local removeCount = math.min(stack.count, remaining)
            stack.count = stack.count - removeCount
            remaining = remaining - removeCount
            if stack.count <= 0 then self.items[s] = nil end
        end
    end

    return remaining == 0
end

--- Calcule la quantité totale d'un item donné, tous emplacements confondus.
---@param name string Le nom technique de l'item.
---@return number La quantité totale possédée.
function _Inventory:getItemCount(name)
    local total = 0
    for _, stack in pairs(self.items) do
        if stack.name == name then total = total + stack.count end
    end
    return total
end

--- Vérifie si l'inventaire contient au moins une quantité donnée d'un item.
---@param name string Le nom technique de l'item.
---@param count number|nil La quantité minimale recherchée (par défaut 1).
---@return boolean `true` si la quantité est possédée, sinon `false`.
function _Inventory:hasItem(name, count)
    return self:getItemCount(name) >= (tonumber(count) or 1)
end

--- Récupère la liste de tous les emplacements contenant un item donné.
---@param name string Le nom technique de l'item.
---@return table Un tableau de `{slot, name, count, metadata}`, trié par numéro de slot croissant.
function _Inventory:getItemsByName(name)
    local found = {}
    for slot = 1, self.slots do
        local stack = self.items[slot]
        if stack and stack.name == name then
            found[#found + 1] = { slot = slot, name = stack.name, count = stack.count, metadata = stack.metadata }
        end
    end
    return found
end

--- Déplace (ou fusionne) un stack d'un emplacement vers un autre, au sein du même inventaire.
--- Ne gère pas l'échange (swap) de deux stacks différents : dans ce cas, la fonction échoue et laisse
--- au component appelant le soin de décider comment traiter le conflit.
---@param fromSlot number L'emplacement source.
---@param toSlot number L'emplacement de destination.
---@param count number|nil La quantité à déplacer (par défaut : tout le stack).
---@return boolean `true` si le déplacement a été effectué, sinon `false`.
function _Inventory:moveItem(fromSlot, toSlot, count)
    local fromStack = self.items[fromSlot]
    if not fromStack then return false end
    if fromSlot == toSlot then return true end
    if toSlot < 1 or toSlot > self.slots then return false end

    count = tonumber(count) or fromStack.count
    if count <= 0 or count > fromStack.count then return false end

    local toStack = self.items[toSlot]

    if not toStack then
        self.items[toSlot] = { name = fromStack.name, count = count, metadata = fromStack.metadata }
    elseif toStack.name == fromStack.name and not toStack.metadata and not fromStack.metadata then
        toStack.count = toStack.count + count
    else
        return false
    end

    fromStack.count = fromStack.count - count
    if fromStack.count <= 0 then self.items[fromSlot] = nil end

    return true
end

--- Vide intégralement l'inventaire (ex: nettoyage d'un inventaire "sol" expiré).
---@return void
function _Inventory:clear()
    self.items = {}
end

--- Marque l'inventaire comme actuellement consulté par un joueur (anti-duplication sur les inventaires partagés).
---@param source number Le Server ID du joueur.
---@return void
function _Inventory:open(source)
    self.openedBy[source] = true
end

--- Retire un joueur de la liste de ceux ayant actuellement l'inventaire ouvert.
---@param source number Le Server ID du joueur.
---@return void
function _Inventory:close(source)
    self.openedBy[source] = nil
end

--- Vérifie si l'inventaire est actuellement ouvert par un joueur autre que celui donné.
--- Utile pour empêcher deux joueurs d'ouvrir simultanément le même coffre/stash (duplication d'items).
---@param source number Le Server ID du joueur qui souhaite l'ouvrir.
---@return boolean `true` si un tiers a déjà l'inventaire ouvert, sinon `false`.
function _Inventory:isLockedByOther(source)
    for openedSrc in pairs(self.openedBy) do
        if openedSrc ~= source then return true end
    end
    return false
end

--- Définit ou met à jour une métadonnée personnalisée sur l'inventaire courant.
---@param key string La clé de la métadonnée.
---@param value any La valeur à associer à la clé.
---@return void
function _Inventory:setMeta(key, value)
    self.metadata = self.metadata or {}
    self.metadata[key] = value
end

--- Récupère une métadonnée spécifique ou l'ensemble des métadonnées de l'inventaire courant.
---@param key string|nil (Optionnel) La clé de la métadonnée. Si omise, retourne la table complète.
---@return any|table|nil La valeur de la métadonnée, la table complète, ou `nil` si aucune métadonnée n'est définie.
function _Inventory:getMeta(key)
    if not self.metadata then return nil end
    if not key then return self.metadata end
    return self.metadata[key]
end

--- Génère un instantané (snapshot) de l'état actuel de l'inventaire, destiné à être envoyé au client (NUI).
---@return table Une table contenant l'identité, la capacité, le poids courant et le contenu de l'inventaire.
function _Inventory:snapshot()
    return {
        id = self.id,
        type = self.type,
        owner = self.owner,
        label = self.label,
        slots = self.slots,
        maxWeight = self.maxWeight,
        weight = self:getWeight(),
        items = self.items,
        metadata = self.metadata,
    }
end

--- Prépare et formate les données de l'inventaire pour leur sauvegarde en base de données.
---@return table Une table structurée contenant les champs à écrire en base (contenu et métadonnées sérialisés en JSON).
function _Inventory:toDB()
    return {
        id = self.id,
        type = self.type,
        owner = self.owner,
        label = self.label,
        slots = self.slots,
        maxWeight = self.maxWeight,
        items = json.encode(self.items),
        metadata = self.metadata and json.encode(self.metadata) or nil,
    }
end

--- Désérialise et formate un enregistrement issu de la base de données pour reconstruire les paramètres d'un inventaire.
--- Fonction "statique" (notez le `.` et non `:`), à appeler via `_Inventory.fromDB(row)` avant de construire l'objet.
---@param row table La ligne d'enregistrement extraite de la base de données.
---@return table Une table prête à être passée au constructeur `_Inventory(data)`.
function _Inventory.fromDB(row)
    return {
        id = row.id,
        type = row.type,
        owner = row.owner,
        label = row.label,
        slots = tonumber(row.slots),
        maxWeight = tonumber(row.maxWeight),
        items = row.items and json.decode(row.items) or {},
        metadata = row.metadata and json.decode(row.metadata) or nil,
    }
end
