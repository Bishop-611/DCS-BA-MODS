local root=[[__F4_RUNTIME__/HUD/]]
local mathlib=dofile(root..'flight_math.lua')
local M={}
local packet,pending,sequence=nil,nil,nil
local params={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<1e12 end
local function set(n,v) if not params[n] then params[n]=get_param_handle('F4MH_'..n) end;params[n]:set(v) end
function M.command(cmd,value)
    if cmd<3900 or cmd>3913 or not finite(value) then pending=nil;return end
    if cmd==3900 then sequence=value;pending={};return end
    if not pending then return end
    if cmd==3913 then
        if value~=sequence then pending=nil;return end
        for i=1,12 do if not finite(pending[i]) then pending=nil;return end end
        if (pending[1]~=0 and pending[1]~=1) or pending[7]<0 or pending[7]>9 then pending=nil;return end
        packet=pending;pending=nil;return
    end
    pending[cmd-3900]=value
end
function M.update(s)
    set('CCIP_VALID',0);set('CCIP_MISSING',0);set('CCIP_UNSUPPORTED',0);set('CCIP_NO_SOLUTION',0)
    set('CCIP_NO_SELECTION',0);set('CCIP_MIXED',0);set('CCIP_WEAPON',0)
    for i=1,5 do set('CCIP_WEAPON_'..i,0) end
    for i=1,128 do set('CCIP_LINE_SHOW_'..i,0) end
    if not s.ag then return end
    local age=packet and s.time-packet[2] or nil
    if not packet or age<-.1 or age>1 then set('CCIP_MISSING',1);return end
    if packet[1]~=1 then
        if packet[7]==8 then return end -- TV and anti-radiation weapons are intentionally excluded
        if packet[7]==3 then set('CCIP_UNSUPPORTED',1)
        elseif packet[7]==2 then set('CCIP_NO_SELECTION',1)
        elseif packet[7]==7 then set('CCIP_MIXED',1)
        else set('CCIP_NO_SOLUTION',1) end
        return
    end
    if not(s.x and s.y and s.z and s.pitch and s.bank and s.heading) then set('CCIP_MISSING',1);return end
    -- Extrapolate the last footprint with launch-platform translation between solutions.
    local dx=packet[3]+packet[10]*age-s.x
    local dy=packet[4]-s.y -- footprint remains on terrain, not translated by aircraft vertical speed
    local dz=packet[5]+packet[12]*age-s.z
    local f,u,r=mathlib.body(dx,dy,dz,s.pitch,s.bank,s.heading)
    local x,y=mathlib.ray(f,u,r,0,false)
    if not x then set('CCIP_NO_SOLUTION',1);return end
    local scale=math.max(math.abs(x)/100,y>=0 and y/15 or -y/100,1)
    x,y=x/scale,y/scale
    set('CCIP_VALID',1);set('CCIP_X',x);set('CCIP_Y',y);set('CCIP_LIMIT',scale>1 and 1 or 0)
    set('CCIP_TOF',packet[6]);set('CCIP_WEAPON',packet[8])
    if packet[8]>=1 and packet[8]<=5 then set('CCIP_WEAPON_'..packet[8],1) end
    if scale==1 then
        local fx,fy=s.fpm_x or 0,s.fpm_y or 0
        local length=math.sqrt((x-fx)^2+(y+16-fy)^2)
        local count=math.min(128,math.max(1,math.ceil(length/.8)))
        for i=1,count do
            local t=(i-1)/count;local px,py=fx+(x-fx)*t,fy+(y+16-fy)*t
            if math.abs(px)<=110 and py>=-110 and py<=40 then
                set('CCIP_LINE_X_'..i,px);set('CCIP_LINE_Y_'..i,py);set('CCIP_LINE_SHOW_'..i,1)
            end
        end
    end
end
return M
