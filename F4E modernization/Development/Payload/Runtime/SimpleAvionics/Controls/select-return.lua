-- Shared cursor acquisition gate for preview and NWS; no synthetic contacts.
return function(contacts,az,range,maxrange)
    local ag,rg=math.rad(6),math.max(1500,maxrange*.08)
    local selected,best=nil,math.huge
    for _,target in ipairs(contacts) do
        local da,dr=math.abs(target.az-az),math.abs(target.range-range)
        if target.range>0 and target.range<=maxrange and (not target.age or target.age<=2) and da<=ag and dr<=rg then
            local score=(da/ag)^2+(dr/rg)^2
            if score<best then selected,best=target,score end
        end
    end
    return selected
end
