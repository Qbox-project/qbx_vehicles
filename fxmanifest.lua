fx_version 'cerulean'
game 'gta5'

description 'QBX_Vehicles'
repository 'https://github.com/Qbox-project/qbx_vehicles'
version '1.4.1'

server_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

server_only 'yes'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
