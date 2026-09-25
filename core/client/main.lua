KFramework.Client = {}

--- Déclenche un événement réseau sécurisé (haché) du client vers le serveur.
---@param event string Le nom clair de l'événement à déclencher sur le serveur.
---@param ... any Les arguments optionnels à transmettre au serveur.
KFramework.toServer = function(event, ...)
    TriggerServerEvent(KFramework.hs256(event), ...)
    KFramework.logDev(("Envoie d'un event au serveur ^6>^1 %s"):format(event))
end

--- Déclenche un événement réseau en clair (non obfusqué) du client vers le serveur.
---@param event string Le nom clair de l'événement à déclencher sur le serveur.
---@param ... any Les arguments optionnels à transmettre au serveur.
KFramework.toServerExposed = function(event, ...)
    TriggerServerEvent(event, ...)
    KFramework.logDev(("Envoie d'un event (^1Exposé^7) au serveur ^6>^1 %s"):format(event))
end

CreateThread(function()
    KFramework.logDev("Demarrage du client...")
    KFramework.toInternal("loaded")
    while (true) do
        Wait(1)
        if (NetworkIsPlayerActive(PlayerId())) then
            KFramework.toInternal("joined")
            break
        end
    end
end)

KFramework.logDev("Bienvenue sur ^4Liberty Story ^7!")