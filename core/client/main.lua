LibertyStory.Client = {}

--- Déclenche un événement réseau sécurisé (haché) du client vers le serveur.
---@param event string Le nom clair de l'événement à déclencher sur le serveur.
---@param ... any Les arguments optionnels à transmettre au serveur.
LibertyStory.toServer = function(event, ...)
    TriggerServerEvent(LibertyStory.hs256(event), ...)
    LibertyStory.logDev(("Envoie d'un event au serveur ^6>^1 %s"):format(event))
end

--- Déclenche un événement réseau en clair (non obfusqué) du client vers le serveur.
---@param event string Le nom clair de l'événement à déclencher sur le serveur.
---@param ... any Les arguments optionnels à transmettre au serveur.
LibertyStory.toServerExposed = function(event, ...)
    TriggerServerEvent(event, ...)
    LibertyStory.logDev(("Envoie d'un event (^1Exposé^7) au serveur ^6>^1 %s"):format(event))
end

CreateThread(function()
    LibertyStory.logDev("Demarrage du client...")
    LibertyStory.toInternal("loaded")
    while (true) do
        Wait(1)
        if (NetworkIsPlayerActive(PlayerId())) then
            LibertyStory.toInternal("joined")
            break
        end
    end
end)

LibertyStory.logDev("Bienvenue sur ^4Liberty Story ^7!")