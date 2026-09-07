LibertyStory = {}

local registerdEvents = {}

--- (L - Core/Shared) Enregistre un événement réseau et l'ajoute à la liste des événements enregistrés.
---@param eventName string Le nom de l'événement réseau à enregistrer.
local function registerEvent(eventName)
    RegisterNetEvent(eventName)
    table.insert(registerdEvents, eventName)
end

--- (L - Core/Shared) Vérifie si un événement réseau a déjà été enregistré localement.
---@param eventName string Le nom de l'événement à vérifier.
---@return boolean `true` si l'événement est dans la liste, `false` sinon.
local isEventRegistred = function(eventName)
    for _, event in pairs(registerdEvents) do 
        if (event == eventName) then 
            return true 
        end
    end
    return false
end

--- (G - Core/Shared) Déclenche un événement interne (Execute même coté) sécurisé (le nom de l'événement est haché en SHA-256).
---@param event string Le nom de l'événement interne à déclencher.
---@param ... any Les arguments optionnels à passer à l'événement.
LibertyStory.toInternal = function(event, ...)
    LibertyStory.logDev(("Envoie d'un event interne ^6>^3 %s^7"):format(event))
    TriggerEvent(LibertyStory.hs256(event), ...)
end

--- (G - Core/Shared) Déclenche un événement interne (Execute même coté) en clair (sans obfuscation du nom).
---@param event string Le nom de l'événement interne à déclencher.
---@param ... any Les arguments optionnels à passer à l'événement.
LibertyStory.toInternalExposed = function(event, ...)
    LibertyStory.logDev(("Envoie d'un event interne ^6>^3 %s^7"):format(event))
    TriggerEvent(event, ...)
end

--- (G - Core/Shared) Enregistre et écoute un événement local sécurisé (le nom de l'événement est haché en SHA-256).
---@param event string Le nom clair de l'événement à écouter.
---@param handler function La fonction de rappel (callback) à exécuter lors du déclenchement.
LibertyStory.onReceive = function(event, handler)
    local baseEvent = event
    event = LibertyStory.hs256(event)
    if (not (isEventRegistred(event))) then
        registerEvent(event)
    end
    AddEventHandler(event, handler)
end

--- (G - Core/Shared) Enregistre et écoute un événement local sécurisé (le nom de l'événement est haché en SHA-256).
---@param event string Le nom clair de l'événement à écouter.
---@param handler function La fonction de rappel (callback) à exécuter lors du déclenchement.
LibertyStory.onReceiveExposed = function(event, handler)
    if (not (isEventRegistred(event))) then
        registerEvent(event)
    end
    AddEventHandler(event, handler)
end

--- (G - Core/Shared) Écoute un événement strictement local en clair (sans déclaration réseau RegisterNetEvent).
---@param event string Le nom de l'événement à écouter.
---@param handler function La fonction de rappel (callback) à exécuter lors du déclenchement.
LibertyStory.onReceiveWithoutNetExposed = function(event, handler)
    AddEventHandler(event, handler)
end

--- (G - Core/Shared) Écoute un événement strictement local sécurisé (haché en SHA-256, sans déclaration réseau RegisterNetEvent).
---@param event string Le nom clair de l'événement à écouter.
---@param handler function La fonction de rappel (callback) à exécuter lors du déclenchement.
LibertyStory.onReceiveWithoutNet = function(event, handler)
    event = LibertyStory.hs256(event)
    AddEventHandler(event, handler)
end

--- (G - Core/Shared) Génère un hachage Jenkins 32 bits natif FiveM à partir d'une chaîne de caractères.
---@param string string La chaîne de caractères à hacher.
---@return integer Le code de hachage numérique sous forme d'entier.
LibertyStory.hash = function(string)
    return GetHashKey(string)
end

--- (G - Core/Shared) Génère une clé obfusquée pour le framework (préfixe 'LS_' suivi du hachage natif FiveM).
---@param string string Le nom de l'événement ou la chaîne à obfusquer.
---@return string La chaîne obfusquée au format "LS_<hash>".
LibertyStory.hs256 = function(string)
    return ("LS_%s"):format(GetHashKey(string))
end

--- (G - Core/Shared) Affiche un message dans la console uniquement si le serveur/client est en mode développement ("DEV").
---@param stringValue string Le message à afficher dans les logs.
LibertyStory.logDev = function(stringValue)
    if (_Config.environment == "DEV") then 
        print(("%s %s^7"):format(_Config.prefix, stringValue))
    end
end

--- (G - Core/Shared) Affiche un message dans la console quel que soit l'environnement (DEV ou PROD).
---@param stringValue string Le message à afficher dans les logs.
LibertyStory.logOverall = function(stringValue)
    print(("%s %s^7"):format(_Config.prefix, stringValue))
end

--- (G - Core/Shared) Affiche une requête ou un message lié à la base de données MySQL dans la console (en jaune).
---@param SQLValue string La requête SQL ou le message à afficher.
LibertyStory.SQL = function(SQLValue)
    print(("[^3SQL^7] %s^7"):format(SQLValue))
end

--- (G - Core/Shared) Affiche un message d'erreur dans la console (en rouge) si les erreurs sont activées dans la configuration.
---@param stringValue string Le message d'erreur à afficher.
LibertyStory.Error = function(stringValue)
    if (_Config.enableError) then 
        print(("[^1ERROR^7] %s^7"):format(stringValue))
    end
end

--- (G - Core/Shared) Affiche un message de succès dans la console (en vert).
---@param stringValue string Le message de confirmation/succès à afficher.
LibertyStory.Succes = function(stringValue)
    print(("[^2SUCCES^7] %s^7"):format(stringValue))
end

--- (G - Core/Shared) Journalise le chargement d'un composant du framework en mode développement.
---@param id string L'identifiant ou le nom du composant chargé.
LibertyStory.loadedComponent = function(id)
    LibertyStory.logDev(("Chargement du composant ^6>^5 %s"):format(id))
end

--- (G - Core/Shared) Journalise le chargement d'un addon externe ou module additionnel en mode développement.
---@param id string L'identifiant ou le nom de l'addon chargé.
LibertyStory.loadedAddon = function(id)
    LibertyStory.logDev(("Chargement de l'addon ^6>^4 %s"):format(id))
end