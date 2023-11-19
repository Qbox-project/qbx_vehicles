fxversion 'cerulean'
game 'gta5'

description 'QBX_Vehicles'
repository 'https://github.com/Qbox-project/qbx_vehicles'
version '0.0.1'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'