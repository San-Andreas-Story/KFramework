--- Commande de développement : crée (une seule fois) un inventaire "coffre" de démonstration rempli de
--- quelques items, et l'ouvre pour le joueur qui tape la commande. Sert à tester le double-panneau NUI
--- sans attendre l'intégration réelle avec les coffres de véhicules/stash. À retirer en production.
RegisterCommand('testcoffre', function(source)
    local id = "trunk:demo"

    if not KFramework.Server.Inventory.exists(id) then
        local inventory = KFramework.Server.Inventory.create(id, {
            type = "trunk", label = "Coffre (démo)", slots = 20, maxWeight = 40000,
        })
        inventory:addItem("water", 6)
        inventory:addItem("lockpick", 3)
        inventory:addItem("tshirt_rouge", 1)
        inventory:addItem("montre", 1)
    end

    KFramework.Server.Inventory.open(source, id)
end, false)
