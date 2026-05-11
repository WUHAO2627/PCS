%% Build Multi-Inverter Droop Parallel Simulink Model
% Multi-inverter parallel droop control simulation.
% 3 inverters in parallel operation, observe power sharing.

function build_droop_parallel_model()

model_name = 'droop_parallel_sim';

if bdIsLoaded(model_name)
    close_system(model_name, 0);
end
new_system(model_name);
open_system(model_name);

%% Simulation parameters
set_param(model_name, 'StopTime', '3');
set_param(model_name, 'Solver', 'ode23tb');
set_param(model_name, 'MaxStep', '1e-5');

%% Powergui
add_block('powerlib/powergui', [model_name '/powergui']);
set_param([model_name '/powergui'], 'SimulationMode', 'Discrete');
set_param([model_name '/powergui'], 'SampleTime', '5e-6');

%% ===== Inverter 1 (100kVA) =====
add_block('simulink/Ports & Subsystems/Subsystem', [model_name '/INV1']);
inv1 = [model_name '/INV1'];

% Inverter 2 (100kVA)
add_block('simulink/Ports & Subsystems/Subsystem', [model_name '/INV2']);
inv2 = [model_name '/INV2'];

% Inverter 3 (50kVA)
add_block('simulink/Ports & Subsystems/Subsystem', [model_name '/INV3']);
inv3 = [model_name '/INV3'];

%% ===== Line impedances (model different cable lengths) =====
add_block('powerlib/Elements/Three-Phase Series RLC Branch', [model_name '/Zline1']);
set_param([model_name '/Zline1'], 'BranchType', 'RL');
set_param([model_name '/Zline1'], 'Resistance', '[0.05 0.05 0.05]');
set_param([model_name '/Zline1'], 'Inductance', '[0.5e-3 0.5e-3 0.5e-3]');

add_block('powerlib/Elements/Three-Phase Series RLC Branch', [model_name '/Zline2']);
set_param([model_name '/Zline2'], 'BranchType', 'RL');
set_param([model_name '/Zline2'], 'Resistance', '[0.1 0.1 0.1]');
set_param([model_name '/Zline2'], 'Inductance', '[1e-3 1e-3 1e-3]');

add_block('powerlib/Elements/Three-Phase Series RLC Branch', [model_name '/Zline3']);
set_param([model_name '/Zline3'], 'BranchType', 'RL');
set_param([model_name '/Zline3'], 'Resistance', '[0.15 0.15 0.15]');
set_param([model_name '/Zline3'], 'Inductance', '[1.5e-3 1.5e-3 1.5e-3]');

%% ===== Common bus (PCC) =====
add_block('powerlib/Elements/Three-Phase Series RLC Load', [model_name '/Load_PCC']);
set_param([model_name '/Load_PCC'], 'NominalVoltage', '380');
set_param([model_name '/Load_PCC'], 'ActivePower', '150000');
set_param([model_name '/Load_PCC'], 'InductivePower', '30000');

%% ===== Load step =====
add_block('powerlib/Elements/Three-Phase Series RLC Load', [model_name '/Load_Step']);
set_param([model_name '/Load_Step'], 'NominalVoltage', '380');
set_param([model_name '/Load_Step'], 'ActivePower', '50000');

% Breaker-controlled load switching
add_block('powerlib/Elements/Three-Phase Breaker', [model_name '/Breaker']);
set_param([model_name '/Breaker'], 'SwitchingTimes', '[1.5 10]');

%% ===== Droop controllers (inside each inverter) =====
% Parameter assignment
% INV1: mp1 = 0.5/100e3 = 5e-6 Hz/W, nq1 = 10/100e3 = 1e-4 V/Var
% INV2: mp2 = 5e-6 Hz/W
% INV3: mp3 = 0.5/50e3 = 1e-5 Hz/W (smaller capacity, larger droop)

%% ===== Measurement =====
add_block('powerlib/Measurements/Three-Phase V-I Measurement', ...
    [model_name '/VI_meas_1']);
add_block('powerlib/Measurements/Three-Phase V-I Measurement', ...
    [model_name '/VI_meas_2']);
add_block('powerlib/Measurements/Three-Phase V-I Measurement', ...
    [model_name '/VI_meas_3']);

%% ===== Power calculation =====
add_block('simulink/Ports & Subsystems/Subsystem', [model_name '/Power_Calc']);

%% ===== Scopes =====
add_block('simulink/Sinks/Scope', [model_name '/Scope_P']);
set_param([model_name '/Scope_P'], 'NumInputPorts', '3');

add_block('simulink/Sinks/Scope', [model_name '/Scope_Q']);
set_param([model_name '/Scope_Q'], 'NumInputPorts', '3');

add_block('simulink/Sinks/Scope', [model_name '/Scope_Freq']);
add_block('simulink/Sinks/Scope', [model_name '/Scope_Vpcc']);

%% Save
save_system(model_name);
fprintf('Multi-inverter droop parallel model "%s" created.\n', model_name);
fprintf('3 inverters: 100kVA + 100kVA + 50kVA\n');
fprintf('50kW load step at t=1.5s, observe power redistribution.\n');
fprintf('Expected: INV1:INV2:INV3 output ratio = 2:2:1\n');

end
