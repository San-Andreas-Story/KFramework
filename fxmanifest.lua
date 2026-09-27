fx_version 'cerulean'
game 'gta5'

author 'Koryzk'
description 'Framework for FiveM'
version '0.01'

shared_scripts {
    --[[ Config ]]--
    'config/global.lua',

    --[[ Core ]]--
    'core/shared/main.lua',
    'core/shared/utils/*.lua',

    --[[ Class ]]--
    'class/shared/*.lua',

    --[[ Components ]]--

    --[[ DEV ]]--
    'dev/shared/*.lua',
}

client_scripts {
    --[[ Config ]]--

    --[[ Core ]]--
    'core/client/main.lua',
    'core/client/utils/*.lua',

    --[[ Components ]]--
    'components/**/client/*.lua',

    --[[ DEV ]]--
    'dev/client/*.lua',
}

server_scripts {
    --[[ Config ]]--

    --[[ Core ]]--
    'core/server/main.lua',
    'core/server/utils/*.lua',

    --[[ Class ]]--
    'class/server/*.lua',

    --[[ Components ]]--
    'components/**/server/*.lua',

    --[[ Vendors ]]
    'vendors/MySQL/mysql-async.js',

    --[[ DEV ]]--
    'dev/server/*.lua',
}