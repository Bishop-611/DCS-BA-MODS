-- Experimental constant-relative-velocity vacuum intercept. Not the native F-16 EEGS.
-- Bullet inherits shooter velocity. Gravity is world down. No unverified drag table.
local M={}
function M.solve(r,v,speed)
    local function at(t)
        local x,y,z=r.x+v.x*t,r.y+v.y*t+4.903325*t*t,r.z+v.z*t
        return math.sqrt(x*x+y*y+z*z)-speed*t,x,y,z
    end
    local lo,hi=0,0
    for i=1,100 do
        hi=i*.02
        if at(hi)<=0 then
            lo=hi-.02
            for _=1,25 do local mid=(lo+hi)/2;if at(mid)>0 then lo=mid else hi=mid end end
            local _,x,y,z=at((lo+hi)/2)
            return {x=x,y=y,z=z,time=(lo+hi)/2}
        end
    end
end
function M.new()
    local previous,velocity,count=nil,nil,0
    return function(now,r)
        if not r then previous=nil;velocity=nil;count=0;return end
        if previous then
            local dt=now-previous.time
            if dt<=0 then return end
            if dt<.095 then return end
            if dt>.3 then previous=nil;velocity=nil;count=0
            else
                local v={x=(r.x-previous.x)/dt,y=(r.y-previous.y)/dt,z=(r.z-previous.z)/dt}
                if v.x*v.x+v.y*v.y+v.z*v.z>1200^2 then previous=nil;velocity=nil;count=0
                else
                    if velocity then local k=dt/(.3+dt);for key,value in pairs(v) do velocity[key]=velocity[key]+k*(value-velocity[key]) end
                    else velocity=v end
                    count=count+1
                end
            end
        end
        previous={x=r.x,y=r.y,z=r.z,time=now}
        if count>=4 then return M.solve(r,velocity,1030) end
    end
end
return M
