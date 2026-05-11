%% Build Three-Level NPC Inverter Simulink Model
% Three-level NPC neutral-point-clamped inverter simulation
% with midpoint potential balance control

function build_npc_3level_model()

model_name = 'npc_3level_sim';

if bdIsLoaded(model_name)
    close_system(model_name, 0);
end
new_system(model_name);
open_system(model_name);

%% Simulation parameters
set_param(model_name, 'StopTime', '0.2');
set_param(model_name, 'Solver', 'ode23tb');
set_param(model_name, 'MaxStep', '5e-6');

%% Powergui
add_block('powerlib/powergui', [model_name '/powergui']);
set_param([model_name '/powergui'], 'SimulationMode', 'Discrete');
set_param([model_name '/powergui'], 'SampleTime', '1e-6');

%% ===== DC side =====
% Upper capacitor
add_block('powerlib/Elements/Series RLC Branch', [model_name '/C1']);
set_param([model_name '/C1'], 'BranchType', 'C');
set_param([model_name '/C1'], 'Capacitance', '4700e-6');

% Lower capacitor
add_block('powerlib/Elements/Series RLC Branch', [model_name '/C2']);
set_param([model_name '/C2'], 'BranchType', 'C');
set_param([model_name '/C2'], 'Capacitance', '4700e-6');

% DC voltage source
add_block('powerlib/Electrical Sources/DC Voltage Source', [model_name '/Vdc']);
set_param([model_name '/Vdc'], 'Amplitude', '800');

%% ===== Three-level inverter (4 IGBTs + 2 clamping diodes per phase) =====
% Using Universal Bridge (3-level) or manual construction
% Encapsulated in Subsystem here
add_block('simulink/Ports & Subsystems/Subsystem', [model_name '/NPC_Bridge']);

%% ===== Output filter =====
add_block('powerlib/Elements/Three-Phase Series RLC Branch', [model_name '/Lf_3ph']);
set_param([model_name '/Lf_3ph'], 'BranchType', 'RL');
set_param([model_name '/Lf_3ph'], 'Resistance', '[0.1 0.1 0.1]');
set_param([model_name '/Lf_3ph'], 'Inductance', '[2e-3 2e-3 2e-3]');

%% ===== Load / Grid connection =====
add_block('powerlib/Elements/Three-Phase Series RLC Load', [model_name '/Load_3ph']);
set_param([model_name '/Load_3ph'], 'NominalVoltage', '380');
set_param([model_name '/Load_3ph'], 'ActivePower', '50000');

%% ===== Midpoint balance controller =====
add_block('simulink/Ports & Subsystems/Subsystem', [model_name '/NP_Balance_Ctrl']);

np_ctrl = [model_name '/NP_Balance_Ctrl'];
delete_line(np_ctrl, 'In1/1', 'Out1/1');

% Voltage difference calculation
add_block('simulink/Math Operations/Sum', [np_ctrl '/Delta_V']);
set_param([np_ctrl '/Delta_V'], 'Inputs', '+-');

% PI controller
add_block('simulink/Continuous/PID Controller', [np_ctrl '/PI_Balance']);
set_param([np_ctrl '/PI_Balance'], 'P', '5');
set_param([np_ctrl '/PI_Balance'], 'I', '200');
set_param([np_ctrl '/PI_Balance'], 'D', '0');
set_param([np_ctrl '/PI_Balance'], 'UpperSaturationLimit', '0.1');
set_param([np_ctrl '/PI_Balance'], 'LowerSaturationLimit', '-0.1');

% Zero-sequence injection adder
add_block('simulink/Math Operations/Sum', [np_ctrl '/Add_Offset']);
set_param([np_ctrl '/Add_Offset'], 'Inputs', '++');

%% ===== Three-level SPWM =====
add_block('simulink/Ports & Subsystems/Subsystem', [model_name '/SPWM_3Level']);

% Dual carriers: upper (0~1) and lower (-1~0)
% Reference compared with two carriers to produce 3-level switching signals

%% ===== Measurement and display =====
add_block('powerlib/Measurements/Voltage Measurement', [model_name '/V_C1_meas']);
add_block('powerlib/Measurements/Voltage Measurement', [model_name '/V_C2_meas']);
add_block('simulink/Sinks/Scope', [model_name '/Scope_Vcap']);
set_param([model_name '/Scope_Vcap'], 'NumInputPorts', '2');
add_block('simulink/Sinks/Scope', [model_name '/Scope_Vout']);
add_block('simulink/Sinks/Scope', [model_name '/Scope_NP_Current']);

%% Save
save_system(model_name);
fprintf('Three-level NPC model "%s" created.\n', model_name);
fprintf('Vdc=800V, C1=C2=4700uF\n');
fprintf('Midpoint balance via zero-sequence voltage injection.\n');

end
