local M={}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<1e8 end
function M.dlz(a,b,c,r)
 if not(finite(a) and finite(b) and finite(r)) or a<0 or b<=a or r<=0 then return end
 local scale=math.ceil(math.max(b*1.15,r*1.1)/5)*5
 local bottom,top=-92,-28
 local function y(v,low,high)
  local raw=bottom+(top-bottom)*math.max(0,math.min(1,v/scale))
  return math.max(bottom+low,math.min(top-high,raw))
 end
 -- Bound the entire stroke, including its .75mil half-width, not only its anchor.
 local minimum,maximum=y(a,.75,3.75),y(b,3.75,.75)
 local secondary=finite(c) and c>=a and c<=b and y(c,2.75,2.75) or nil
 if secondary and (math.abs(secondary-minimum)<3 or math.abs(secondary-maximum)<3) then secondary=nil end
 return {minimum=minimum,maximum=maximum,secondary=secondary,target=y(r,4.75,4.75),scale=scale,range=r}
end
function M.los(az,el,trim)
 if not(finite(az) and finite(el)) or math.abs(az)>=85 or math.abs(el)>=85 then return end
 local a,e=math.rad(az),math.rad(el)
 local x=math.atan2(math.cos(e)*math.sin(a),math.cos(e)*math.cos(a))*1000
 local y=math.atan2(math.sin(e),math.cos(e)*math.cos(a))*1000
 y=y+(finite(trim) and trim or 0)
 local limit=math.max(math.abs(x)/110,y>=0 and y/38 or -y/105,1)
 return x/limit,y/limit,limit>1
end
function M.funnel(pitch,bank,pitchRate,yawRate,span)
 if not(finite(pitch) and finite(bank) and finite(pitchRate) and finite(yawRate) and finite(span)) or span<5 or span>50 then return end
 if math.abs(pitchRate)>4 or math.abs(yawRate)>4 then return end
 local left,right={},{}
 for i=0,15 do
  local range=250+i*75;local t=range/1030
  local half=math.atan(span/(2*range))*1000
  local x=-.5*yawRate*t*1000+.5*9.80665*math.cos(pitch)*math.sin(bank)*t*t/range*1000
  -- Body-axis ballistic reference. The shared optical offset is applied once
  -- by the device; a second hard-coded depression here displaced the funnel.
  local y=-.5*pitchRate*t*1000-.5*9.80665*math.cos(pitch)*math.cos(bank)*t*t/range*1000
  left[i+1]={x=x-half,y=y};right[i+1]={x=x+half,y=y}
 end
 return left,right
end
return M
