--- Définitions statiques de tous les items disponibles dans le framework, indexées par leur nom technique (unique).
--- Consommée par `_Inventory` (poids, empilage), par `KFramework.Server.Inventory.useItem` (utilisation) et par
--- le NUI de l'inventaire (icône, tenue).
---@type table<string, table>
--- Champs disponibles par item :
---   label          string   Nom affiché dans l'interface.
---   description     string  Description affichée dans l'interface (tooltip).
---   icon            string  Emoji utilisé comme icône dans le NUI (à remplacer par tes vraies images plus tard).
---   weight          number  Poids unitaire, en grammes.
---   stackable       boolean Si `true`, plusieurs exemplaires peuvent partager le même emplacement.
---   usable          boolean Si `true`, l'item peut être utilisé via `Inventory:useItem`. Si `false` ou omis,
---                           toute tentative d'utilisation est refusée (le bouton "Utiliser" est grisé côté NUI).
---   consumeOnUse    boolean Si `false`, l'item n'est PAS retiré de l'inventaire après utilisation (par défaut : un
---                           exemplaire est consommé à chaque utilisation).
---   shouldClose     boolean Si `true`, ferme automatiquement le NUI de l'inventaire après utilisation.
---   onUse           function|nil (source, stack, slot) Comportement personnalisé à l'utilisation. Si omis, un event
---                           interne générique `Inventory:itemUsed` est diffusé (voir component Inventory).
---   wear            string|nil La case de tenue visée dans `_Config.inventory.wearSlots` (ex: "tshirt", "hat").
---                           Présent uniquement sur les items habillables : les autorise à être déposés dans
---                           l'inventaire "équipement" du joueur, et rend "Utiliser" équivalent à "porter".
---   ped             table|nil Traduction du `wear` en variation de ped GTA (uniquement lue côté client) :
---                           `{ kind = "component"|"prop", id = number, drawable = number, texture = number|nil }`.
_Items = {

    -- Consommables
    ["water"] = {
        label = "Bouteille d'eau", icon = "💧", description = "Une bouteille d'eau fraîche.",
        weight = 500, stackable = true, usable = true, shouldClose = true,
    },
    ["bread"] = {
        label = "Pain", icon = "🍞", description = "Un bon pain frais.",
        weight = 300, stackable = true, usable = true, shouldClose = true,
    },

    -- Outils
    ["lockpick"] = {
        label = "Pince à crocheter", icon = "🔓", description = "Permet de crocheter une serrure.",
        weight = 150, stackable = true, usable = true, shouldClose = true,
    },
    ["phone"] = {
        label = "Téléphone", icon = "📱", description = "Un téléphone portable.",
        weight = 200, stackable = false, usable = true, consumeOnUse = false, shouldClose = true,
    },

    -- Non utilisables (exemples) : "usable" omis ou explicitement `false`.
    ["identity_card"] = {
        label = "Carte d'identité", icon = "🪪", description = "Papiers d'identité officiels.",
        weight = 10, stackable = false, usable = false,
    },
    ["cle"] = {
        label = "Clé", icon = "🔑", description = "Une clé, ne s'utilise pas depuis l'inventaire.",
        weight = 20, stackable = true, usable = false,
    },
    ["argent"] = {
        label = "Argent", icon = "💵", description = "De l'argent liquide.",
        weight = 1, stackable = true, usable = false,
    },

    -- Tenues (habillables) : `wear` = case ciblée, `ped` = traduction en variation de ped côté client.
    ["casquette"] = {
        label = "Casquette", icon = "🧢", description = "Une casquette.", weight = 100,
        stackable = false, usable = true, consumeOnUse = false, shouldClose = false,
        wear = "hat", ped = { kind = "prop", id = 0, drawable = 0 },
    },
    ["lunettes"] = {
        label = "Lunettes", icon = "🕶️", description = "Une paire de lunettes.", weight = 50,
        stackable = false, usable = true, consumeOnUse = false, shouldClose = false,
        wear = "glasses", ped = { kind = "prop", id = 1, drawable = 0 },
    },
    ["masque"] = {
        label = "Masque", icon = "😷", description = "Un masque chirurgical.", weight = 30,
        stackable = false, usable = true, consumeOnUse = false, shouldClose = false,
        wear = "mask", ped = { kind = "component", id = 1, drawable = 1 },
    },
    ["tshirt_blanc"] = {
        label = "T-shirt blanc", icon = "👕", description = "Un t-shirt blanc.", weight = 200,
        stackable = false, usable = true, consumeOnUse = false, shouldClose = false,
        wear = "tshirt", ped = { kind = "component", id = 8, drawable = 15 },
    },
    ["tshirt_rouge"] = {
        label = "T-shirt rouge", icon = "👕", description = "Un t-shirt rouge.", weight = 200,
        stackable = false, usable = true, consumeOnUse = false, shouldClose = false,
        wear = "tshirt", ped = { kind = "component", id = 8, drawable = 21 },
    },
    ["jean"] = {
        label = "Jean", icon = "👖", description = "Un jean.", weight = 500,
        stackable = false, usable = true, consumeOnUse = false, shouldClose = false,
        wear = "pants", ped = { kind = "component", id = 4, drawable = 4 },
    },
    ["baskets"] = {
        label = "Baskets", icon = "👟", description = "Une paire de baskets.", weight = 400,
        stackable = false, usable = true, consumeOnUse = false, shouldClose = false,
        wear = "shoes", ped = { kind = "component", id = 6, drawable = 6 },
    },
    ["gilet"] = {
        label = "Gilet pare-balles", icon = "🦺", description = "Un gilet pare-balles.", weight = 900,
        stackable = false, usable = true, consumeOnUse = false, shouldClose = false,
        wear = "vest", ped = { kind = "component", id = 9, drawable = 1 },
    },
    ["montre"] = {
        label = "Montre", icon = "⌚", description = "Une montre.", weight = 60,
        stackable = false, usable = true, consumeOnUse = false, shouldClose = false,
        wear = "watch", ped = { kind = "prop", id = 6, drawable = 0 },
    },
    ["collier"] = {
        label = "Collier", icon = "📿", description = "Un collier.", weight = 40,
        stackable = false, usable = true, consumeOnUse = false, shouldClose = false,
        wear = "jewel", ped = { kind = "component", id = 7, drawable = 1 },
    },
    ["sac"] = {
        label = "Sac à dos", icon = "🎒", description = "Un sac à dos.", weight = 700,
        stackable = false, usable = true, consumeOnUse = false, shouldClose = false,
        wear = "bag", ped = { kind = "component", id = 5, drawable = 1 },
    },
    -- NB : "Casquette" et "Casque" partagent le même emplacement natif GTA (prop 0 = tête) : le jeu ne permet
    -- pas de porter les deux en même temps, quoi que fasse l'inventaire. C'est une limitation du jeu, pas un bug.
    ["casque"] = {
        label = "Casque", icon = "🪖", description = "Un casque de protection.", weight = 600,
        stackable = false, usable = true, consumeOnUse = false, shouldClose = false,
        wear = "helmet", ped = { kind = "prop", id = 0, drawable = 15 },
    },
    ["oreillette"] = {
        label = "Oreillette", icon = "🎧", description = "Une oreillette radio.", weight = 30,
        stackable = false, usable = true, consumeOnUse = false, shouldClose = false,
        wear = "ear", ped = { kind = "prop", id = 2, drawable = 0 },
    },

}
