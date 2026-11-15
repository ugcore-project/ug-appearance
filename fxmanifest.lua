--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@diagnostic disable: undefined-global

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ug-appearance'
author 'UgCore Framework & Contributors'
version '1.0.0' -- x-release-please-version
description 'Character creator, clothing stores, barbers, tattoos, surgeons and outfits for UgCore'
repository 'https://github.com/ugcore-project/ug-appearance'

ugcore_version '1.0.0'
uglib_version '1.0.0'

dependencies {
    '/onesync',
    'ug-core',
    'ug-lib',
    'oxmysql',
}

shared_scripts {
    '@ug-core/import.lua',
    '@ug-lib/import.lua',
    'shared/init.lua',
    'shared/enums.lua',
    'shared/appearance.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/config.lua',
    'server/database.lua',
    'server/sessions.lua',
    'server/outfits.lua',
    'server/commands.lua',
    'server/boot.lua',
}

client_scripts {
    'client/tattoos.js',
    'client/camera.lua',
    'client/ped.lua',
    'client/studio.lua',
    'client/nui.lua',
    'client/editor.lua',
    'client/stores.lua',
    'client/boot.lua',
}

ui_page 'web/dist/index.html'

files {
    'locales/*.json',
    'web/dist/index.html',
    'web/dist/assets/*',
}
