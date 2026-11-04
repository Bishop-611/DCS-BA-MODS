-- Initial AIM-7M simulation profile. Numeric motor/aero data from this DCS install:
-- CoreMods/aircraft/AircraftWeaponPack/aim7_family.lua (AIM_7M and AIM_7_FM).
-- Guidance, atmosphere, terminal-energy gate and target response below are our assumptions.
return {
    name='AIM-7M',mass=231.1,area=.0324,minimum_range=1500,arm_delay=1.6,
    lifetime=75,minimum_speed=140,max_g=25,pn=3,turn_g=6,step=.15,
    boost={start=.2,duration=3.7,fuel=38.48,isp=247},
    sustain={start=3.9,duration=10.8,fuel=21.82,isp=209},
    cx={.34,.34,.34,.34,.35,1.10,1.27,1.23,1.19,1.12,1.05,1,.95,.91,.87,.84,.81,.78,.76,.74,.72},
    base_drag={.11,.11,.11,.11,.11,.18,.19,.17,.16,.14,.13,.12,.12,.11,.11,.10,.09,.09,.08,.08,.07},
    cya={1.14,1.14,1.14,1.14,1.14,1.42,1.46,1.39,1.32,1.15,1.06,1,.94,.89,.83,.78,.73,.69,.65,.61,.57},
    k1={.0056,.0056,.0056,.0056,.0056,.0056,.0056,.0056,.0052,.0048,.0045,.0041,.0037,.0036,.0034,.0032,.0031,.0030,.0029,.0027,.0026},
    k2={.0055,.0055,.0055,.0055,.0055,.0055,.0055,.0055,.0051,.0047,.0043,.0037,.0031,.0032,.0033,.0035,.0036,.0037,.0038,.0039,.0040}
}
