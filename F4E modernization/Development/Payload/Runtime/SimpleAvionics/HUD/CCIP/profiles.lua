-- Initial calibration profiles, not validated native FM replicas.
-- GBU-12 is a distinct unpowered ballistic reference; no laser guidance is predicted.
local M={}
function M.select(name,input)
    if type(name)~='string' then return nil end
    local n=name:upper():gsub('[^%w]','')
    -- F-4 Entry/Weapons.lua maps its LAU3/LAU68 FFAR stores to HYDRA_70_MK* wsTypes.
    -- Export therefore reports Hydra labels for those F-4 stores. Aircraft-scoped
    -- compatibility aliases use our existing approximate FFAR model, not a claim
    -- to reproduce the closed native Hydra/Mk66 flight model on other aircraft.
    if input and input.aircraft=='F-4E-45MC' then
        local aliases={HYDRA70MK1HE='FFARMK1HE',HYDRA70MK5HEAT='FFARMK5HEAT',HYDRA70M156WP='FFARM156WP'}
        n=aliases[n] or n
    end
    if n=='M61A1' then return {estimated=true,mass=.1,dragArea=.00011,muzzle=1030,bore=-.03,kind='GUN',code=2} end
    -- F-4 Entry/Weapons.lua supplies distinct store masses; Cd remains a calibration model.
    local lgb={GBU12={277,.279},GBU12B={277,.279},GBU16={513,.356},GBU16B={513,.356},GBU24={1087,.457},BDU45LGB={277,.279}}
    if lgb[n] then local p=lgb[n];return {estimated=true,mass=p[1],dragArea=math.pi*p[2]^2*.25*.38,muzzle=0,kind='LGB_BALLISTIC',code=1} end
    local bombs={MK81={118,.229,.25},MK82={228,.273,.25},MK82LD={228,.273,.25},MK83={454,.356,.25},MK84={908,.457,.25},M117={340,.408,.3},BDU33={11.3,.1,.25},BDU45={232,.273,.25},BDU45B={232,.273,.25},BDU50LD={241,.273,.25}}
    for key,p in pairs(bombs) do if n==key then return {estimated=true,mass=p[1],dragArea=math.pi*p[2]^2*.25*p[3],muzzle=0,kind='BOMB',code=3} end end
    local retarded={MK82SNAKEYE={249.5,.273},MK82AIR={242,.273},MK82Y={232,.273},BDU50HD={241,.273}}
    if retarded[n] then
        if not input or input.arming==nil then return nil end
        local p=retarded[n];local area=math.pi*p[2]^2*.25
        return {estimated=true,mass=p[1],dragArea=area*.25,muzzle=0,kind='RETARDED_BOMB',code=3,
            retarder=input.tailArmed and {delay=.4,dragArea=area*2} or nil}
    end
    -- Mk4 FFAR predecessor data in local FFAR.lua: 3.3kN for1.3s,3kg fuel;
    -- per-warhead masses differ. F-4-specific export aliases above are approximate.
    local ffar={FFARMK1HE=21.5*.453592,FFARMK5HEAT=21.6*.453592,FFARM156WP=24.7*.453592}
    if ffar[n] then return {estimated=true,mass=ffar[n],fuelMass=3,dragArea=math.pi*.06985^2*.25*.4,
        muzzle=0,thrust=3300,burnTime=1.3,alignThrust=true,kind='ROCKET',code=4} end
    -- F4 LAU10: (288.9 - 61.7)/4 = 56.8 kg per Zuni. Native Mk71Mod1
    -- and Zuni_WAFAR definitions are opaque. Motor duration/thrust and Cd below
    -- are explicit first-pass calibration assumptions, NOT extracted native FM.
    if n=='ZUNI127' or n=='ZUNIMK24MOD1HE' or n=='ZUNIMK71' then
        return {estimated=true,mass=56.8,dragArea=math.pi*.127^2*.25*.4,
            muzzle=0,thrust=36000,burnTime=1.8,alignThrust=true,kind='ROCKET',code=4,
            calibration='ZUNI_CONSTANT_MASS_MOTOR_ASSUMPTION'}
    end
    -- User-requested bomb-like reference for free-fall cluster dispensers.
    -- Distinct F4 store masses; area/Cd are calibration estimates. Predicts the
    -- unopened mother body's reference impact, not bomblet footprint/centroid.
    local clusters={ROCKEYE={222,.335},MK20={222,.335},MK20ROCKEYE={222,.335},CBU99={222,.335},
        CBU87={430,.406},CBU52B={356,.409},BL755={278,.419}}
    if clusters[n] then local p=clusters[n];return {estimated=true,mass=p[1],
        dragArea=math.pi*p[2]^2*.25*.35,muzzle=0,kind='CLUSTER_BALLISTIC',code=3,
        calibration='UNOPENED_MOTHER_BODY_REFERENCE'} end
    -- Powered, no-steering reference only; manual guidance after launch is not forecast.
    local bullpup={AGM12A={257,.3048,41.88,230,2.5},AGM12B={263,.3048,40,270,2},AGM12C={811.5,.4318,122.53,270,2.28},AGM12CED={811.5,.4318,122.53,270,2.28}}
    if bullpup[n] then local p=bullpup[n];return {estimated=true,mass=p[1],fuelMass=p[3],dragArea=math.pi*p[2]^2*.25*.34,
        muzzle=0,thrust=p[4]*9.80665*p[3]/p[5],burnTime=p[5],ignitionDelay=.1,alignThrust=true,kind='MCLOS_REFERENCE',code=5} end
    return nil
end
return M
