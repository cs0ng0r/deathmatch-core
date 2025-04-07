fx_version 'cerulean'
game 'gta5'

author 'DM Core'
description 'FiveM Deathmatch Core with Security Features'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/*.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua', -- Make sure oxmysql resource is installed
    'server/*.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/img/*.png'
}