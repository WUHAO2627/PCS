%% Build VSG (Virtual Synchronous Generator) Simulink Model
% Auto-build script for VSG simulation model.
% Contains: Swing equation, excitation control, V/I dual-loop, load step response

function build_vsg_model()

model_name = 'vsg_simulation';

if bdIsLoaded(model_name)
    close_system(model_name, 0);
end
new_system(model_name);
open_system(model_name);

%% Simulation parameters
set_param(model_name, 'StopTime', '2');
set_param(model_name, 'Solver', 'ode23tb');
set_param(model_name, 'MaxStep', '1e-5');

%% Powergui
add_block('powerlib/powergui', [model_name '/powergui']);
set_param([model_name '/powergui'], 'SimulationMode', 'Discrete');
set_param([model_name '/powergui'], 'SampleTime', '5e-6');

%% ===== Power stage =====
% DC source (models storage/PV)
add_block('powerlib/Electrical Sources/DC Voltage Source', ...
    [model_name '/Vdc_Source']);
set_param([model_name '/Vdc_Source'], 'Amplitude', '800');

% Three-phase inverter bridge
add_block('powerlib/Power Electronics/Universal Bridge', ...
    [model_name '/VSG_Inverter']);
set_param([model_name '/VSG_Inverter'], 'Arms', '3');
set_param([model_name '/VSG_Inverter'], 'Device', 'IGBT / Diodes');

% LC filter
add_block('powerlib/Elements/Three-Phase Series RLC Branch', ...
    [model_name '/Lf']);
set_param([model_name '/Lf'], 'BranchType', 'RL');
set_param([model_name '/Lf'], 'Resistance', '[0.1 0.1 0.1]');
set_param([model_name '/Lf'], 'Inductance', '[3e-3 3e-3 3e-3]');

add_block('powerlib/Elements/Three-Phase Series RLC Branch', ...
    [model_name '/Cf']);
set_param([model_name '/Cf'], 'BranchType', 'C');
set_param([model_name '/Cf'], 'Capacitance', '[20e-6 20e-6 20e-6]');

% Load (RLC)
add_block('powerlib/Elements/Three-Phase Series RLC Load', ...
    [model_name '/Load']);
set_param([model_name '/Load'], 'NominalVoltage', '380');
set_param([model_name '/Load'], 'ActivePower', '50000');
set_param([model_name '/Load'], 'InductivePower', '10000');

%% ===== VSG Control Subsystem =====
add_block('simulink/Ports & Subsystems/Subsystem', ...
    [model_name '/VSG_Controller']);

% Add core modules inside subsystem
ctrl_path = [model_name '/VSG_Controller'];

% Delete default connection
delete_line(ctrl_path, 'In1/1', 'Out1/1');

% Swing equation subsystem
add_block('simulink/Ports & Subsystems/Subsystem', ...
    [ctrl_path '/Swing_Equation']);

% Excitation control
add_block('simulink/Ports & Subsystems/Subsystem', ...
    [ctrl_path '/Excitation']);

% abc-dq transform
add_block('simulink/Math Operations/MATLAB Function', ...
    [ctrl_path '/Park_Transform']);

% PI controllers
add_block('simulink/Continuous/PID Controller', ...
    [ctrl_path '/PI_Id']);
set_param([ctrl_path '/PI_Id'], 'P', '15');
set_param([ctrl_path '/PI_Id'], 'I', '200');
set_param([ctrl_path '/PI_Id'], 'D', '0');

add_block('simulink/Continuous/PID Controller', ...
    [ctrl_path '/PI_Iq']);
set_param([ctrl_path '/PI_Iq'], 'P', '15');
set_param([ctrl_path '/PI_Iq'], 'I', '200');
set_param([ctrl_path '/PI_Iq'], 'D', '0');

%% ===== Load step =====
add_block('simulink/Sources/Step', [model_name '/Load_Step']);
set_param([model_name '/Load_Step'], 'Time', '1.0');
set_param([model_name '/Load_Step'], 'After', '1');

%% ===== Scopes =====
add_block('simulink/Sinks/Scope', [model_name '/Scope_Frequency']);
set_param([model_name '/Scope_Frequency'], 'NumInputPorts', '1');

add_block('simulink/Sinks/Scope', [model_name '/Scope_Voltage']);
add_block('simulink/Sinks/Scope', [model_name '/Scope_Power']);
add_block('simulink/Sinks/Scope', [model_name '/Scope_Current']);

%% Save
save_system(model_name);
fprintf('VSG simulation model "%s" created.\n', model_name);
fprintf('Key parameters: J=0.5 kg*m^2, D=50 N*m*s/rad\n');
fprintf('Observe frequency response (inertia support) during load step.\n');

end
