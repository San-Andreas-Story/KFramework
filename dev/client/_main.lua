--- Événement client pour spawner un véhicule et installer le joueur dedans
---@param modelName string Le nom ou le hash du modèle de véhicule à faire spawner
RegisterCommand("car", function(modelName)
    local ped = PlayerPedId()
    local modelHash = type(modelName) == "number" and modelName or GetHashKey(modelName)

    -- Vérification si le modèle existe
    if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
        KFramework.logDev(("Modèle de véhicule invalide : %s"):format(tostring(modelName)))
        return
    end

    -- Chargement du modèle en mémoire
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(10)
    end

    -- Récupération de la position et du cap (heading) du joueur
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    -- Suppression du véhicule actuel si le joueur est déjà dans un véhicule
    if IsPedInAnyVehicle(ped, false) then
        local currentVeh = GetVehiclePedIsIn(ped, false)
        SetEntityAsMissionEntity(currentVeh, true, true)
        DeleteVehicle(currentVeh)
    end

    -- Création du véhicule
    local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, false)

    -- Installation du joueur au siège conducteur (-1)
    SetPedIntoVehicle(ped, vehicle, -1)

    -- Synchronisation avec le routing bucket / instance actuel si nécessaire
    local currentInstance = KFramework.Client.Instance.get()
    if currentInstance and currentInstance ~= 0 then
        --
    end

    -- Nettoyage du modèle en mémoire
    SetModelAsNoLongerNeeded(modelHash)
end)