-- World x north/y up/z east; clockwise heading; body x forward/y up/z right.
local M={}
function M.finite(v) return type(v)=='number' and v==v and math.abs(v)<1e10 end
function M.clamp(v,a,b) return math.max(a,math.min(b,v)) end
function M.body(x,y,z,pitch,bank,heading)
    local cp,sp,ch,sh,cb,sb=math.cos(pitch),math.sin(pitch),math.cos(heading),math.sin(heading),math.cos(bank),math.sin(bank)
    local f=x*cp*ch+y*sp+z*cp*sh
    local u=-x*sp*ch+y*cp-z*sp*sh
    local r=-x*sh+z*ch
    return f,u*cb+r*sb,r*cb-u*sb
end
function M.world(f,u,r,pitch,bank,heading)
    local cb,sb,cp,sp,ch,sh=math.cos(bank),math.sin(bank),math.cos(pitch),math.sin(pitch),math.cos(heading),math.sin(heading)
    local u0,r0=u*cb-r*sb,u*sb+r*cb
    local horizontal=f*cp-u0*sp
    return horizontal*ch-r0*sh,f*sp+u0*cp,horizontal*sh+r0*ch
end
function M.ray(f,u,r,trim,limit)
    if f<=1e-6 then return nil end
    -- Collimator image-plane coordinates, not independent azimuth/elevation angles.
    local x,y=r/f*1000,u/f*1000+(trim or 0)
    if limit then
        local scale=math.max(math.abs(x)/95,y>=0 and y/42 or -y/100,1)
        return x/scale,y/scale,scale>1
    end
    return x,y,math.abs(x)<=110 and y>=-110 and y<=40
end
function M.hud_angles(az,el,trim)
    if not(M.finite(az) and M.finite(el)) or math.abs(az)>=math.pi/2 or math.abs(el)>=math.pi/2 then return nil end
    local x,y=az*1000,el*1000+(trim or 0)
    local scale=math.max(math.abs(x)/95,y>=0 and y/42 or -y/100,1)
    return x/scale,y/scale,scale>1
end
function M.project(x,y,z,pitch,bank,heading,trim)
    for _,v in ipairs({x,y,z,pitch,bank,heading}) do if not M.finite(v) then return nil end end
    if x*x+y*y+z*z<225 then return nil end
    local f,u,r=M.body(x,y,z,pitch,bank,heading)
    return M.ray(f,u,r,trim,true)
end
function M.ladder_point(degrees,offset,pitch,bank,trim)
    if not(M.finite(pitch) and M.finite(bank)) then return nil end
    local p,h=math.rad(degrees),math.rad(offset)
    local f,u,r=M.body(math.cos(p)*math.cos(h),math.sin(p),math.cos(p)*math.sin(h),pitch,bank,0)
    return M.ray(f,u,r,trim,false)
end
function M.ladder(degrees,pitch,bank,trim)
    local x,y,visible=M.ladder_point(degrees,0,pitch,bank,trim)
    return x or 0,y or 0,visible or false
end
function M.ladder_stroke(degrees,xmil,ymil,pitch,bank,trim)
    if not(M.finite(pitch) and M.finite(bank)) then return nil end
    local a=math.rad(degrees)
    local x,y=xmil/1000,ymil/1000
    local f,u,r=M.body(math.cos(a)-y*math.sin(a),math.sin(a)+y*math.cos(a),x,pitch,bank,0)
    return M.ray(f,u,r,trim,false)
end
return M
