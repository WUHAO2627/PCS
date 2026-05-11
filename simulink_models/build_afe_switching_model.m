%% Build AFE Rectifier Switching Model (R2024b)
% Detailed three-phase PWM rectifier with IGBT bridge, switching transients,
% carrier PWM, PI controllers, and Simscape power elements.

function build_afe_switching_model()

model_name = 'afe_switching_rectifier';

% Close existing model if loaded
if bdIsLoaded(model_name)
    close_system(model_name, 0);
end
new_system(model_name);
open_system(model_name);

%% Simulation configuration for switching-level
set_param(model_name, 'StopTime', '0.5');
set_param(model_name, 'Solver', 'ode23tb');      % Variable-step for switching transients
set_param(model_name, 'MaxStep', '1e-5');        % Max 10 us
set_param(model_name, 'MinStep', '1e-8');
set_param(model_name, 'RelTol', '1e-4');
set_param(model_name, 'AbsTol', '1e-6');

%% Add Simscape power components
add_block('powerlib/powergui', [model_name '/powergui']);
set_param([model_name '/powergui'], 'SimulationMode', 'Discrete');
set_param([model_name '/powergui'], 'SampleTime', '1e-5');

%% ===== AC Side: Grid + Series R-L =====
add_block('powerlib/Electrical Sources/Three-Phase Source', [model_name '/Grid']);
set_param([model_name '/Grid'], 'Voltage', '380 V');
set_param([model_name '/Grid'], 'Frequency', '50 Hz');
set_param([model_name '/Grid'], 'PhaseAngle', '0 deg');
set_param([model_name '/Grid'], 'InternalResistance', '[0.01 0.01 0.01] Ohm');

% Series AC-side L-R
add_block('powerlib/Elements/Series RLC Branch', [model_name '/Lac_Rac']);
set_param([model_name '/Lac_Rac'], 'BranchType', 'RL');
set_param([model_name '/Lac_Rac'], 'Resistance', '[0.05 0.05 0.05] Ohm');
set_param([model_name '/Lac_Rac'], 'Inductance', '[5e-3 5e-3 5e-3] H');

%% ===== IGBT Bridge (Universal Bridge for 6-pulse rectifier) =====
add_block('powerlib/Power Electronics/Universal Bridge', [model_name '/IGBT_Bridge']);
set_param([model_name '/IGBT_Bridge'], 'Arms', '3');
set_param([model_name '/IGBT_Bridge'], 'Device', 'IGBT / Diodes');
set_param([model_name '/IGBT_Bridge'], 'Snubber', 'RC');
set_param([model_name '/IGBT_Bridge'], 'Ron', '0.01 Ohm');
set_param([model_name '/IGBT_Bridge'], 'Lon', '0');
set_param([model_name '/IGBT_Bridge'], 'Vf', '0.8 V');
set_param([model_name '/IGBT_Bridge'], 'Tf', '0.2 us');

%% ===== DC Side: Split Capacitor Bus =====
add_block('powerlib/Elements/Series RLC Branch', [model_name '/C_upper']);
set_param([model_name '/C_upper'], 'BranchType', 'C');
set_param([model_name '/C_upper'], 'Capacitance', '2350e-6 F');

add_block('powerlib/Elements/Series RLC Branch', [model_name '/C_lower']);
set_param([model_name '/C_lower'], 'BranchType', 'C');
set_param([model_name '/C_lower'], 'Capacitance', '2350e-6 F');

% DC-side load (dynamic)
add_block('powerlib/Elements/Programmable Voltage Source', [model_name '/Vdc_Load']);
set_param([model_name '/Vdc_Load'], 'Amplitude', '750');

%% ===== Measurements =====
add_block('powerlib/Measurements/Three-Phase V-I Measurement', [model_name '/VI_AC']);
add_block('powerlib/Measurements/Voltage Measurement', [model_name '/V_Cpos']);
add_block('powerlib/Measurements/Voltage Measurement', [model_name '/V_Cneg']);
add_block('powerlib/Measurements/Current Measurement', [model_name '/I_dc']);

%% ===== Control System =====
% PLL + Grid voltage measurement
add_block('simulink/Ports & Subsystems/Subsystem', [model_name '/PLL_GFL_Controller']);
ctrl_subsys = [model_name '/PLL_GFL_Controller'];
populate_pll_gfl_switching(ctrl_subsys);

% PWM Carrier + Comparator
add_block('simulink/Sources/Repeating Sequence', [model_name '/Carrier_TriangleWave']);
set_param([model_name '/Carrier_TriangleWave'], 'rep_seq_t', '[0 5e-6 1e-5]');
set_param([model_name '/Carrier_TriangleWave'], 'rep_seq_y', '[0 1 0]');

add_block('simulink/Logic and Bit Operations/Relational Operator', [model_name '/Comp_A']);
set_param([model_name '/Comp_A'], 'Operator', '>');
add_block('simulink/Logic and Bit Operations/Relational Operator', [model_name '/Comp_B']);
set_param([model_name '/Comp_B'], 'Operator', '>');
add_block('simulink/Logic and Bit Operations/Relational Operator', [model_name '/Comp_C']);
set_param([model_name '/Comp_C'], 'Operator', '>');

% Gate drivers
add_block('simulink/Logic and Bit Operations/Logical Operator', [model_name '/Inv_A']);
set_param([model_name '/Inv_A'], 'Operator', 'NOT');
add_block('simulink/Logic and Bit Operations/Logical Operator', [model_name '/Inv_B']);
set_param([model_name '/Inv_B'], 'Operator', 'NOT');
add_block('simulink/Logic and Bit Operations/Logical Operator', [model_name '/Inv_C']);
set_param([model_name '/Inv_C'], 'Operator', 'NOT');

%% ===== Scopes =====
add_block('simulink/Sinks/Scope', [model_name '/Scope_V_AC']);
add_block('simulink/Sinks/Scope', [model_name '/Scope_I_AC']);
add_block('simulink/Sinks/Scope', [model_name '/Scope_Vdc']);
add_block('simulink/Sinks/Scope', [model_name '/Scope_Idc']);
add_block('simulink/Sinks/Scope', [model_name '/Scope_Gate_Signals']);

%% ===== Wiring (Power Side) =====
% Grid -> Series RL -> IGBT Bridge AC
add_line(model_name, 'Grid/LV+', 'Lac_Rac/LV+', 'autorouting', 'on');
add_line(model_name, 'Lac_Rac/RV+', 'IGBT_Bridge/a', 'autorouting', 'on');
add_line(model_name, 'IGBT_Bridge/+', 'C_upper/+', 'autorouting', 'on');
add_line(model_name, 'C_upper/-', 'C_lower/+', 'autorouting', 'on');
add_line(model_name, 'C_lower/-', 'IGBT_Bridge/-', 'autorouting', 'on');

% DC measurements
add_line(model_name, 'C_upper/+', 'V_Cpos/+', 'autorouting', 'on');
add_line(model_name, 'C_lower/-', 'V_Cpos/-', 'autorouting', 'on');
add_line(model_name, 'C_upper/-', 'V_Cneg/+', 'autorouting', 'on');
add_line(model_name, 'C_lower/+', 'V_Cneg/-', 'autorouting', 'on');
add_line(model_name, 'C_upper/+', 'I_dc/+', 'autorouting', 'on');
add_line(model_name, 'I_dc/-', 'Vdc_Load/~', 'autorouting', 'on');

% AC measurements
add_line(model_name, 'VI_AC/V', 'Scope_V_AC/1', 'autorouting', 'on');
add_line(model_name, 'VI_AC/I', 'Scope_I_AC/1', 'autorouting', 'on');
add_line(model_name, 'V_Cpos/v', 'Scope_Vdc/1', 'autorouting', 'on');
add_line(model_name, 'V_Cneg/v', 'Scope_Vdc/2', 'autorouting', 'on');
add_line(model_name, 'I_dc/i', 'Scope_Idc/1', 'autorouting', 'on');

%% ===== Control Wiring =====
% Measurements -> Control
add_line(model_name, 'VI_AC/V', [model_name '/PLL_GFL_Controller/1'], 'autorouting', 'on');
add_line(model_name, 'VI_AC/I', [model_name '/PLL_GFL_Controller/2'], 'autorouting', 'on');
add_line(model_name, 'V_Cpos/v', [model_name '/PLL_GFL_Controller/3'], 'autorouting', 'on');

% Control -> Gate Drivers
add_line(model_name, [model_name '/PLL_GFL_Controller/1'], 'Comp_A/1', 'autorouting', 'on');
add_line(model_name, [model_name '/PLL_GFL_Controller/2'], 'Comp_B/1', 'autorouting', 'on');
add_line(model_name, [model_name '/PLL_GFL_Controller/3'], 'Comp_C/1', 'autorouting', 'on');
add_line(model_name, 'Carrier_TriangleWave/1', 'Comp_A/2', 'autorouting', 'on');
add_line(model_name, 'Carrier_TriangleWave/1', 'Comp_B/2', 'autorouting', 'on');
add_line(model_name, 'Carrier_TriangleWave/1', 'Comp_C/2', 'autorouting', 'on');

% Gate signals
add_line(model_name, 'Comp_A/1', 'IGBT_Bridge/1', 'autorouting', 'on');
add_line(model_name, 'Comp_B/1', 'IGBT_Bridge/3', 'autorouting', 'on');
add_line(model_name, 'Comp_C/1', 'IGBT_Bridge/5', 'autorouting', 'on');
add_line(model_name, 'Comp_A/1', 'Scope_Gate_Signals/1', 'autorouting', 'on');
add_line(model_name, 'Comp_B/1', 'Scope_Gate_Signals/2', 'autorouting', 'on');
add_line(model_name, 'Comp_C/1', 'Scope_Gate_Signals/3', 'autorouting', 'on');

%% Save
save_system(model_name);
fprintf('AFE switching-level rectifier model "%s" created successfully.\n', model_name);
fprintf('Features: IGBT bridge, PWM carrier, PLL + GFL control, detailed DC bus.\n');

end

%% ===== PLL + GFL Control Subsystem =====
function populate_pll_gfl_switching(sys)
% Inputs: [V_abc, I_abc, Vdc_meas]
% Outputs: [duty_a, duty_b, duty_c]

try delete_line(sys, 'In1/1', 'Out1/1'); catch, end
try delete_block([sys '/In1']); catch, end
try delete_block([sys '/Out1']); catch, end

% Inputs
add_block('simulink/Ports & Subsystems/In1', [sys '/V_abc'], 'Position', [30 30 60 50]);
add_block('simulink/Ports & Subsystems/In1', [sys '/I_abc'], 'Position', [30 80 60 100]);
add_block('simulink/Ports & Subsystems/In1', [sys '/Vdc_meas'], 'Position', [30 130 60 150]);

% Outputs
add_block('simulink/Ports & Subsystems/Out1', [sys '/Duty_a'], 'Position', [650 30 680 50]);
add_block('simulink/Ports & Subsystems/Out1', [sys '/Duty_b'], 'Position', [650 80 680 100]);
add_block('simulink/Ports & Subsystems/Out1', [sys '/Duty_c'], 'Position', [650 130 680 150]);

% PLL
add_block('simulink/User-Defined Functions/MATLAB Function', [sys '/PLL'], ...
    'Position', [120 20 240 60]);
set_ml_fcn_switching(sys, 'PLL', [...
    'function theta = fcn(Vabc)' newline ...
    '%#codegen' newline ...
    'persistent th integ w' newline ...
    'if isempty(th), th = 0; integ = 0; w = 2*pi*50; end' newline ...
    'Ts = 1e-5; Kp = 100; Ki = 5000;' newline ...
    'va = Vabc(1); vb = Vabc(2);' newline ...
    'v_alpha = 2/3*(va - 0.5*vb);' newline ...
    'v_beta = 2/3*sqrt(3)/2*vb;' newline ...
    'vq = -v_alpha*sin(th) + v_beta*cos(th);' newline ...
    'integ = integ + Ki*vq*Ts;' newline ...
    'w = Kp*vq + integ + 2*pi*50;' newline ...
    'th = mod(th + w*Ts, 2*pi);' newline ...
    'theta = th;' newline ...
    'end']);

% GFL Control (simplified, focusing on Vdc loop and current loop)
add_block('simulink/User-Defined Functions/MATLAB Function', [sys '/GFL_Control'], ...
    'Position', [320 20 500 120]);
set_ml_fcn_switching(sys, 'GFL_Control', [...
    'function [da, db, dc] = fcn(Vabc, Iabc, theta, Vdc_meas)' newline ...
    '%#codegen' newline ...
    'persistent int_vdc int_d int_q' newline ...
    'if isempty(int_vdc), int_vdc=0; int_d=0; int_q=0; end' newline ...
    'Ts = 1e-5; Kp_vdc = 1; Ki_vdc = 50; Kp_i = 20; Ki_i = 500;' newline ...
    'L = 5e-3; Vdc = 750; w = 2*pi*50;' newline ...
    'va=Vabc(1); ia=Iabc(1);' newline ...
    'Vdc_ref = 750;' newline ...
    'err_vdc = Vdc_ref - Vdc_meas;' newline ...
    'int_vdc = int_vdc + Ki_vdc*err_vdc*Ts;' newline ...
    'id_ref = Kp_vdc*err_vdc + int_vdc;' newline ...
    'id_ref = min(max(id_ref, 100), -100);' newline ...
    'id = ia; iq = 0;' newline ...
    'err_d = id_ref - id;' newline ...
    'int_d = int_d + Ki_i*err_d*Ts;' newline ...
    'ud = Kp_i*err_d + int_d - w*L*iq + va;' newline ...
    'da = 0.5 + ud/Vdc;' newline ...
    'db = 0.5 - 0.5*ud/Vdc;' newline ...
    'dc = 0.5 - 0.5*ud/Vdc;' newline ...
    'da=min(max(da,0.05),0.95);' newline ...
    'db=min(max(db,0.05),0.95);' newline ...
    'dc=min(max(dc,0.05),0.95);' newline ...
    'end']);

% Wiring
add_line(sys, 'V_abc/1', 'PLL/1', 'autorouting', 'on');
add_line(sys, 'PLL/1', 'GFL_Control/4', 'autorouting', 'on');
add_line(sys, 'V_abc/1', 'GFL_Control/1', 'autorouting', 'on');
add_line(sys, 'I_abc/1', 'GFL_Control/2', 'autorouting', 'on');
add_line(sys, 'Vdc_meas/1', 'GFL_Control/3', 'autorouting', 'on');

add_line(sys, 'GFL_Control/1', 'Duty_a/1', 'autorouting', 'on');
add_line(sys, 'GFL_Control/2', 'Duty_b/1', 'autorouting', 'on');
add_line(sys, 'GFL_Control/3', 'Duty_c/1', 'autorouting', 'on');

end

%% Helper to set MATLAB Function script
function set_ml_fcn_switching(sys, block_name, code)
blk_path = [sys '/' block_name];
sf = sfroot();
chart = find(sf, '-isa', 'Stateflow.EMChart', 'Path', blk_path);
if ~isempty(chart)
    chart.Script = code;
end
end
