--[[ FX Information ]] --
fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'

--[[ Resource Information ]] --
name 'ox_doorlock'
version      '1.22.3'
license 'GPL-3.0-or-later'
author 'Overextended'
repository 'https://github.com/overextended/ox_doorlock'

--[[ Manifest ]] --
shared_scripts {
    '@pr_bridge/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/utils.lua',
}

server_script 'server/main.lua'

ui_page 'web/build/index.html'

files {
    'web/build/index.html',
    'web/build/**/*',
    'web/build/sounds/*.wav',
    'data/door_models.json',
    'locales/*.json',
    'audio/data/oxdoorlock_sounds.dat54.rel',
    'audio/dlc_oxdoorlock/oxdoorlock.awc',
}

data_file 'AUDIO_WAVEPACK' 'audio/dlc_oxdoorlock'
data_file 'AUDIO_SOUNDDATA' 'audio/data/oxdoorlock_sounds.dat'

dependencies {
    'pr_bridge',
}

server_script 'server/version.lua'
