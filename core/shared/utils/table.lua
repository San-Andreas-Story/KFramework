--- Copie superficielle d'un tableau indexé (list-like).
---@param list table
---@return table
KFramework.Utils.copyList = function(list)
    local copy = {}
    for i = 1, #list do copy[i] = list[i] end
    return copy
end