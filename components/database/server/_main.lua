KFramework.Server.Database = {}

--- Securise et formate les parametres d'une requete SQL pour eviter les erreurs d'objets vides/nuls.
---@param params table|nil Le tableau des parametres a passer a la requete.
---@return table Le tableau de parametres securise (un tableau vide fictif si aucun n'est fourni).
local function safeParameters(params)
    if nil == params then
        return { [''] = '' }
    end
    assert(type(params) == "table", "A table is expected")
    if next(params) == nil then
        return { [''] = '' }
    end
    return params
end

---Execute une requete SQL de modification/mise a jour (UPDATE, DELETE).
---@param query string La requete SQL a executer.
---@param params table|nil Les parametres d'injection de la requete.
---@param func function|nil La fonction de rappel (callback) executee une fois la requete terminee.
KFramework.Server.Database.execute = function(query, params, func)
    KFramework.SQL(query)
    exports[GetCurrentResourceName()]:mysql_execute(query, safeParameters(params), func)
end

---Execute une requete SQL de lecture (SELECT) et retourne le resultat.
---@param query string La requete SQL a executer.
---@param params table|nil Les parametres d'injection de la requete.
---@param func function|nil La fonction de rappel (callback) recevant les resultats de la requete.
KFramework.Server.Database.query = function(query, params, func)
    KFramework.SQL(query)
    exports[GetCurrentResourceName()]:mysql_fetch_all(query, safeParameters(params), func)
end

---Execute une requete SQL d'insertion (INSERT) et retourne generalement l'ID insere.
---@param query string La requete SQL a executer.
---@param params table|nil Les parametres d'injection de la requete.
---@param func function|nil La fonction de rappel (callback) recevant l'ID de la ligne inseree.
KFramework.Server.Database.insert = function(query, params, func)
    KFramework.SQL(query)
    exports[GetCurrentResourceName()]:mysql_insert(query, safeParameters(params), func)
end

KFramework.loadedComponent('Database')