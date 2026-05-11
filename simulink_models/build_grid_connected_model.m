%% Build Grid-Connected Inverter Simulink Model
% Run this script to auto-create a Simulink simulation model.
% Contains: 3-phase inverter bridge, LCL filter, PLL, dual-loop control, grid model

function build_grid_connected_model()

model_name = 'grid_connected_inverter_sim';

% Close existing model if loaded
if bdIsLoaded(model_name)
    close_system(model_name, 0);
end
new_system(model_name);
open_system(model_name);

%% Simulation parameters
set_param(model_name, 'StopTime', '0.5');
set_param(model_name, 'Solver', 'ode23tb');
set_param(model_name, 'MaxStep', '1e-5');

%% Add Powergui
add_block('powerlib/powergui', [model_name '/powergui']);
set_param([model_name '/powergui'], 'SimulationMode', 'Discrete');
set_param([model_name '/powergui'], 'SampleTime', '5e-6');

%% ===== Power circuit =====
% DC voltage source
add_block('powerlib/Electrical Sources/DC Voltage Source', ...
    [model_name '/Vdc']);
set_param([model_name '/Vdc'], 'Amplitude', '700');

% Three-phase inverter bridge (Universal Bridge)
add_block('powerlib/Power Electronics/Universal Bridge', ...
    [model_name '/Inverter']);
set_param([model_name '/Inverter'], 'Arms', '3');
set_param([model_name '/Inverter'], 'Device', 'IGBT / Diodes');

% LCL filter
% Inverter-side inductor L1
add_block('powerlib/Elements/Series RLC Branch', ...
    [model_name '/L1']);
set_param([model_name '/L1'], 'BranchType', 'RL');
set_param([model_name '/L1'], 'Resistance', '0.1');
set_param([model_name '/L1'], 'Inductance', '3e-3');

% Filter capacitor C
add_block('powerlib/Elements/Series RLC Branch', ...
    [model_name '/Cf']);
set_param([model_name '/Cf'], 'BranchType', 'C');
set_param([model_name '/Cf'], 'Capacitance', '10e-6');

% Grid-side inductor L2
add_block('powerlib/Elements/Series RLC Branch', ...
    [model_name '/L2']);
set_param([model_name '/L2'], 'BranchType', 'RL');
set_param([model_name '/L2'], 'Resistance', '0.05');
set_param([model_name '/L2'], 'Inductance', '1e-3');

% Three-phase grid voltage source
add_block('powerlib/Electrical Sources/Three-Phase Source', ...
    [model_name '/Grid']);
set_param([model_name '/Grid'], 'Voltage', '380');
set_param([model_name '/Grid'], 'Frequency', '50');
set_param([model_name '/Grid'], 'PhaseAngle', '0');

%% ===== Measurement =====
% Current measurement
add_block('powerlib/Measurements/Current Measurement', ...
    [model_name '/Ia_meas']);

% Voltage measurement (PCC)
add_block('powerlib/Measurements/Voltage Measurement', ...
    [model_name '/Vpcc_meas']);

%% ===== Control system =====
% PLL
add_block('simulink/Math Operations/MATLAB Function', ...
    [model_name '/PLL_Control']);

% Add control subsystem
add_block('simulink/Ports & Subsystems/Subsystem', ...
    [model_name '/Controller']);

% Scope
add_block('simulink/Sinks/Scope', [model_name '/Scope_Power']);
add_block('simulink/Sinks/Scope', [model_name '/Scope_Current']);
add_block('simulink/Sinks/Scope', [model_name '/Scope_Vdc']);

%% Save
save_system(model_name);
fprintf('Model "%s" created successfully.\n', model_name);
fprintf('Please wire and configure the control subsystem internals.\n');

end
