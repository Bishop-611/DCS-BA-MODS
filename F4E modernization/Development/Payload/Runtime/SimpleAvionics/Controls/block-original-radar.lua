local dev=GetSelf()
for command=3001,3999 do dev:listen_command(command) end
need_to_be_closed=false
function SetCommand(command,value)
    log.write('F4_SIMPLE_RADAR_BLOCK',log.INFO,'IGNORED original radar control '..tostring(command)..' value='..tostring(value))
end
function post_initialize()
    log.write('F4_SIMPLE_RADAR_BLOCK',log.INFO,'Original radar cockpit/key controls terminate here; no forwarding')
end
