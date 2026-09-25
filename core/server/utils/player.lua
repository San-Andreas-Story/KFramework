--- Le joueur (Server ID) est-il toujours connecté ?
---@param _src number
---@return boolean
KFramework.Server.Utils.isConnected = function(_src)
    return type(_src) == "number" and GetPlayerName(_src) ~= nil
end