local root=[[__F4_RUNTIME__/HUD/]]
local mathlib,ballistics=dofile(root..'flight_math.lua'),dofile(root..'gun_math.lua')
local previous,velocity,samples=nil,nil,0
local last_status,last_log=nil,-10
local params={}
local function set(n,v)
    if not params[n] then params[n]=get_param_handle('F4MH_'..n) end
    params[n]:set(v)
end
local function get(n) return get_param_handle(n):get() end
return function(s)
    set('GUN_SIGHT_VALID',0)
    set('GUN_SIGHT_LIMIT',0)
    local function status(name)
        set('GUN_RANGE',name=='RANGE' and 1 or 0)
        set('GUN_WAIT',name=='WAIT' and 1 or 0)
        set('GUN_NO_SOLUTION',name=='NO_SOLUTION' and 1 or 0)
        if name~=last_status or (name~='OFF' and s.time-last_log>=5) then
            if type(log)=='table' then log.write('F4_GUN_SIGHT',log.INFO,'state='..name..' range='..tostring(get('RADAR_STT_RANGE'))..' samples='..samples) end
            last_status=name;last_log=s.time
        end
    end
    local range=get('RADAR_STT_RANGE')
    if not(s.aa and s.gun and get('RADAR_MODE')==3 and range>0
        and s.pitch and s.bank and s.heading) then previous=nil;velocity=nil;samples=0;status('OFF');return end
    if range<250 or range>1500 then previous=nil;velocity=nil;samples=0;status('RANGE');return end
    local u,r=math.tan(get('RADAR_STT_ELEVATION')),math.tan(get('RADAR_STT_AZIMUTH'))
    local norm=math.sqrt(1+u*u+r*r)
    local x,y,z=mathlib.world(range/norm,range*u/norm,range*r/norm,s.pitch,s.bank,s.heading)
    local dt=previous and s.time-previous.time or nil
    if dt and (dt<=0 or dt>.3) then previous=nil;velocity=nil;samples=0;dt=nil end
    if not dt or dt>=.095 then
        if dt then
            local v={x=(x-previous.x)/dt,y=(y-previous.y)/dt,z=(z-previous.z)/dt}
            if v.x*v.x+v.y*v.y+v.z*v.z>1200^2 then velocity=nil;samples=0
            else
                if velocity then local k=dt/(.25+dt);for key,value in pairs(v) do velocity[key]=velocity[key]+k*(value-velocity[key]) end
                else velocity=v end
                samples=samples+1
            end
        end
        previous={time=s.time,x=x,y=y,z=z}
    end
    if velocity and samples>=4 then
        local solution=ballistics.solve({x=x,y=y,z=z},velocity,1030)
        if solution then
            local f,u,r=mathlib.body(solution.x,solution.y,solution.z,s.pitch,s.bank,s.heading)
            local gx,gy=mathlib.ray(f,u,r,0,false)
            if gx then
                local scale=math.max(math.abs(gx)/90,gy>=0 and gy/24 or -gy/92,1)
                set('GUN_SIGHT_X',gx/scale);set('GUN_SIGHT_Y',gy/scale)
                set('GUN_SIGHT_VALID',1);set('GUN_SIGHT_LIMIT',scale>1 and 1 or 0)
                status(scale>1 and 'LIMIT' or 'VALID')
            else status('NO_SOLUTION') end
        else status('NO_SOLUTION') end
    else status('WAIT') end
end
