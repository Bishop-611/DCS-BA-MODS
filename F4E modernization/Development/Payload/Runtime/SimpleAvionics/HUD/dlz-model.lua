-- DCS-only approximate planar intercept model, not F-15C native code.
-- Integrates motor mass flow, Mach-dependent drag, PN turning and a separate escape turn.
local M={}
local g=9.80665
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<1e9 end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function wrap(x) return (x+math.pi)%(2*math.pi)-math.pi end
local function table_at(tab,mach)
    local n=clamp(mach/.2,0,#tab-1);local i=math.floor(n)+1
    return tab[i]+(tab[math.min(i+1,#tab)]-tab[i])*(n-math.floor(n))
end
local function atmosphere(h)
    h=clamp(h,0,20000)
    local temp=288.15-.0065*math.min(h,11000)
    local pressure=h<=11000 and 101325*(temp/288.15)^5.25588 or 22632*math.exp(-(h-11000)/6341.62)
    return pressure/(287.05287*temp),math.sqrt(1.4*287.05287*temp)
end
function M.intercept(s,p,range,escape)
    local mx,my,tx,ty,v,angle=0,0,range,0,s.speed,s.launch_angle or 0
    local target_speed=math.sqrt(s.target_radial^2+s.target_lateral^2)
    local target_angle=math.atan2(s.target_lateral,s.target_radial)
    local dt=p.step
    for i=1,math.floor(p.lifetime/dt) do
        local t=i*dt
        if escape and target_speed>10 then
            -- Immediate sustained level 6-G turn toward a tail-away heading.
            local turn=g*math.sqrt(p.turn_g^2-1)/target_speed
            target_angle=target_angle+clamp(wrap(-target_angle),-turn*dt,turn*dt)
        end
        local tvx,tvy=target_speed*math.cos(target_angle),target_speed*math.sin(target_angle)
        local mvx,mvy=v*math.cos(angle),v*math.sin(angle)
        local rx,ry=tx-mx,ty-my
        local r2=rx*rx+ry*ry;local r=math.sqrt(r2)
        if r<math.max(25,v*dt*.7) then
            if t>=p.arm_delay and v>=math.max(p.minimum_speed,target_speed+50) then return true,t,v end
            return false
        end
        local dvx,dvy=tvx-mvx,tvy-mvy
        local closing=-(rx*dvx+ry*dvy)/math.max(r,1)
        local los_rate=(rx*dvy-ry*dvx)/math.max(r2,1)
        local normal=t>=p.arm_delay and clamp(p.pn*math.max(closing,0)*los_rate,-p.max_g*g,p.max_g*g) or 0
        local mass,thrust=p.mass,0
        for _,motor in ipairs({p.boost,p.sustain}) do
            local burnt=clamp(t-motor.start,0,motor.duration)
            mass=mass-motor.fuel*burnt/motor.duration
            if t>=motor.start and t<motor.start+motor.duration then thrust=thrust+motor.isp*g*motor.fuel/motor.duration end
        end
        local height=s.altitude+(s.target_altitude-s.altitude)*clamp(mx/math.max(range,1),0,1)
        local rho,sound=atmosphere(height)
        local q=.5*rho*v*v;local mach=v/sound
        local alpha=math.abs(normal)*mass/math.max(q*p.area*table_at(p.cya,mach),1)
        alpha=math.min(alpha,20)
        local cd=table_at(p.cx,mach)+(thrust==0 and table_at(p.base_drag,mach) or 0)
            +table_at(p.k1,mach)*alpha+table_at(p.k2,mach)*alpha*alpha
        local acceleration=(thrust-q*p.area*cd)/mass-g*(s.climb_sine or 0)
        angle=angle+normal/math.max(v,1)*dt
        v=math.max(0,v+acceleration*dt)
        mx=mx+v*math.cos(angle)*dt;my=my+v*math.sin(angle)*dt
        tx=tx+tvx*dt;ty=ty+tvy*dt
        if t>p.sustain.start+p.sustain.duration and v<p.minimum_speed then return false end
        if mx< -500 or math.abs(my)>100000 then return false end
    end
    return false
end
function M.solve(s,p,yield_step)
    for _,key in ipairs({'speed','altitude','target_altitude','target_radial','target_lateral','range'}) do
        if not finite(s[key]) then return nil,'INVALID_INPUT' end
    end
    if s.speed<100 or s.speed>1000 or s.range<=0 or s.altitude<0 or s.altitude>20000
        or math.abs(s.target_radial)>1000 or math.abs(s.target_lateral)>1000 then return nil,'OUTSIDE_MODEL' end
    local function trial(range,escape)
        local hit,t=M.intercept(s,p,range,escape)
        if yield_step then yield_step() end
        return hit,t
    end
    local function envelope(escape)
        -- Scan first: acquisition/arming can make the close-in region non-monotonic.
        local best=0
        for r=p.minimum_range,60000,2000 do if trial(r,escape) then best=r end end
        if best==0 then return nil end
        local lo,hi=best,math.min(best+2000,60000)
        for _=1,9 do local mid=(lo+hi)/2;if trial(mid,escape) then lo=mid else hi=mid end end
        return lo
    end
    local rpi=envelope(false);if not rpi then return nil,'NO_INTERCEPT' end
    local rtr=envelope(true)
    if rtr then rtr=math.min(rtr,rpi) end
    local hit,tof=trial(s.range,false)
    return {rmin=p.minimum_range,rpi=rpi,rtr=rtr,tof=hit and tof or nil}
end
return M
