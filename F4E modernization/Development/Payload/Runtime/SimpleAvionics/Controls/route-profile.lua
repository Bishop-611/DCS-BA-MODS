-- Runs inside the input-profile environment after its original binds are built.
-- Do not add options, rename them, or change their default physical combinations.
local map=dofile([[__F4_RUNTIME__/Controls/input-map.lua]])
return function(res)
    for _,group in ipairs({res.keyCommands or {},res.axisCommands or {}}) do
        for _,bind in ipairs(group) do
            if bind.cockpit_device_id~=203 then
                for _,entry in ipairs(map) do
                    if bind.cockpit_device_id==entry.device and
                        (bind.down==entry.command or bind.action==entry.command or bind.pressed==entry.command) then
                        local target=bind.action and (entry.axis_routed or entry.routed) or entry.routed
                        for _,field in ipairs({'down','up','pressed','action'}) do
                            if bind[field]==entry.command then bind[field]=target end
                        end
                        bind.cockpit_device_id=203
                        break
                    end
                end
                -- Original radar controls keep their names/bindings but terminate at a sink.
                if bind.cockpit_device_id==52 then bind.cockpit_device_id=204 end
            end
        end
    end
    return res
end
