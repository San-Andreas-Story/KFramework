_Config = {
    prefix = "^6[KFramework]^7",
    environment = 'DEV',
    enableError = true, -- nécessaire pour que KFramework.Error() affiche quoi que ce soit (absent de l'original)

    inventory = {
        defaultSlots = 40,     -- nombre d'emplacements par défaut d'un nouvel inventaire "poches"
        defaultWeight = 30000, -- poids maximal par défaut, en grammes (30 kg)

        -- Ordre = numéro de slot dans l'inventaire "équipement" (equip:<charId>). Ne réordonne pas cette liste
        -- une fois en prod : ça décale tous les slots déjà sauvegardés en base. Ajoute plutôt à la fin.
        wearSlots = {
            "hat", "glasses", "mask", "tshirt", "pants", "shoes",
            "vest", "watch", "jewel", "ear", "helmet", "bag",
        },
    },
}
