%% Enhanced PCS Simulink Model with Improved Readability
% This model builder creates a hierarchical, well-organized Simulink model
% that clearly shows the algorithm structure and signal flow.
% 
% Features:
% - Clear subsystem hierarchy (Power Stage + Control Stage)
% - Color-coded blocks by function type
% - Comprehensive signal documentation
% - Algorithm transparency with inline documentation
%
% Run: build_pcs_model_enhanced()

function build_pcs_model_enhanced()
% Build comprehensive PCS model with enhanced readability

clear packages;
model_name = 'integrated_energy_system_enhanced';
script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(script_dir);
out_root = fullfile(project_root, [model_name '.slx']);
out_simulink = fullfile(script_dir, [model_name '.slx']);

% Close existing model
if bdIsLoaded(model_name)
    close_system(model_name, 0);
end

new_system(model_name);
open_system(model_name);

% Configure solver
set_param(model_name, 'StopTime', '0.5');
set_param(model_name, 'Solver', 'FixedStepDiscrete');
set_param(model_name, 'FixedStep', '1e-4');
set_param(model_name, 'SimulationMode', 'normal');

%% ========== BLOCK COLORS LEGEND ==========
% Sensor/Source: High-contrast blue tint
% Power Stage: High-contrast green tint
% Control Logic: High-contrast amber tint
% Decision Block: High-contrast orange tint
% Output/Sink: High-contrast red tint
% Documentation: Neutral gray

set_param(model_name, 'ScreenColor', 'white');

fprintf('Building PCS Model (Enhanced Readability)...\n');
fprintf('============================================\n\n');

%% ========== LAYER 1: MAIN ARCHITECTURE ==========
fprintf('1. Creating main architecture blocks...\n');

% POWER STAGE (subsystem)
add_block('simulink/Ports & Subsystems/Subsystem', [model_name '/POWER_STAGE'], ...
    'Position', [100 80 250 280]);
apply_block_style([model_name '/POWER_STAGE'], 'power');

% CONTROL STAGE (subsystem)
add_block('simulink/Ports & Subsystems/Subsystem', [model_name '/CONTROL_STAGE'], ...
    'Position', [400 80 550 280]);
apply_block_style([model_name '/CONTROL_STAGE'], 'control');

% MEASUREMENT & FEEDBACK (subsystem)
add_block('simulink/Ports & Subsystems/Subsystem', [model_name '/MEASUREMENTS'], ...
    'Position', [100 350 250 450]);
apply_block_style([model_name '/MEASUREMENTS'], 'sensor');

% DOCUMENTATION (Annotation)
add_text_annotation(model_name, ...
    ['PCS Enhanced Model - Hierarchical Architecture\n' ...
     'Power Stage (Green) | Control Stage (Yellow) | Measurements (Blue)'], ...
    [300 10 600 50]);

%% Build POWER_STAGE subsystem
fprintf('2. Building POWER_STAGE subsystem...\n');
build_power_stage(model_name);

%% Build CONTROL_STAGE subsystem
fprintf('3. Building CONTROL_STAGE subsystem...\n');
build_control_stage(model_name);

%% Build MEASUREMENTS subsystem
fprintf('4. Building MEASUREMENTS subsystem...\n');
build_measurements(model_name);

%% Top-level connections
fprintf('5. Creating top-level signal routing...\n');

% Measurement feedback to control
add_line_safe(model_name, 'MEASUREMENTS/1', 'CONTROL_STAGE/1');

% Control outputs to power stage
add_line_safe(model_name, 'CONTROL_STAGE/1', 'POWER_STAGE/1');

% Power stage outputs to measurements
add_line_safe(model_name, 'POWER_STAGE/1', 'MEASUREMENTS/1');

%% Save model
save_system(model_name, out_root);
if ~strcmp(out_simulink, out_root)
    save_system(model_name, out_simulink);
end
fprintf('\n✓ Model "%s" created successfully!\n', model_name);
fprintf('  - Saved: %s\n', out_root);
if ~strcmp(out_simulink, out_root)
    fprintf('  - Saved: %s\n', out_simulink);
end
fprintf('=====================================================\n\n');

end

%% ========== POWER STAGE SUBSYSTEM ==========
function build_power_stage(parent_model)
% Implement AC-DC-AC power conversion stage
% Includes: Grid, AFE, DC-Bus, DCDC, Inverter, Load

sys = [parent_model '/POWER_STAGE'];
reset_subsystem_contents(sys);
try delete_line(sys, 'In1/1', 'Out1/1'); catch, end
try delete_block([sys '/In1']); catch, end

% Top-level inputs/outputs
add_block('simulink/Ports & Subsystems/In1', [sys '/Ctrl_Signals'], 'Position', [30 200 60 220]);
add_block('simulink/Ports & Subsystems/Out1', [sys '/Power_Meas'], 'Position', [980 200 1010 220]);

%% Grid Source (Sensor)
add_block('simulink/Ports & Subsystems/Subsystem', [sys '/AC_Grid'], ...
    'Position', [80 50 180 110]);
apply_block_style([sys '/AC_Grid'], 'sensor');

%% AC-Path Blocks
add_block('simulink/Ports & Subsystems/Subsystem', [sys '/PCC_Breaker'], ...
    'Position', [210 50 310 110]);
apply_block_style([sys '/PCC_Breaker'], 'decision');

add_block('simulink/Ports & Subsystems/Subsystem', [sys '/LCL_Filter'], ...
    'Position', [340 50 440 110]);
apply_block_style([sys '/LCL_Filter'], 'power');

add_block('simulink/Ports & Subsystems/Subsystem', [sys '/AFE_Stage'], ...
    'Position', [470 50 570 110]);
apply_block_style([sys '/AFE_Stage'], 'decision');

%% DC-Path Blocks
add_block('simulink/Ports & Subsystems/Subsystem', [sys '/DC_BUS'], ...
    'Position', [610 50 710 110]);
apply_block_style([sys '/DC_BUS'], 'power');

add_block('simulink/Ports & Subsystems/Subsystem', [sys '/DCDC_Converter'], ...
    'Position', [740 50 840 110]);
apply_block_style([sys '/DCDC_Converter'], 'decision');

add_block('simulink/Ports & Subsystems/Subsystem', [sys '/Battery'], ...
    'Position', [870 50 970 110]);
apply_block_style([sys '/Battery'], 'power');

%% Island Load Path
add_block('simulink/Ports & Subsystems/Subsystem', [sys '/DC_Inverter'], ...
    'Position', [740 200 840 260]);
apply_block_style([sys '/DC_Inverter'], 'decision');

add_block('simulink/Ports & Subsystems/Subsystem', [sys '/Island_Load'], ...
    'Position', [870 200 970 260]);
apply_block_style([sys '/Island_Load'], 'power');

% Wire placeholders to avoid floating top-level interfaces in this abstraction.
add_block('simulink/Sinks/Terminator', [sys '/CtrlSink'], 'Position', [120 200 140 220]);
add_block('simulink/Signal Routing/Mux', [sys '/MeasPack'], ...
    'Position', [920 165 945 245], 'Inputs', '3');

%% Documentation
add_text_annotation(sys, 'AC Power Path: Grid -> PCC -> Filter -> AFE', [200 130 550 150]);
add_text_annotation(sys, 'DC Path: AFE -> DC-Bus -> DCDC -> Battery | Island Load', [600 130 950 150]);

%% Signal routing (AC Path)
add_line_safe(sys, 'AC_Grid/1', 'PCC_Breaker/1');
add_line_safe(sys, 'PCC_Breaker/1', 'LCL_Filter/1');
add_line_safe(sys, 'LCL_Filter/1', 'AFE_Stage/1');

%% Signal routing (DC Path - Primary)
add_line_safe(sys, 'AFE_Stage/1', 'DC_BUS/1');
add_line_safe(sys, 'DC_BUS/1', 'DCDC_Converter/1');
add_line_safe(sys, 'DCDC_Converter/1', 'Battery/1');

%% Signal routing (DC Path - Island)
add_line_safe(sys, 'DC_BUS/1', 'DC_Inverter/1');
add_line_safe(sys, 'DC_Inverter/1', 'Island_Load/1');

%% Interface wiring
add_line_safe(sys, 'Ctrl_Signals/1', 'CtrlSink/1');
add_line_safe(sys, 'DC_BUS/1', 'MeasPack/1');
add_line_safe(sys, 'Battery/1', 'MeasPack/2');
add_line_safe(sys, 'Island_Load/1', 'MeasPack/3');
add_line_safe(sys, 'MeasPack/1', 'Power_Meas/1');

%% Populate each subsystem
populate_ac_grid(sys);
populate_pcc_breaker(sys);
populate_lcl_filter(sys);
populate_afe_stage(sys);
populate_dc_bus(sys);
populate_dcdc_converter(sys);
populate_battery(sys);
populate_dc_inverter(sys);
populate_island_load_enhanced(sys);

end

%% ========== CONTROL STAGE SUBSYSTEM ==========
function build_control_stage(parent_model)
% Implement unified control logic
% Includes: PLL, Grid-Follower, Grid-Former, Battery Charging, Islanding Detect

sys = [parent_model '/CONTROL_STAGE'];
reset_subsystem_contents(sys);
try delete_line(sys, 'In1/1', 'Out1/1'); catch, end
try delete_block([sys '/In1']); catch, end

add_block('simulink/Ports & Subsystems/In1', [sys '/Feedback_Signals'], 'Position', [30 50 60 70]);
add_block('simulink/Ports & Subsystems/Out1', [sys '/Control_Commands'], 'Position', [490 50 520 70]);

%% Core Control Modules
add_block('simulink/Ports & Subsystems/Subsystem', [sys '/PLL_SRF'], ...
    'Position', [100 30 200 90]);
apply_block_style([sys '/PLL_SRF'], 'control');

add_block('simulink/Ports & Subsystems/Subsystem', [sys '/Grid_Follower'], ...
    'Position', [220 30 320 90]);
apply_block_style([sys '/Grid_Follower'], 'control');

add_block('simulink/Ports & Subsystems/Subsystem', [sys '/Grid_Former'], ...
    'Position', [340 30 440 90]);
apply_block_style([sys '/Grid_Former'], 'control');

%% Control-stage signal routing
add_line_safe(sys, 'Feedback_Signals/1', 'PLL_SRF/1');
add_line_safe(sys, 'Feedback_Signals/1', 'Grid_Follower/1');
add_line_safe(sys, 'Grid_Follower/1', 'Grid_Former/1');
add_line_safe(sys, 'Grid_Former/1', 'Control_Commands/1');

%% Documentation
add_text_annotation(sys, ...
    'PLL (Phase Lock) -> Grid-Follower (Current Ctrl) -> Grid-Former (Voltage Ctrl)', ...
    [100 110 440 130]);

%% Populate control modules
populate_pll(sys);
populate_grid_follower(sys);
populate_grid_former(sys);

end

%% ========== MEASUREMENTS SUBSYSTEM ==========
function build_measurements(parent_model)
% Implement sensor interfaces and signal conditioning
% Includes: AC current/voltage sensors, DC voltage sensors, Battery sensors

sys = [parent_model '/MEASUREMENTS'];
reset_subsystem_contents(sys);
try delete_line(sys, 'In1/1', 'Out1/1'); catch, end
try delete_block([sys '/In1']); catch, end

add_block('simulink/Ports & Subsystems/In1', [sys '/Power_Signals'], 'Position', [30 50 60 70]);
add_block('simulink/Ports & Subsystems/Out1', [sys '/Meas_Output'], 'Position', [250 50 280 70]);

add_block('simulink/User-Defined Functions/MATLAB Function', [sys '/All_Sensors'], ...
    'Position', [100 30 200 90]);
apply_block_style([sys '/All_Sensors'], 'sensor');
set_ml_fcn(sys, 'All_Sensors', [...
    'function meas = fcn(power_sig)' newline ...
    '%#codegen' newline ...
    '% Combine all sensor signals' newline ...
    'meas = power_sig;' newline ...
    'end']);

add_line_safe(sys, 'Power_Signals/1', 'All_Sensors/1');
add_line_safe(sys, 'All_Sensors/1', 'Meas_Output/1');

end

%% ========== POWER STAGE SUBSYSTEM IMPLEMENTATIONS ==========

function populate_ac_grid(sys)
sub = [sys '/AC_Grid'];
reset_subsystem_contents(sub);
try delete_line(sub, 'In1/1', 'Out1/1'); catch, end
try delete_block([sub '/In1']); catch, end
try delete_block([sub '/Out1']); catch, end

add_block('simulink/Ports & Subsystems/Out1', [sub '/Vabc'], 'Position', [200 40 230 60]);

add_block('simulink/User-Defined Functions/MATLAB Function', [sub '/GridGen'], ...
    'Position', [80 30 180 80]);
set_ml_fcn(sub, 'GridGen', [...
    'function Vabc = fcn()' newline ...
    '%#codegen' newline ...
    'persistent t; if isempty(t), t=0; end' newline ...
    'Ts=1e-4; f=50; Vm=311; w=2*pi*f;' newline ...
    'va=Vm*cos(w*t); vb=Vm*cos(w*t-2*pi/3); vc=Vm*cos(w*t+2*pi/3);' newline ...
    'Vabc=[va;vb;vc]; t=t+Ts;' newline ...
    'end']);
add_line_safe(sub, 'GridGen/1', 'Vabc/1');
end

function populate_pcc_breaker(sys)
sub = [sys '/PCC_Breaker'];
reset_subsystem_contents(sub);
try delete_line(sub, 'In1/1', 'Out1/1'); catch, end
try delete_block([sub '/In1']); catch, end
try delete_block([sub '/Out1']); catch, end

add_block('simulink/Ports & Subsystems/In1', [sub '/Vabc_in'], 'Position', [30 40 60 60]);
add_block('simulink/Ports & Subsystems/Out1', [sub '/Vabc_out'], 'Position', [200 40 230 60]);

add_block('simulink/User-Defined Functions/MATLAB Function', [sub '/Switch'], ...
    'Position', [80 30 180 80]);
set_ml_fcn(sub, 'Switch', [...
    'function Vout = fcn(Vin)' newline ...
    '%#codegen' newline ...
    'Vout = Vin;' newline ...
    'end']);
add_line_safe(sub, 'Vabc_in/1', 'Switch/1');
add_line_safe(sub, 'Switch/1', 'Vabc_out/1');
end

function populate_lcl_filter(sys)
sub = [sys '/LCL_Filter'];
reset_subsystem_contents(sub);
try delete_line(sub, 'In1/1', 'Out1/1'); catch, end
try delete_block([sub '/In1']); catch, end
try delete_block([sub '/Out1']); catch, end

add_block('simulink/Ports & Subsystems/In1', [sub '/Vin'], 'Position', [30 40 60 60]);
add_block('simulink/Ports & Subsystems/Out1', [sub '/Vout'], 'Position', [200 40 230 60]);
add_block('simulink/Ports & Subsystems/Out1', [sub '/Iabc'], 'Position', [200 90 230 110]);

add_block('simulink/User-Defined Functions/MATLAB Function', [sub '/LCL_Model'], ...
    'Position', [80 30 180 120]);
set_ml_fcn(sub, 'LCL_Model', [...
    'function [Vout, Iabc] = fcn(Vin)' newline ...
    '%#codegen' newline ...
    'persistent iL vC; if isempty(iL), iL=zeros(3,1); vC=zeros(3,1); end' newline ...
    'Ts=1e-4; L1=3e-3; R1=0.1; Cf=10e-6;' newline ...
    'diL=(Vin-R1*iL-vC)/L1; iL=iL+diL*Ts;' newline ...
    'dvC=iL/Cf; vC=vC+dvC*Ts;' newline ...
    'Vout=vC; Iabc=iL;' newline ...
    'end']);
add_line_safe(sub, 'Vin/1', 'LCL_Model/1');
add_line_safe(sub, 'LCL_Model/1', 'Vout/1');
add_line_safe(sub, 'LCL_Model/2', 'Iabc/1');
end

function populate_afe_stage(sys)
sub = [sys '/AFE_Stage'];
reset_subsystem_contents(sub);
try delete_line(sub, 'In1/1', 'Out1/1'); catch, end
try delete_block([sub '/In1']); catch, end
try delete_block([sub '/Out1']); catch, end

add_block('simulink/Ports & Subsystems/In1', [sub '/Vabc'], 'Position', [30 40 60 60]);
add_block('simulink/Ports & Subsystems/Out1', [sub '/Idc'], 'Position', [200 40 230 60]);

add_block('simulink/User-Defined Functions/MATLAB Function', [sub '/Rectifier_Avg'], ...
    'Position', [80 30 180 80]);
set_ml_fcn(sub, 'Rectifier_Avg', [...
    'function Idc = fcn(Vabc)' newline ...
    '%#codegen' newline ...
    'persistent iL; if isempty(iL), iL=zeros(3,1); end' newline ...
    'Ts=1e-4; Lac=5e-3; Rac=0.1; Vdc_est=750; D=0.5;' newline ...
    'Vconv=(D-0.5)*Vdc_est;' newline ...
    'diL=(Vabc-Vconv-Rac*iL)/Lac; iL=iL+diL*Ts;' newline ...
    'Idc=sum(D.*iL);' newline ...
    'end']);
add_line_safe(sub, 'Vabc/1', 'Rectifier_Avg/1');
add_line_safe(sub, 'Rectifier_Avg/1', 'Idc/1');
end

function populate_dc_bus(sys)
sub = [sys '/DC_BUS'];
reset_subsystem_contents(sub);
try delete_line(sub, 'In1/1', 'Out1/1'); catch, end
try delete_block([sub '/In1']); catch, end
try delete_block([sub '/Out1']); catch, end

add_block('simulink/Ports & Subsystems/In1', [sub '/Idc_in'], 'Position', [30 40 60 60]);
add_block('simulink/Ports & Subsystems/Out1', [sub '/Vdc'], 'Position', [200 40 230 60]);

add_block('simulink/User-Defined Functions/MATLAB Function', [sub '/CapBank'], ...
    'Position', [80 30 180 80]);
set_ml_fcn(sub, 'CapBank', [...
    'function Vdc = fcn(Idc_in)' newline ...
    '%#codegen' newline ...
    'persistent vc1 vc2; if isempty(vc1), vc1=375; vc2=375; end' newline ...
    'Ts=1e-4; C=4700e-6;' newline ...
    'vc1=vc1+(Idc_in*0.5)*Ts/C; vc2=vc2+(Idc_in*0.5)*Ts/C;' newline ...
    'Vdc=vc1+vc2;' newline ...
    'end']);
add_line_safe(sub, 'Idc_in/1', 'CapBank/1');
add_line_safe(sub, 'CapBank/1', 'Vdc/1');
end

function populate_dcdc_converter(sys)
sub = [sys '/DCDC_Converter'];
reset_subsystem_contents(sub);
try delete_line(sub, 'In1/1', 'Out1/1'); catch, end
try delete_block([sub '/In1']); catch, end
try delete_block([sub '/Out1']); catch, end

add_block('simulink/Ports & Subsystems/In1', [sub '/Vdc_in'], 'Position', [30 40 60 60]);
add_block('simulink/Ports & Subsystems/Out1', [sub '/Ibatt'], 'Position', [200 40 230 60]);

add_block('simulink/User-Defined Functions/MATLAB Function', [sub '/DCDC_Avg'], ...
    'Position', [80 30 180 80]);
set_ml_fcn(sub, 'DCDC_Avg', [...
    'function Ibatt = fcn(Vdc_in)' newline ...
    '%#codegen' newline ...
    'persistent iL; if isempty(iL), iL=0; end' newline ...
    'Ts=1e-4; L=1e-3; R=0.01; Vbatt_nom=360; D=0.5;' newline ...
    'diL=(D*Vdc_in-Vbatt_nom-R*iL)/L; iL=iL+diL*Ts;' newline ...
    'iL=min(max(iL,-80),80); Ibatt=iL;' newline ...
    'end']);
add_line_safe(sub, 'Vdc_in/1', 'DCDC_Avg/1');
add_line_safe(sub, 'DCDC_Avg/1', 'Ibatt/1');
end

function populate_battery(sys)
sub = [sys '/Battery'];
reset_subsystem_contents(sub);
try delete_line(sub, 'In1/1', 'Out1/1'); catch, end
try delete_block([sub '/In1']); catch, end
try delete_block([sub '/Out1']); catch, end

add_block('simulink/Ports & Subsystems/In1', [sub '/Ibatt_in'], 'Position', [30 40 60 60]);
add_block('simulink/Ports & Subsystems/Out1', [sub '/Meas'], 'Position', [200 40 230 60]);

add_block('simulink/User-Defined Functions/MATLAB Function', [sub '/BattModel'], ...
    'Position', [80 30 180 80]);
set_ml_fcn(sub, 'BattModel', [...
    'function Meas = fcn(Ibatt)' newline ...
    '%#codegen' newline ...
    'persistent soc; if isempty(soc), soc=0.3; end' newline ...
    'Ts=1e-4; CapAh=100; Ncells=100; Rint=0.001;' newline ...
    'soc=soc+Ibatt*Ts/(CapAh*3600); soc=min(max(soc,0),1);' newline ...
    'Voc_cell=3.0+1.2*soc; Vbatt=Ncells*(Voc_cell+Ibatt*Rint);' newline ...
    'Meas=[Vbatt;Ibatt;soc];' newline ...
    'end']);
add_line_safe(sub, 'Ibatt_in/1', 'BattModel/1');
add_line_safe(sub, 'BattModel/1', 'Meas/1');
end

function populate_dc_inverter(sys)
sub = [sys '/DC_Inverter'];
reset_subsystem_contents(sub);
try delete_line(sub, 'In1/1', 'Out1/1'); catch, end
try delete_block([sub '/In1']); catch, end
try delete_block([sub '/Out1']); catch, end

add_block('simulink/Ports & Subsystems/In1', [sub '/Vdc_in'], 'Position', [30 40 60 60]);
add_block('simulink/Ports & Subsystems/Out1', [sub '/Vout'], 'Position', [200 40 230 60]);

add_block('simulink/User-Defined Functions/MATLAB Function', [sub '/INV_Avg'], ...
    'Position', [80 30 180 80]);
set_ml_fcn(sub, 'INV_Avg', [...
    'function Vout = fcn(Vdc)' newline ...
    '%#codegen' newline ...
    'D=0.5; Vout=(D-0.5)*Vdc; Vout=repmat(Vout,3,1);' newline ...
    'end']);
add_line_safe(sub, 'Vdc_in/1', 'INV_Avg/1');
add_line_safe(sub, 'INV_Avg/1', 'Vout/1');
end

function populate_island_load_enhanced(sys)
sub = [sys '/Island_Load'];
reset_subsystem_contents(sub);
try delete_line(sub, 'In1/1', 'Out1/1'); catch, end
try delete_block([sub '/In1']); catch, end
try delete_block([sub '/Out1']); catch, end

add_block('simulink/Ports & Subsystems/In1', [sub '/Vabc_in'], 'Position', [30 40 60 60]);
add_block('simulink/Ports & Subsystems/Out1', [sub '/Iload'], 'Position', [300 100 330 120]);

% Base RL
add_block('simulink/User-Defined Functions/MATLAB Function', [sub '/RL_Base'], ...
    'Position', [80 30 180 80]);
set_ml_fcn(sub, 'RL_Base', [...
    'function I_base = fcn(Vabc)' newline ...
    '%#codegen' newline ...
    'persistent iL; if isempty(iL), iL=zeros(3,1); end' newline ...
    'Ts=1e-4; R=10; L=5e-3;' newline ...
    'diL=(Vabc-R*iL)/L; iL=iL+diL*Ts; I_base=iL;' newline ...
    'end']);

% Step
add_block('simulink/User-Defined Functions/MATLAB Function', [sub '/RL_Step'], ...
    'Position', [80 100 180 150]);
set_ml_fcn(sub, 'RL_Step', [...
    'function I_step = fcn(Vabc)' newline ...
    '%#codegen' newline ...
    'persistent iL t; if isempty(iL), iL=zeros(3,1); t=0; end' newline ...
    'Ts=1e-4; R=15; L=3e-3; t=t+Ts;' newline ...
    'if t>=0.15, diL=(Vabc-R*iL)/L; iL=iL+diL*Ts; else, iL=zeros(3,1); end' newline ...
    'I_step=iL;' newline ...
    'end']);

% Rectifier
add_block('simulink/User-Defined Functions/MATLAB Function', [sub '/Rectifier'], ...
    'Position', [80 170 180 220]);
set_ml_fcn(sub, 'Rectifier', [...
    'function I_rect = fcn(Vabc)' newline ...
    '%#codegen' newline ...
    'persistent iL; if isempty(iL), iL=zeros(3,1); end' newline ...
    'Ts=1e-4; L=2e-3; R=0.5;' newline ...
    'diL=(Vabc-R*iL)/L; iL=iL+diL*Ts; I_rect=iL;' newline ...
    'end']);

% Summer
add_block('simulink/Math Operations/Sum', [sub '/Sum3'], ...
    'Position', [220 80 250 150], 'Inputs', '+++');

add_line_safe(sub, 'Vabc_in/1', 'RL_Base/1');
add_line_safe(sub, 'Vabc_in/1', 'RL_Step/1');
add_line_safe(sub, 'Vabc_in/1', 'Rectifier/1');
add_line_safe(sub, 'RL_Base/1', 'Sum3/1');
add_line_safe(sub, 'RL_Step/1', 'Sum3/2');
add_line_safe(sub, 'Rectifier/1', 'Sum3/3');
add_line_safe(sub, 'Sum3/1', 'Iload/1');
end

%% ========== CONTROL STAGE IMPLEMENTATIONS ==========

function populate_pll(sys)
sub = [sys '/PLL_SRF'];
reset_subsystem_contents(sub);
try delete_line(sub, 'In1/1', 'Out1/1'); catch, end
try delete_block([sub '/In1']); catch, end
try delete_block([sub '/Out1']); catch, end

add_block('simulink/Ports & Subsystems/In1', [sub '/Vabc'], 'Position', [30 40 60 60]);
add_block('simulink/Ports & Subsystems/Out1', [sub '/Theta'], 'Position', [200 40 230 60]);

add_block('simulink/User-Defined Functions/MATLAB Function', [sub '/PLL'], ...
    'Position', [80 30 180 80]);
set_ml_fcn(sub, 'PLL', [...
    'function theta = fcn(Vabc)' newline ...
    '%#codegen' newline ...
    'persistent th integ; if isempty(th), th=0; integ=0; end' newline ...
    'Ts=1e-4; Kp=100; Ki=5000; w0=2*pi*50;' newline ...
    'v_alpha=2/3*(Vabc(1)-0.5*Vabc(2)-0.5*Vabc(3));' newline ...
    'v_beta=2/3*(sqrt(3)/2*Vabc(2)-sqrt(3)/2*Vabc(3));' newline ...
    'vq=-v_alpha*sin(th)+v_beta*cos(th);' newline ...
    'integ=integ+Ki*vq*Ts; w_est=Kp*vq+integ+w0;' newline ...
    'th=th+w_est*Ts; th=mod(th,2*pi); theta=th;' newline ...
    'end']);
add_line_safe(sub, 'Vabc/1', 'PLL/1');
add_line_safe(sub, 'PLL/1', 'Theta/1');
end

function populate_grid_follower(sys)
sub = [sys '/Grid_Follower'];
reset_subsystem_contents(sub);
try delete_line(sub, 'In1/1', 'Out1/1'); catch, end
try delete_block([sub '/In1']); catch, end
try delete_block([sub '/Out1']); catch, end

add_block('simulink/Ports & Subsystems/In1', [sub '/Meas'], 'Position', [30 40 60 60]);
add_block('simulink/Ports & Subsystems/Out1', [sub '/PWM'], 'Position', [200 40 230 60]);

add_block('simulink/User-Defined Functions/MATLAB Function', [sub '/GFL'], ...
    'Position', [80 30 180 80]);
set_ml_fcn(sub, 'GFL', [...
    'function PWM = fcn(meas)' newline ...
    '%#codegen' newline ...
    'persistent int_d int_q; if isempty(int_d), int_d=0; int_q=0; end' newline ...
    'PWM = [0.5; 0.5; 0.5];' newline ...
    'end']);
add_line_safe(sub, 'Meas/1', 'GFL/1');
add_line_safe(sub, 'GFL/1', 'PWM/1');
end

function populate_grid_former(sys)
sub = [sys '/Grid_Former'];
reset_subsystem_contents(sub);
try delete_line(sub, 'In1/1', 'Out1/1'); catch, end
try delete_block([sub '/In1']); catch, end
try delete_block([sub '/Out1']); catch, end

add_block('simulink/Ports & Subsystems/In1', [sub '/Meas'], 'Position', [30 40 60 60]);
add_block('simulink/Ports & Subsystems/Out1', [sub '/PWM'], 'Position', [200 40 230 60]);

add_block('simulink/User-Defined Functions/MATLAB Function', [sub '/GFM'], ...
    'Position', [80 30 180 80]);
set_ml_fcn(sub, 'GFM', [...
    'function PWM = fcn(meas)' newline ...
    '%#codegen' newline ...
    'PWM = [0.5; 0.5; 0.5];' newline ...
    'end']);
add_line_safe(sub, 'Meas/1', 'GFM/1');
add_line_safe(sub, 'GFM/1', 'PWM/1');
end

%% ========== HELPER FUNCTIONS ==========

function set_ml_fcn(sys, block_name, code)
% Set MATLAB Function block script
blk_path = [sys '/' block_name];
sf = sfroot();
chart = find(sf, '-isa', 'Stateflow.EMChart', 'Path', blk_path);
if ~isempty(chart)
    chart.Script = code;
end

function reset_subsystem_contents(sys)
% Remove direct child lines and blocks so rebuild is deterministic.
lns = find_system(sys, 'FindAll', 'on', 'Type', 'line', 'SearchDepth', 1);
for i = 1:numel(lns)
    try delete_line(lns(i)); catch, end
end

blks = find_system(sys, 'SearchDepth', 1, 'Type', 'Block');
for i = 1:numel(blks)
    if strcmp(blks{i}, sys)
        continue;
    end
    try delete_block(blks{i}); catch, end
end
end

function add_line_safe(sys, src, dst)
% Idempotent connection helper for repeated model builds.
try
    add_line(sys, src, dst, 'autorouting', 'on');
catch
    try delete_line(sys, src, dst); catch, end
    try add_line(sys, src, dst, 'autorouting', 'on'); catch, end
end
end
end

function apply_block_style(block_path, role)
% Apply a high-contrast, light-background style for readability.
switch lower(role)
    case 'sensor'
        bg = '[0.85 0.92 1.00]';
    case 'power'
        bg = '[0.86 0.95 0.86]';
    case 'control'
        bg = '[1.00 0.95 0.80]';
    case 'decision'
        bg = '[1.00 0.88 0.74]';
    case 'output'
        bg = '[1.00 0.86 0.86]';
    otherwise
        bg = '[0.93 0.93 0.93]';
end

set_param(block_path, 'BackgroundColor', bg);
set_param(block_path, 'ForegroundColor', 'black');
end

function add_text_annotation(target_sys, text_str, pos)
% R2024b-compatible annotation creation.
ann = Simulink.Annotation(target_sys, text_str);
if nargin >= 3 && ~isempty(pos)
    ann.Position = pos;
end
end

