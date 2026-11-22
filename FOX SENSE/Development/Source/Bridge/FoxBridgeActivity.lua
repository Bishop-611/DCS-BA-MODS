-- A fresh local HUD heartbeat is required before doing any export work.
-- Cached at one filesystem stat per wall-clock second while idle or active.
local checked,active=nil,false
local fs=lfs
if not fs and type(require)=='function' then local ok,value=pcall(require,'lfs');if ok then fs=value end end
return function()
    if not (os and type(os.time)=='function' and fs and type(fs.attributes)=='function' and type(fs.writedir)=='function') then return false end
    local now=os.time()
    if checked==now then return active end
    checked=now;active=false
    local ok,modified=pcall(fs.attributes,fs.writedir()..'Logs/FoxSense.active','modification')
    if ok and type(modified)=='number' and now-modified>=-1 and now-modified<=3 then active=true end
    return active
end
