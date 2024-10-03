fx_version('cerulean')
game({ 'gta5' })
lua54('yes')

author('Hajden - Forked from lunar_garage')
description('Quick Garage')
version('1.1.7')

shared_scripts({
    '@ox_lib/init.lua',
    'config/config.lua'
});

client_scripts({
    'framework/**/client.lua',
    'utils/cl_main.lua',
    'config/cl_edit.lua',
    'client/*.lua'
});

server_scripts({
    'framework/**/server.lua',
    '@oxmysql/lib/MySQL.lua',
    'utils/sv_main.lua',
    'config/sv_config.lua',
    'locales/*.lua',
    'server/*.lua'
});

files({
    'locales/*.json'
});