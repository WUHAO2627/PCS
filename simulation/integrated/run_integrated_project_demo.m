clear; clc;

addpath('..\..\core_functions');
addpath('..\..\advanced_algorithms');
addpath('..\..\project\config');
addpath('..\..\project\controller');
addpath('..\..\project\integration');

cfg = system_config();
ctrl = unified_power_controller(cfg);

% Build architecture-level Simulink model.
build_integrated_system_model();

Ts = cfg.Ts;
N = 2000;

% Synthetic measurements for controller dry-run.
m = struct();
m.V_rms = 220;
m.freq = 50;
m.theta = 0;
m.v_sample = 0;
m.ia = 0; m.ib = 0; m.ic = 0;
m.vga = 311; m.vgb = -155; m.vgc = -155;
m.Vdc = cfg.vdc_ref;
m.Vbatt = 360;
m.Ibatt = 0;
m.Tbatt = 25;
m.Pref = 3e4;
m.Qref = 0;
m.va = 0; m.vb = 0; m.vc = 0;
m.iLa = 0; m.iLb = 0; m.iLc = 0;
m.vca = 0; m.vcb = 0; m.vcc = 0;
m.Vc1 = 380; m.Vc2 = 370;

mode_log = strings(1, N);
dcdc_log = zeros(1, N);

for k = 1:N
    t = (k-1) * Ts;

    if t < 0.05
        ctrl.set_mode("GRID_CONNECTED");
    elseif t < 0.1
        ctrl.set_mode("CHARGING");
    elseif t < 0.15
        ctrl.set_mode("ISLANDED");
    else
        ctrl.set_mode("BLACK_START");
    end

    m.theta = 2*pi*50*t;
    m.v_sample = 311*sin(2*pi*50*t);
    m.ia = 8*sin(2*pi*50*t);
    m.ib = 8*sin(2*pi*50*t - 2*pi/3);
    m.ic = 8*sin(2*pi*50*t + 2*pi/3);

    out = ctrl.step(m);
    mode_log(k) = string(out.mode);
    dcdc_log(k) = out.dcdc_duty;

    if isfield(out, 'charge_state')
        m.Ibatt = 30 * out.dcdc_duty;
        m.Vbatt = min(m.Vbatt + m.Ibatt * Ts * 0.02, 420);
    end
end

fprintf('Integrated controller dry-run complete.\n');
disp("Mode coverage:");
disp(unique(mode_log));
fprintf('Final DCDC duty: %.4f\n', dcdc_log(end));
