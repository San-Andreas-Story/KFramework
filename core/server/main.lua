KFramework.Server = {}

--- Déclenche un événement réseau sécurisé (haché) du serveur vers un client spécifique.
---@param eventName string Le nom de l'événement à déclencher sur le client.
---@param targetSrc integer L'ID (source) du joueur ciblé.
---@param ... any Les arguments optionnels à transmettre au client.
KFramework.toClient = function(eventName, targetSrc, ...)
    TriggerClientEvent(KFramework.hs256(eventName), targetSrc, ...)
    KFramework.logDev(("Envoie d'un event au client (^3%i^7) ^6>^1 %s"):format(targetSrc, eventName))
end

--- Déclenche un événement réseau sécurisé (haché) du serveur vers TOUS les clients connectés (broadcast).
---@param eventName string Le nom de l'événement à déclencher sur tous les clients.
---@param ... any Les arguments optionnels à transmettre aux clients.
KFramework.toClients = function(eventName, ...)
    TriggerClientEvent(KFramework.hs256(eventName), -1, ...)
    KFramework.logDev(("Envoie d'un event à tous les clients ^6>^1 %s"):format(eventName))
end

--- Déclenche un événement réseau en clair (non obfusqué) du serveur vers un client spécifique.
---@param event string Le nom clair de l'événement à déclencher sur le client.
---@param targetSrc integer L'ID (source) du joueur ciblé.
---@param ... any Les arguments optionnels à transmettre au client.
KFramework.toClientExposed = function(event, targetSrc, ...)
    TriggerClientEvent(event, targetSrc, ...)
    KFramework.logDev(("Envoie d'un event (^1Exposé^7) au client (^3%s^7) ^6>^1 %s"):format(targetSrc, event))
end

CreateThread(function()
    KFramework.logDev("Initialisation de Liberty Story")
    KFramework.logDev("Demarrage du serveur...")
    KFramework.toInternal("loaded")
end)