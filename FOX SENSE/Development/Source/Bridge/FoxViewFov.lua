-- GUI hook. Read the same FOV used by DCS's in-mission graphics settings.
-- No camera setters, input hooks, file polling, or process-memory access.
if FoxViewFovHookLoaded then return end
if type(DCS)~='table' or type(DCS.setUserCallbacks)~='function' then return end
FoxViewFovHookLoaded=true
local okLfs,fs=pcall(require,'lfs')
local okActivity,isActive=false,nil
if okLfs and type(fs)=='table' and type(fs.writedir)=='function' then okActivity,isActive=pcall(dofile,fs.writedir()..'Scripts/F4RwrLink/FoxBridgeActivity.lua') end
if not okActivity or type(isActive)~='function' then isActive=function() return false end end
local last=-1
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<1e12 end
local function clear()
    last=-1
    if type(net)=='table' and type(net.dostring_in)=='function' then
        pcall(net.dostring_in,'export','FoxViewFovSample=nil; return "ok"')
    end
end
local function frame()
    if not isActive() then return end
    if type(DCS.getModelTime)~='function' or type(DCS.getCurrentFOV)~='function' then return end
    local ok,now=pcall(DCS.getModelTime)
    if not ok or not finite(now) or (now>=last and now-last<1/60-0.0001) then return end
    last=now
    local valid,fov=pcall(DCS.getCurrentFOV)
    if not valid or not finite(fov) or fov<=1 or fov>=179 then return end
    if type(net)~='table' or type(net.dostring_in)~='function' then return end
    -- Only a validated number crosses environments. Export timestamps it locally.
    local code=string.format('FoxViewFovSample={degrees=%.9f,time=LoGetModelTime()}; return "ok"',fov)
    pcall(net.dostring_in,'export',code)
end
DCS.setUserCallbacks({onSimulationStart=clear,onSimulationStop=clear,onSimulationFrame=frame})
