KFramework.Server.Inventory = {}

--- Registre de tous les inventaires actuellement chargés en mémoire, indexé par leur `id`
--- (ex: "player:12", "equip:12", "trunk:AB-123-CD").
local inventories = {}

--- source -> id de l'inventaire "poches" / "équipement" actuellement actifs pour ce joueur.
--- Maintenues indépendamment du component Players pour ne dépendre d'aucun ordre de chargement entre components.
local sourceToInventoryId = {}
local sourceToEquipId = {}

--- Liste ordonnée des cases de tenue (voir `_Config.inventory.wearSlots`) : l'index dans cette liste
--- correspond au numéro de slot dans l'inventaire "équipement" d'un personnage.
local WEAR_SLOTS = (_Config.inventory and _Config.inventory.wearSlots) or {}

local function playerInventoryId(charId) return ("player:%s"):format(charId) end
local function equipInventoryId(charId) return ("equip:%s"):format(charId) end
local function isEquipId(id) return type(id) == "string" and id:sub(1, 6) == "equip:" end

--- Retrouve l'index (numéro de slot) d'une catégorie de tenue dans `WEAR_SLOTS`.
---@param category string La catégorie (ex: "hat", "tshirt"...).
---@return number|nil L'index correspondant, ou `nil` si la catégorie est inconnue.
local function wearSlotIndex(category)
    for i, key in ipairs(WEAR_SLOTS) do if key == category then return i end end
    return nil
end

--- Pousse l'instantané (snapshot) courant d'un inventaire à tous les joueurs en train de le consulter.
---@param id string L'identifiant de l'inventaire à synchroniser.
---@return void
local function syncInventory(id)
    local inventory = inventories[id]
    if not inventory then return end
    local snap = inventory:snapshot()
    for src in pairs(inventory.openedBy) do
        if KFramework.Server.Utils.isConnected(src) then
            KFramework.toClient("Inventory:update", src, snap)
        end
    end
end

--- Pousse la tenue actuelle (équipement) d'un joueur à son propre client, pour mise à jour visuelle du ped.
---@param source number Le Server ID du joueur.
---@param equipId string L'identifiant de son inventaire "équipement".
---@return void
local function pushWear(source, equipId)
    local inventory = inventories[equipId]
    if not inventory then return end
    KFramework.toClient("Inventory:applyWear", source, inventory:snapshot())
end

--- Un joueur a-t-il le droit d'agir sur cet inventaire (ses propres poches/équipement, ou un inventaire
--- qu'il a légitimement ouvert via `Inventory.open`) ? Sécurité minimale contre un NUI trafiqué.
---@param source number
---@param id string
---@return boolean
local function hasAccess(source, id)
    if id == sourceToInventoryId[source] or id == sourceToEquipId[source] then return true end
    local inventory = inventories[id]
    return inventory ~= nil and inventory.openedBy[source] == true
end

--- Charge un inventaire depuis la base de données s'il existe, ou le crée avec `defaults` sinon,
--- puis l'enregistre dans le registre. Ne fait rien si l'inventaire est déjà en mémoire.
---@param id string
---@param defaults table Options de création à utiliser si aucune ligne n'existe en base.
---@param cb function|nil Callback appelé une fois l'inventaire disponible en mémoire.
---@return void
local function loadInventoryFromDB(id, defaults, cb)
    if inventories[id] then if cb then cb() end return end

    KFramework.Server.Database.query('SELECT * FROM kf_inventories WHERE id = ? LIMIT 1', { id }, function(row)
        if inventories[id] then if cb then cb() end return end -- créé entre-temps

        local opts = row and _Inventory.fromDB(row) or defaults
        opts.id = id
        inventories[id] = _Inventory(opts)
        KFramework.logDev(("Inventaire chargé : %s."):format(id))
        if cb then cb() end
    end)
end

--- Vérifie si un inventaire existe et est actuellement chargé en mémoire.
---@param id string
---@return boolean
KFramework.Server.Inventory.exists = function(id)
    return inventories[id] ~= nil
end

--- Récupère l'objet `_Inventory` brut associé à un identifiant (usage interne / autres components).
---@param id string
---@return Inventory|nil
KFramework.Server.Inventory.get = function(id)
    return inventories[id]
end

--- Crée un nouvel inventaire et l'enregistre dans le registre. Si l'identifiant existe déjà, le renvoie tel
--- quel sans l'écraser.
---@param id string
---@param opts table|nil `type`, `owner`, `label`, `slots`, `maxWeight`, `items`, `temporary`, `metadata`.
---@return Inventory
KFramework.Server.Inventory.create = function(id, opts)
    if inventories[id] then return inventories[id] end
    opts = opts or {}
    opts.id = id
    local inventory = _Inventory(opts)
    inventories[id] = inventory
    KFramework.logDev(("Inventaire créé : %s (type: %s, %d slots, %dg max)."):format(id, inventory.type, inventory.slots, inventory.maxWeight))
    KFramework.toInternal("Inventory:created", id)
    return inventory
end

--- Récupère un inventaire existant, ou le crée s'il n'existe pas encore.
---@param id string
---@param opts table|nil
---@return Inventory
KFramework.Server.Inventory.getOrCreate = function(id, opts)
    return inventories[id] or KFramework.Server.Inventory.create(id, opts)
end

--- Retire un inventaire du registre (sans le sauvegarder).
---@param id string
---@return boolean
KFramework.Server.Inventory.remove = function(id)
    if not inventories[id] then return false end
    inventories[id] = nil
    KFramework.toInternal("Inventory:removed", id)
    return true
end

--- Récupère l'identifiant de l'inventaire "poches" actuellement actif pour un joueur connecté.
---@param source number
---@return string|nil
KFramework.Server.Inventory.getPlayerInventoryId = function(source)
    return sourceToInventoryId[tonumber(source)]
end

--- Récupère l'identifiant de l'inventaire "équipement" (tenue portée) actuellement actif pour un joueur.
---@param source number
---@return string|nil
KFramework.Server.Inventory.getPlayerEquipId = function(source)
    return sourceToEquipId[tonumber(source)]
end

--- Ajoute une quantité d'un item dans un inventaire, puis synchronise son contenu.
---@param id string
---@param name string
---@param count number|nil
---@param metadata table|nil
---@return boolean
---@return string|nil
KFramework.Server.Inventory.addItem = function(id, name, count, metadata)
    local inventory = inventories[id]
    if not inventory then return false, "no_inventory" end
    local ok, reason = inventory:addItem(name, count, metadata)
    if ok then
        syncInventory(id)
        KFramework.toInternal("Inventory:itemAdded", id, name, count)
    end
    return ok, reason
end

--- Retire une quantité d'un item d'un inventaire, puis synchronise son contenu.
---@param id string
---@param name string
---@param count number|nil
---@param slot number|nil
---@return boolean
KFramework.Server.Inventory.removeItem = function(id, name, count, slot)
    local inventory = inventories[id]
    if not inventory then return false end
    local ok = inventory:removeItem(name, count, slot)
    if ok then
        syncInventory(id)
        KFramework.toInternal("Inventory:itemRemoved", id, name, count)
    end
    return ok
end

--- Vérifie si un inventaire contient au moins une quantité donnée d'un item.
---@param id string
---@param name string
---@param count number|nil
---@return boolean
KFramework.Server.Inventory.hasItem = function(id, name, count)
    local inventory = inventories[id]
    if not inventory then return false end
    return inventory:hasItem(name, count)
end

--- Récupère la quantité totale d'un item dans un inventaire donné.
---@param id string
---@param name string
---@return number
KFramework.Server.Inventory.getItemCount = function(id, name)
    local inventory = inventories[id]
    if not inventory then return 0 end
    return inventory:getItemCount(name)
end

--- Récupère l'instantané (snapshot) courant d'un inventaire.
---@param id string
---@return table|nil
KFramework.Server.Inventory.getSnapshot = function(id)
    local inventory = inventories[id]
    if not inventory then return nil end
    return inventory:snapshot()
end

--- Transfère une quantité d'item d'un inventaire vers un autre, en vérifiant que la destination peut
--- l'accueillir. Opération "tout ou rien" : rollback si l'ajout côté destination échoue malgré la vérification.
--- Fonction bas niveau : ne fait AUCUNE vérification d'accès ni de catégorie de tenue (voir `moveBetween`).
---@param fromId string
---@param toId string
---@param slot number
---@param count number|nil
---@return boolean
KFramework.Server.Inventory.transferItem = function(fromId, toId, slot, count)
    local from = inventories[fromId]
    local to = inventories[toId]
    if not from or not to then return false end

    local stack = from:getSlot(slot)
    if not stack then return false end

    count = tonumber(count) or stack.count
    if count <= 0 or count > stack.count then return false end

    if not to:canHold(stack.name, count) then return false end
    if not from:removeItem(stack.name, count, slot) then return false end

    local ok = to:addItem(stack.name, count, stack.metadata)
    if not ok then
        from:addItem(stack.name, count, stack.metadata) -- rollback (cas limite : conflit concurrent sur la destination)
        return false
    end

    syncInventory(fromId)
    syncInventory(toId)
    return true
end

--- Point d'entrée unique pour tout déplacement d'item demandé par le NUI : entre deux emplacements d'un même
--- inventaire, entre deux inventaires différents (poches <-> coffre), ou entre les poches et l'inventaire
--- "équipement" (habiller/déshabiller). Vérifie l'accès du joueur aux deux inventaires concernés, ainsi que
--- la catégorie de tenue si la destination est une case d'équipement.
---@param source number Le Server ID du joueur à l'origine de la demande.
---@param from table `{ id = string, slot = number }` — emplacement source.
---@param to table `{ id = string, slot = number }` — emplacement de destination.
---@param count number|nil La quantité à déplacer (par défaut : tout le stack ; ignoré pour un item non-empilable).
---@return boolean `true` si le déplacement a été effectué, sinon `false`.
KFramework.Server.Inventory.moveBetween = function(source, from, to, count)
    source = tonumber(source)
    if type(from) ~= "table" or type(to) ~= "table" then return false end
    if not hasAccess(source, from.id) or not hasAccess(source, to.id) then return false end

    local fromInv = inventories[from.id]
    if not fromInv then return false end
    local stack = fromInv:getSlot(from.slot)
    if not stack then return false end

    if isEquipId(to.id) then
        local def = _Items and _Items[stack.name]
        if not def or def.wear ~= WEAR_SLOTS[to.slot] then return false end
    end

    local ok
    if from.id == to.id then
        if fromInv:isLockedByOther(source) then return false end
        ok = fromInv:moveItem(from.slot, to.slot, count)
        if ok then syncInventory(from.id) end
    else
        ok = KFramework.Server.Inventory.transferItem(from.id, to.id, from.slot, count)
    end

    if ok then
        if isEquipId(from.id) then pushWear(source, from.id) end
        if isEquipId(to.id) then pushWear(source, to.id) end
    end
    return ok
end

--- Jette au sol une quantité d'item depuis un inventaire auquel le joueur a accès.
--- Ne crée pas (encore) d'inventaire "sol" ramassable : diffuse un event interne `Inventory:itemDropped`
--- pour qu'un futur component de loot au sol puisse s'y brancher.
---@param source number
---@param id string
---@param slot number
---@param count number|nil La quantité à jeter (par défaut : tout le stack).
---@return boolean
KFramework.Server.Inventory.dropItem = function(source, id, slot, count)
    source = tonumber(source)
    if not hasAccess(source, id) then return false end

    local inventory = inventories[id]
    if not inventory then return false end
    local stack = inventory:getSlot(slot)
    if not stack then return false end

    count = math.min(tonumber(count) or stack.count, stack.count)
    if count <= 0 then return false end

    local name = stack.name
    if not inventory:removeItem(name, count, slot) then return false end

    syncInventory(id)
    if isEquipId(id) then pushWear(source, id) end
    KFramework.toInternal("Inventory:itemDropped", source, name, count)
    return true
end

--- Ouvre un inventaire pour un joueur : refuse si un autre joueur l'a déjà ouvert (anti-duplication), sinon
--- envoie au client SES poches, l'inventaire ciblé (sauf si c'est déjà ses poches) et sa tenue actuelle, pour
--- affichage du double-panneau NUI.
---@param source number
---@param id string L'identifiant de l'inventaire à ouvrir (peut être les poches du joueur lui-même).
---@return boolean
KFramework.Server.Inventory.open = function(source, id)
    source = tonumber(source)
    local selfId = sourceToInventoryId[source]
    id = id or selfId -- pas d'id fourni = le joueur ouvre ses propres poches
    if not id then return false end

    local target = inventories[id]
    if not target then return false end

    if target:isLockedByOther(source) then
        KFramework.toClient("Inventory:openDenied", source, id)
        return false
    end

    local selfInv = selfId and inventories[selfId]
    local equipId = sourceToEquipId[source]
    local equipInv = equipId and inventories[equipId]

    target:open(source)
    if selfInv and selfId ~= id then selfInv:open(source) end

    KFramework.toClient("Inventory:open", source, {
        self = selfInv and selfInv:snapshot() or nil,
        target = (id ~= selfId) and target:snapshot() or nil,
        equip = equipInv and equipInv:snapshot() or nil,
    })
    return true
end

--- Ferme un inventaire pour un joueur (le retire, ainsi que ses propres poches, de la liste des personnes
--- le consultant).
---@param source number
---@param id string
---@return void
KFramework.Server.Inventory.close = function(source, id)
    source = tonumber(source)
    local target = inventories[id]
    if target then target:close(source) end

    local selfId = sourceToInventoryId[source]
    local selfInv = selfId and inventories[selfId]
    if selfInv and selfId ~= id then selfInv:close(source) end
end

--- Traite l'utilisation d'un item par un joueur, depuis son inventaire "poches" actif.
--- Si l'item est une tenue (`def.wear`), "utiliser" revient à l'équiper (transfert vers l'inventaire
--- "équipement", à la case correspondant à sa catégorie). Sinon, délègue à `def.onUse` s'il existe, sinon
--- diffuse un event interne générique `Inventory:itemUsed`, et consomme un exemplaire sauf si
--- `def.consumeOnUse` vaut explicitement `false`.
---@param source number
---@param slot number
---@return boolean
KFramework.Server.Inventory.useItem = function(source, slot)
    source = tonumber(source)
    local id = sourceToInventoryId[source]
    if not id then return false end

    local inventory = inventories[id]
    if not inventory then return false end

    local stack = inventory:getSlot(slot)
    if not stack then return false end

    local def = _Items and _Items[stack.name]
    if not def or not def.usable then return false end

    if def.wear then
        local equipId = sourceToEquipId[source]
        local slotIndex = wearSlotIndex(def.wear)
        if not equipId or not slotIndex then return false end
        return KFramework.Server.Inventory.moveBetween(source, { id = id, slot = slot }, { id = equipId, slot = slotIndex })
    end

    if type(def.onUse) == "function" then
        def.onUse(source, stack, slot)
    else
        KFramework.toInternal("Inventory:itemUsed", source, stack.name, stack.metadata)
    end

    if def.consumeOnUse ~= false then
        inventory:removeItem(stack.name, 1, slot)
        syncInventory(id)
    end

    if def.shouldClose then
        inventory:close(source)
        KFramework.toClient("Inventory:close", source, id)
    end

    return true
end

--- Sauvegarde en base de données le contenu d'un inventaire (upsert sur `kf_inventories`).
---@param id string
---@return boolean
KFramework.Server.Inventory.save = function(id)
    local inventory = inventories[id]
    if not inventory or inventory.temporary then return false end

    local data = inventory:toDB()
    KFramework.Server.Database.execute([[
        INSERT INTO kf_inventories (id, type, owner, label, slots, maxWeight, items, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            items = VALUES(items),
            slots = VALUES(slots),
            maxWeight = VALUES(maxWeight),
            metadata = VALUES(metadata)
    ]], { data.id, data.type, data.owner, data.label, data.slots, data.maxWeight, data.items, data.metadata },
        function(rowsChanged)
            if not rowsChanged then
                KFramework.Error(("Échec de la sauvegarde de l'inventaire %s."):format(id))
            end
        end)

    return true
end

--- Sauvegarde en base de données tous les inventaires actuellement chargés en mémoire (hors `temporary`).
---@return number
KFramework.Server.Inventory.saveAll = function()
    local count = 0
    for id, inventory in pairs(inventories) do
        if not inventory.temporary then
            KFramework.Server.Inventory.save(id)
            count = count + 1
        end
    end
    return count
end

--- À la connexion/chargement d'un personnage, charge ses poches ET sa tenue (équipement) depuis la base de
--- données, puis pousse la tenue au client pour habiller le ped dès l'arrivée en jeu.
KFramework.onReceive("Player:loaded", function(source, charSnapshot)
    source = tonumber(source)
    if not charSnapshot or not charSnapshot.charId then return end

    local pocketId = playerInventoryId(charSnapshot.charId)
    local equipId = equipInventoryId(charSnapshot.charId)
    sourceToInventoryId[source] = pocketId
    sourceToEquipId[source] = equipId

    loadInventoryFromDB(pocketId, { type = "player", owner = charSnapshot.charId, label = "Poches" })
    loadInventoryFromDB(equipId, {
        type = "equip", owner = charSnapshot.charId, label = "Tenue",
        slots = #WEAR_SLOTS, maxWeight = 999999,
    }, function()
        pushWear(source, equipId)
    end)
end)

--- À la déconnexion d'un joueur, sauvegarde ses poches et sa tenue puis les décharge de la mémoire.
AddEventHandler("playerDropped", function()
    local source = tonumber(source)
    local pocketId = sourceToInventoryId[source]
    local equipId = sourceToEquipId[source]
    sourceToInventoryId[source] = nil
    sourceToEquipId[source] = nil

    for _, id in ipairs({ pocketId, equipId }) do
        if id and inventories[id] then
            inventories[id]:close(source)
            KFramework.Server.Inventory.save(id)
            inventories[id] = nil
        end
    end
end)

--- Boucle de sauvegarde périodique.
CreateThread(function()
    while true do
        Wait(5 * 60 * 1000) -- 5 minutes
        local count = KFramework.Server.Inventory.saveAll()
        if count > 0 then
            KFramework.logDev(("Sauvegarde périodique : %d inventaire(s) en cours de sauvegarde."):format(count))
        end
    end
end)

--- Event réseau (client -> serveur) : le joueur souhaite ouvrir un inventaire (ses poches, un coffre, un stash...).
KFramework.onReceive("Inventory:open", function(id)
    local source = tonumber(source)
    KFramework.Server.Inventory.open(source, id)
end)

--- Event réseau (client -> serveur) : le joueur ferme l'inventaire qu'il consultait.
KFramework.onReceive("Inventory:close", function(id)
    local source = tonumber(source)
    KFramework.Server.Inventory.close(source, id)
end)

--- Event réseau (client -> serveur) : le joueur utilise l'item présent dans un slot de ses poches.
KFramework.onReceive("Inventory:useItem", function(slot)
    local source = tonumber(source)
    KFramework.Server.Inventory.useItem(source, slot)
end)

--- Event réseau (client -> serveur) : déplacement d'item (drag & drop NUI), au sein d'un inventaire, entre deux
--- inventaires, ou entre les poches et l'inventaire "équipement". Voir `moveBetween`.
KFramework.onReceive("Inventory:moveItem", function(from, to, count)
    local source = tonumber(source)
    KFramework.Server.Inventory.moveBetween(source, from, to, count)
end)

--- Event réseau (client -> serveur) : le joueur jette une quantité d'item au sol.
KFramework.onReceive("Inventory:dropItem", function(id, slot, count)
    local source = tonumber(source)
    KFramework.Server.Inventory.dropItem(source, id, slot, count)
end)

KFramework.loadedComponent('Inventory')
