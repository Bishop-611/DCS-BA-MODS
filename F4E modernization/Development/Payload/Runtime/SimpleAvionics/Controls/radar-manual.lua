local root=[[__F4_RUNTIME__/]]
local profile=dofile(root..'radar-profile.lua')
perfomance=profile.performance
dofile(root..'radar-contacts.lua')
local receive_init,receive_update=post_initialize,update
local update_display=dofile(root..'display-data.lua')
local force_interlock=dofile(root..'Controls/force-interlock.lua')
local dev=GetSelf()
local tick=0
dev:listen_command(509);dev:listen_command(510)
function SetCommand(command,value)
    if command==509 or command==510 then
        log.write('F4_SIMPLE_MANUAL',log.INFO,'RADAR received '..tostring(command)..' value='..tostring(value))
    end
end
function post_initialize()
    receive_init()
    force_interlock('STARTUP')
    for name,value in pairs({SCAN_ZONE_VOLUME_AZIMUTH=profile.performance.scan_volume_azimuth,
        SCAN_ZONE_VOLUME_ELEVATION=profile.performance.scan_volume_elevation,
        RADAR_PITCH_STABILIZATION=1,RADAR_ROLL_STABILIZATION=1}) do get_param_handle(name):set(value) end
    get_param_handle('IFF_INTERROGATOR_STATUS'):set(0)
    log.write('F4_SIMPLE_MANUAL',log.INFO,'MANUAL_PHASE initialized; no timed auto-lock; original radar OFF reassertion active')
end
function update()
    receive_update();update_display();tick=tick+1
    force_interlock('WATCHDOG')
    if tick%10==0 then
        -- Direct UI/input access to the original radar is blocked. Also resist initial AI power-on.
        local ok,err=pcall(function() GetDevice(52):performClickableAction(3004,0,false) end)
        if tick<=30 or not ok then
            log.write('F4_SIMPLE_MANUAL',log.INFO,'ORIGINAL_OFF_COMMANDED success='..tostring(ok)..' '..tostring(err))
        end
        log.write('F4_SIMPLE_MANUAL',log.INFO,'STATE tick='..tostring(tick)..' mode='..tostring(get_param_handle('RADAR_MODE'):get())..
            ' power='..tostring(dev:get_power())..' range='..tostring(get_param_handle('RADAR_STT_RANGE'):get()))
    end
end
