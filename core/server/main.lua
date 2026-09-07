LibertyStory.Server = {}

--- Déclenche un événement réseau sécurisé (haché) du serveur vers un client spécifique.
---@param eventName string Le nom de l'événement à déclencher sur le client.
---@param targetSrc integer L'ID (source) du joueur ciblé.
---@param ... any Les arguments optionnels à transmettre au client.
LibertyStory.toClient = function(eventName, targetSrc, ...)
    TriggerClientEvent(LibertyStory.hs256(eventName), targetSrc, ...)
    LibertyStory.logDev(("Envoie d'un event au client (^3%i^7) ^6>^1 %s"):format(targetSrc, eventName))
end

--- Déclenche un événement réseau sécurisé (haché) du serveur vers TOUS les clients connectés (broadcast).
---@param eventName string Le nom de l'événement à déclencher sur tous les clients.
---@param ... any Les arguments optionnels à transmettre aux clients.
LibertyStory.toClients = function(eventName, ...)
    TriggerClientEvent(LibertyStory.hs256(eventName), -1, ...)
    LibertyStory.logDev(("Envoie d'un event à tous les clients ^6>^1 %s"):format(eventName))
end

--- Déclenche un événement réseau en clair (non obfusqué) du serveur vers un client spécifique.
---@param event string Le nom clair de l'événement à déclencher sur le client.
---@param targetSrc integer L'ID (source) du joueur ciblé.
---@param ... any Les arguments optionnels à transmettre au client.
LibertyStory.toClientExposed = function(event, targetSrc, ...)
    TriggerClientEvent(event, targetSrc, ...)
    LibertyStory.logDev(("Envoie d'un event (^1Exposé^7) au client (^3%s^7) ^6>^1 %s"):format(targetSrc, event))
end

CreateThread(function()
    LibertyStory.logDev("Initialisation de Liberty Story")
    LibertyStory.logDev("Demarrage du serveur...")
    LibertyStory.toInternal("loaded")
end)