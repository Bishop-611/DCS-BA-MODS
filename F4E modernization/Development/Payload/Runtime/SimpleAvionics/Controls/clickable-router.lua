return function(elements)
    local map=dofile([[__F4_RUNTIME__/Controls/input-map.lua]])
    for _,element in pairs(elements) do
        local original=element.device
        if original==52 then
            local power=false
            for _,action in ipairs(element.action or {}) do if action==3004 then power=true end end
            element.device=power and 203 or 204
            if power then
                for _,field in ipairs({'action','stop_action'}) do
                    for i in ipairs(element[field] or {}) do element[field][i]=3009 end
                end
            end
        else
            for _,entry in ipairs(map) do
                if original==entry.device then
                    local matches=false
                    for _,action in ipairs(element.action or {}) do if action==entry.command then matches=true end end
                    if matches then
                        element.device=203
                        for _,field in ipairs({'action','stop_action'}) do
                            for i,action in ipairs(element[field] or {}) do
                                if action==entry.command then element[field][i]=entry.routed end
                            end
                        end
                        break
                    end
                end
            end
        end
    end
end
