KFramework.Client.Inventory = {}

--- État de la session d'inventaire actuellement affichée : ids réels de chaque panneau (résolus par le
--- serveur à l'ouverture), pour traduire les échanges NUI ("self"/"target"/"equip") en vrais identifiants.
local state = { selfId = nil, targetId = nil, equipId = nil, open = false }

--- Traduction `wear` (catégorie) -> variation de ped GTA "par défaut", utilisée pour DÉSHABILLER un
--- emplacement quand `Inventory:applyWear` ne contient plus d'item pour cette case. À ajuster si tes valeurs
--- de composant/prop "neutre" diffèrent (ex: un pantalon par défaut différent de `0`).
local CATEGORY_PED = {
    hat     = { kind = "prop",      id = 0 },
    glasses = { kind = "prop",      id = 1 },
    mask    = { kind = "component", id = 1, drawable = 0 },
    tshirt  = { kind = "component", id = 8, drawable = 15 },
    pants   = { kind = "component", id = 4, drawable = 0 },
    shoes   = { kind = "component", id = 6, drawable = 0 },
    vest    = { kind = "component", id = 9, drawable = 0 },
    watch   = { kind = "prop",      id = 6 },
    jewel   = { kind = "component", id = 7, drawable = 0 },
    ear     = { kind = "prop",      id = 2 },
    helmet  = { kind = "prop",      id = 0 },
    bag     = { kind = "component", id = 5, drawable = 0 },
}

local function applyPedItem(ped, info)
    if not info then return end
    if info.kind == "prop" then
        SetPedPropIndex(ped, info.id, info.drawable or 0, info.texture or 0, true)
    else
        SetPedComponentVariation(ped, info.id, info.drawable or 0, info.texture or 0, 2)
    end
end

local function clearPedSlot(ped, category)
    local base = CATEGORY_PED[category]
    if not base then return end
    if base.kind == "prop" then
        ClearPedProp(ped, base.id)
    else
        SetPedComponentVariation(ped, base.id, base.drawable or 0, 0, 2)
    end
end

--- Applique visuellement sur le ped local la tenue décrite par un snapshot de l'inventaire "équipement".
--- Chaque case (voir `_Config.inventory.wearSlots`) est soit habillée avec `_Items[name].ped`, soit réinitialisée.
---@param snapshot table Le snapshot de l'inventaire "équipement" (voir `_Inventory:snapshot`).
---@return void
KFramework.Client.Inventory.applyWear = function(snapshot)
    local ped = PlayerPedId()
    local wearSlots = (_Config.inventory and _Config.inventory.wearSlots) or {}
    for i, category in ipairs(wearSlots) do
        local stack = snapshot.items[i]
        local def = stack and _Items and _Items[stack.name]
        if def and def.ped then
            applyPedItem(ped, def.ped)
        else
            clearPedSlot(ped, category)
        end
    end
end

local invCam = nil

local function startPreviewCam()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local distance, height, lookHeight, fov = 2.4, 0.75, 0.55, 40.0

    invCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(invCam, coords.x - forward.x * distance, coords.y - forward.y * distance, coords.z + height)
    PointCamAtCoord(invCam, coords.x, coords.y, coords.z + lookHeight)
    SetCamFov(invCam, fov)
    RenderScriptCams(true, true, 500, true, true)

    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    DisplayRadar(false)
end

local function stopPreviewCam()
    if invCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(invCam, false)
        invCam = nil
    end
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    DisplayRadar(true)
end

--- Le NUI de l'inventaire est-il actuellement affiché ?
---@return boolean
KFramework.Client.Inventory.isOpen = function()
    return state.open
end

--- Demande au serveur d'ouvrir un inventaire (poches, coffre, stash...). Sans argument, ouvre les poches
--- du joueur local. Le serveur répond par `Inventory:open` (accepté) ou `Inventory:openDenied`.
---@param id string|nil L'identifiant de l'inventaire à ouvrir. `nil` = les poches du joueur local.
---@return void
KFramework.Client.Inventory.open = function(id)
    KFramework.toServer("Inventory:open", id)
end

--- Ferme l'inventaire actuellement affiché : prévient le serveur puis nettoie caméra/HUD/NUI.
---@return void
KFramework.Client.Inventory.close = function()
    if not state.open then return end
    KFramework.toServer("Inventory:close", state.targetId or state.selfId)
    KFramework.Client.Inventory.hideUI()
end

--- Demande au serveur d'utiliser l'item présent dans un emplacement des poches du joueur local.
---@param slot number
---@return void
KFramework.Client.Inventory.useItem = function(slot)
    KFramework.toServer("Inventory:useItem", slot)
end

--- Résout un emplacement NUI (`{ side = "self"|"target"|"equip", slot = number }`) vers son identifiant
--- d'inventaire réel, à partir de la session actuellement ouverte.
---@param loc table
---@return table|nil `{ id = string, slot = number }`, ou `nil` si le panneau demandé n'est pas ouvert.
local function resolveLoc(loc)
    if type(loc) ~= "table" or not loc.side or not loc.slot then return nil end
    local id = (loc.side == "self" and state.selfId)
        or (loc.side == "target" and state.targetId)
        or (loc.side == "equip" and state.equipId)
    if not id then return nil end
    return { id = id, slot = loc.slot }
end

--- Demande un déplacement d'item entre deux emplacements NUI (même panneau, panneau opposé, ou vers/depuis
--- l'inventaire "équipement" pour habiller/déshabiller le personnage).
---@param from table `{ side, slot }`.
---@param to table `{ side, slot }`.
---@param count number|nil La quantité à déplacer (par défaut : tout le stack).
---@return void
KFramework.Client.Inventory.moveItem = function(from, to, count)
    local f, t = resolveLoc(from), resolveLoc(to)
    if not f or not t then return end
    KFramework.toServer("Inventory:moveItem", f, t, count)
end

--- Demande à jeter une quantité d'item au sol, depuis les poches, l'inventaire ciblé ouvert, ou l'équipement
--- actuellement porté (dans ce dernier cas, le ped se déshabille automatiquement de cet emplacement).
---@param side "self"|"target"|"equip"
---@param slot number
---@param count number|nil
---@return void
KFramework.Client.Inventory.dropItem = function(side, slot, count)
    local loc = resolveLoc({ side = side, slot = slot })
    if not loc then return end
    KFramework.toServer("Inventory:dropItem", loc.id, loc.slot, count)
end

--- Affiche le NUI de l'inventaire (double-panneau + tenue) à partir du payload envoyé par le serveur, et
--- démarre la caméra de preview sur le ped local.
---@param payload table `{ self = snapshot|nil, target = snapshot|nil, equip = snapshot|nil }`.
---@return void
KFramework.Client.Inventory.showUI = function(payload)
    state.selfId = payload.self and payload.self.id
    state.targetId = payload.target and payload.target.id
    state.equipId = payload.equip and payload.equip.id
    state.open = true

    SetNuiFocus(true, true)
    startPreviewCam()
    SendNUIMessage({ action = "open", catalog = _Items, self = payload.self, target = payload.target, equip = payload.equip })
    KFramework.logDev("Ouverture NUI de l'inventaire.")
end

--- Cache le NUI de l'inventaire, libère le focus NUI et arrête la caméra de preview.
---@return void
KFramework.Client.Inventory.hideUI = function()
    state.selfId, state.targetId, state.equipId, state.open = nil, nil, nil, false
    SetNuiFocus(false, false)
    stopPreviewCam()
    SendNUIMessage({ action = "close" })
end

KFramework.onReceive("Inventory:open", function(payload)
    KFramework.Client.Inventory.showUI(payload)
end)

---@param id string
KFramework.onReceive("Inventory:openDenied", function(id)
    KFramework.logDev(("Ouverture refusée : l'inventaire %s est déjà occupé par un autre joueur."):format(tostring(id)))
    -- TODO : afficher une notification à l'utilisateur via ton système de notifications.
end)

--- Le contenu d'un des panneaux ouverts a changé côté serveur : met à jour le bon côté dans le NUI.
---@param snapshot table
KFramework.onReceive("Inventory:update", function(snapshot)
    if not state.open then return end
    if snapshot.id == state.selfId then
        SendNUIMessage({ action = "update", side = "self", inventory = snapshot })
    elseif snapshot.id == state.targetId then
        SendNUIMessage({ action = "update", side = "target", inventory = snapshot })
    end
end)

--- La tenue du joueur local a changé (équipement/déséquipement) : applique le rendu sur le ped, et met à
--- jour le panneau "équipement" du NUI si l'inventaire est actuellement affiché.
---@param snapshot table
KFramework.onReceive("Inventory:applyWear", function(snapshot)
    KFramework.Client.Inventory.applyWear(snapshot)
    if state.open and snapshot.id == state.equipId then
        SendNUIMessage({ action = "update", side = "equip", inventory = snapshot })
    end
end)

--- Le serveur ferme l'inventaire actuellement affiché (item utilisé avec `shouldClose`, etc.).
---@param id string
KFramework.onReceive("Inventory:close", function(id)
    if state.open and (id == state.selfId or id == state.targetId) then
        KFramework.Client.Inventory.hideUI()
    end
end)

RegisterNUICallback('inventory:close', function(_, cb)
    KFramework.Client.Inventory.close()
    cb('ok')
end)

--- Attendu : `{ from = { side, slot }, to = { side, slot }, count = number|nil }`.
RegisterNUICallback('inventory:move', function(data, cb)
    if type(data) == "table" and data.from and data.to then
        KFramework.Client.Inventory.moveItem(data.from, data.to, data.count)
    end
    cb('ok')
end)

--- Attendu : `{ slot = number }` (toujours dans les poches du joueur local).
RegisterNUICallback('inventory:use', function(data, cb)
    if type(data) == "table" and data.slot then
        KFramework.Client.Inventory.useItem(data.slot)
    end
    cb('ok')
end)

--- Attendu : `{ side = "self"|"target", slot = number, count = number|nil }`.
RegisterNUICallback('inventory:drop', function(data, cb)
    if type(data) == "table" and data.side and data.slot then
        KFramework.Client.Inventory.dropItem(data.side, data.slot, data.count)
    end
    cb('ok')
end)

RegisterCommand('+kf_inventory', function()
    if state.open then KFramework.Client.Inventory.close() else KFramework.Client.Inventory.open() end
end, false)
RegisterKeyMapping('+kf_inventory', "Ouvrir l'inventaire", 'keyboard', 'I')

RegisterCommand('+kf_closeInventory', function()
    if state.open then KFramework.Client.Inventory.close() end
end, false)
RegisterKeyMapping('+kf_closeInventory', "Fermer l'inventaire", 'keyboard', 'BACK')

KFramework.loadedComponent('Inventory')