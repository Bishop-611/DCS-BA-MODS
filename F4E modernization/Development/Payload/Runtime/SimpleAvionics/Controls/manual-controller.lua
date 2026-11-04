local select_return=dofile([[__F4_RUNTIME__/Controls/select-return.lua]])
local M={}
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
function M.new(io)
    local c={acm=false,range=25,normal_range=25,x=0,y=.5,key_x=0,key_y=0,axis_x=0,axis_y=0,
        cage_press=nil,cage_long=false,nws_down=false,pending=false,index=1,previous_aa=false}
    function c:publish()
        io.state(self.acm,self.range)
    end
    function c:toggle_acm()
        io.unlock()
        self.acm=not self.acm
        if self.acm then self.normal_range=self.range;self.range=10;self.index=1;self.pending=true
        else self.range=self.normal_range;self.pending=false end
        self:publish()
    end
    function c:cage(down,now)
        if down then
            if not self.cage_press then self.cage_press=now;self.cage_long=false end
        elseif self.cage_press then
            if not self.cage_long and now-self.cage_press>=.6 then self.cage_long=true;self:toggle_acm() end
            if not self.cage_long and not self.acm then
                local ranges={5,10,25,50}
                for i,r in ipairs(ranges) do if r==self.range then self.range=ranges[i%#ranges+1];break end end
                self.normal_range=self.range;self:publish()
            end
            self.cage_press=nil;self.cage_long=false
        end
    end
    function c:nws(down)
        if down and not self.nws_down then
            if self.acm then
                self.index=1;self.pending=true;io.unlock()
            elseif io.mode()==3 or io.mode()==2 or io.busy() then io.unlock()
            else
                local az,r=self.x*math.rad(60),self.y*self.range*1852
                local selected=select_return(io.contacts(),az,r,self.range*1852)
                if selected then
                    self.x=selected.az/math.rad(60);self.y=selected.range/(self.range*1852)
                    io.cursor(selected.az,selected.range)
                    io.lock_at(selected.az,selected.range,selected.elevation)
                elseif io.no_target then io.no_target(az,r) end
            end
        end
        self.nws_down=down
    end
    function c:slew(kind,value)
        self[kind]=clamp(value,-1,1)
    end
    function c:tick(now,dt,aa)
        if not aa then
            if self.previous_aa then
                io.unlock();self.acm=false;self.range=self.normal_range;self.pending=false;self:publish()
            end
            self.cage_press=nil;self.cage_long=false;self.nws_down=false
            self.key_x=0;self.key_y=0;self.axis_x=0;self.axis_y=0
            self.previous_aa=false;return
        end
        self.previous_aa=true
        if self.cage_press and not self.cage_long and now-self.cage_press>=.6 then
            self.cage_long=true;self:toggle_acm()
        end
        local function axis(value) return math.abs(value)<.06 and 0 or value end
        self.x=clamp(self.x+(self.key_x+axis(self.axis_x))*dt*.75,-1,1)
        self.y=clamp(self.y+(self.key_y+axis(self.axis_y))*dt*.40,0,1)
        if not self.acm then io.cursor(self.x*math.rad(60),self.y*self.range*1852) end
        if self.acm and self.pending and io.mode()==1 and not io.busy() then
            local candidates={}
            for _,target in ipairs(io.contacts()) do
                if target.range>300 and target.range<=10*1852 and math.abs(target.az)<=math.rad(60) then
                    candidates[#candidates+1]=target
                end
            end
            table.sort(candidates,function(a,b) return a.range<b.range end)
            if #candidates>0 then
                local target=candidates[1]
                self.index=1;self.pending=false
                io.lock_at(target.az,target.range,target.elevation)
            end
        end
        if self.acm and not self.pending and io.mode()==1 and not io.busy() then self.pending=true end
        if io.mode()==3 then io.iff() end
    end
    c:publish()
    return c
end
return M
