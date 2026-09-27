--- Commande pour faire spawner un véhicule
--- Usage : /car [nom_du_modele]
RegisterCommand("car", function(source, args, rawCommand)
    local _src = source
    local modelName = args[1] or "sultan" -- Modèle par défaut si aucun n'est spécifié

    -- (Optionnel) Vous pouvez ajouter ici des vérifications de permission/groupe
    -- ex: if not KFramework.Server.Player.isAdmin(_src) then return end

    -- Envoie de l'événement au client pour créer le véhicule
    TriggerClientEvent("KFramework:Client:Vehicle:Spawn", _src, modelName)
end, false) -- Mettre à false pour autoriser tout le monde, ou true pour restreindre via ACE permissions