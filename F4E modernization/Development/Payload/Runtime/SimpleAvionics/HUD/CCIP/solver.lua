-- Numerical impact solver. Profiles explicitly declare verified or estimated data.
-- No default profile: unknown bombs/rockets must not borrow another weapon's ballistics.
local M={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<1e12 end
function M.solve(origin,velocity,profile,terrain,wind)
 if type(profile)~='table' or not (profile.verified or profile.estimated) or type(terrain)~='function' then return nil,'NO_PROFILE' end
 if not finite(profile.mass) or profile.mass<=0 or not finite(profile.dragArea) or profile.dragArea<0 then return nil,'BAD_PROFILE' end
 for _,v in ipairs({origin,velocity}) do if type(v)~='table' or not finite(v.x) or not finite(v.y) or not finite(v.z) then return nil,'BAD_STATE' end end
 wind=wind or {x=0,y=0,z=0}
 if not finite(wind.x) or not finite(wind.y) or not finite(wind.z) then return nil,'BAD_WIND' end
 local p={x=origin.x,y=origin.y,z=origin.z};local v={x=velocity.x,y=velocity.y,z=velocity.z}
 local dt=0.02;local previous=terrain(p.x,p.z)
 if not finite(previous) or p.y<=previous then return nil,'BAD_TERRAIN' end
 local height=p.y-previous
 for i=1,6000 do
  if profile.yield_step and i%40==0 then profile.yield_step() end
  local dx,dy,dz=v.x-wind.x,v.y-wind.y,v.z-wind.z
  local speed=math.sqrt(dx*dx+dy*dy+dz*dz)
  local rho=1.225*math.exp(-math.max(0,p.y)/8500)
  local elapsed=(i-1)*dt
  local mass=profile.mass
  local motor_elapsed=elapsed-(profile.ignitionDelay or 0)
  if profile.fuelMass and profile.burnTime and profile.burnTime>0 then mass=mass-profile.fuelMass*math.max(0,math.min(1,motor_elapsed/profile.burnTime)) end
  if mass<=0 then return nil,'BAD_MASS' end
  local area=profile.dragArea
  if profile.retarder and elapsed>=profile.retarder.delay then area=profile.retarder.dragArea end
  local k=.5*rho*area*speed/mass
  local ax,ay,az=-k*dx,-9.80665-k*dy,-k*dz
  if profile.thrust and motor_elapsed>=0 and motor_elapsed<(profile.burnTime or 0) then
   local d=profile.direction;if type(d)~='table' then return nil,'NO_MOTOR_AXIS' end
   local a=profile.thrust/mass
   if profile.alignThrust and speed>1 then ax=ax+a*dx/speed;ay=ay+a*dy/speed;az=az+a*dz/speed
   else ax=ax+a*d.x;ay=ay+a*d.y;az=az+a*d.z end
  end
  local q={x=p.x+v.x*dt+.5*ax*dt*dt,y=p.y+v.y*dt+.5*ay*dt*dt,z=p.z+v.z*dt+.5*az*dt*dt}
  v.x=v.x+ax*dt;v.y=v.y+ay*dt;v.z=v.z+az*dt
  local ground=terrain(q.x,q.z)
  if not finite(ground) then return nil,'NO_TERRAIN' end
  local nextHeight=q.y-ground
  if nextHeight<=0 then
   local f=height/(height-nextHeight)
   return {x=p.x+(q.x-p.x)*f,y=p.y+(q.y-p.y)*f,z=p.z+(q.z-p.z)*f,time=(i-1+f)*dt},'OK'
  end
  p=q;height=nextHeight
 end
 return nil,'NO_IMPACT'
end
return M
