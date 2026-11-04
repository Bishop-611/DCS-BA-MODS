-- Experimental simple-radar profile. These are configuration targets, not measured APG-73 performance.
return {
    name='AA_80x20_4BEAM_25NM_V2',
    range_nm=25,
    display_history_seconds=5,
    display_batch_window_seconds=.25,
    performance={
        roll_compensation_limits={math.rad(-180),math.rad(180)},
        pitch_compensation_limits={math.rad(-60),math.rad(60)},
        tracking_azimuth={math.rad(-60),math.rad(60)},
        tracking_elevation={math.rad(-60),math.rad(60)},
        scan_volume_azimuth=math.rad(80),
        scan_volume_elevation=math.rad(20),
        scan_beam=math.rad(5),
        -- Native range is RCS-dependent: this is not a 200km fighter detection guarantee.
        max_available_distance=200000,
        scan_speed=math.rad(120),
        dead_zone=1,
        ground_clutter={sea={0,0,0},land={0,0,0},artificial={0,0,0},rays_density=.01,max_distance=1852}
    }
}
