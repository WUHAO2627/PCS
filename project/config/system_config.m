function cfg = system_config()
% Unified configuration for integrated EMS/power-conversion project.

cfg.Ts = 1e-4;
cfg.f_nom = 50;
cfg.vdc_ref = 750;
cfg.vac_ll_rms = 380;

cfg.battery.cells_series = 100;
cfg.battery.cc_current = 50;
cfg.battery.cv_voltage_per_cell = 4.2;
cfg.battery.taper_current = 2;

cfg.protection.anti_islanding_trip_s = 2.0;
cfg.protection.grid_reconnect_delay_s = 5.0;

cfg.parallel.max_units = 3;
cfg.parallel.rated_va = [100e3, 100e3, 50e3];

cfg.mode.default = "GRID_CONNECTED";
end
