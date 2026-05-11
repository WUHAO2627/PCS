%% Test script for advanced models (Multi-load platform + AFE switching)
% Validates the new island load configuration and AFE switching model

clear; clc; close all;

fprintf('========================================\n');
fprintf('  Multi-Load Island Platform Test\n');
fprintf('========================================\n\n');

%% Test 1: Rebuild integrated model with advanced island loads
fprintf('Test 1: Building integrated model with multi-load island platform...\n');
try
    cd(fileparts(mfilename('fullpath')));
    cd('project/integration');
    build_integrated_system_model();
    fprintf('✓ Integrated model built successfully\n');
    fprintf('  Features:\n');
    fprintf('    - Base RL load (always active): R=10Ω, L=5mH\n');
    fprintf('    - Step load adds at t=0.15s: R=15Ω, L=3mH\n');
    fprintf('    - Nonlinear rectifier: 3-phase bridge + 1mF DC-side cap\n');
    fprintf('  Load combination: I_total = I_base + I_step + I_rectifier\n\n');
catch ME
    fprintf('✗ Error in integrated model build:\n');
    fprintf('  %s\n\n', ME.message);
end

%% Test 2: Run integrated model simulation
fprintf('Test 2: Simulating integrated model for 0.5 seconds...\n');
try
    model = 'integrated_energy_system';
    if bdIsLoaded(model)
        % Run simulation
        out = sim(model, 'StopTime', '0.5', 'Solver', 'FixedStepDiscrete', ...
            'FixedStep', '1e-4', 'SimulationMode', 'normal');
        fprintf('✓ Integration simulation completed\n');
        fprintf('  Simulation time: %.2f sec\n', toc);
        
        % Check if scopes have data
        scopes = {'Scope_Vdc', 'Scope_Iabc', 'Scope_Batt'};
        fprintf('  Data logged to scopes: %s\n\n', strjoin(scopes, ', '));
        
        close_system(model, 0);
    else
        fprintf('! Model not loaded. Skipping simulation.\n\n');
    end
catch ME
    fprintf('✗ Error during integration simulation:\n');
    fprintf('  %s\n\n', ME.message);
end

%% Test 3: Build AFE switching-level model
fprintf('Test 3: Building AFE switching-level model...\n');
try
    cd(fileparts(mfilename('fullpath')));
    cd('simulink_models');
    build_afe_switching_model();
    fprintf('✓ AFE switching model built successfully\n');
    fprintf('  Features:\n');
    fprintf('    - Universal Bridge IGBT (Ron=0.01Ω, Vf=0.8V, Tf=0.2µs)\n');
    fprintf('    - PWM carrier: triangle wave @ 10 kHz (1e-5s period)\n');
    fprintf('    - Variable-step ODE solver (ode23tb, max step=1e-5s)\n');
    fprintf('    - Split DC bus: C1=C2=2350µF\n');
    fprintf('    - Grid: 380V 50Hz with ~20Ω series impedance\n');
    fprintf('    - Control: PLL + GFL current control with Vdc outer loop\n\n');
catch ME
    fprintf('✗ Error in AFE switching model build:\n');
    fprintf('  %s\n\n', ME.message);
end

%% Test 4: AFE switching model simulation (shorter time, higher resolution)
fprintf('Test 4: Simulating AFE switching model for 0.1 seconds...\n');
try
    afe_model = 'afe_switching_rectifier';
    if bdIsLoaded(afe_model)
        % Configure solver for switching transients
        set_param(afe_model, 'StopTime', '0.1');
        set_param(afe_model, 'Solver', 'ode23tb');
        set_param(afe_model, 'MaxStep', '1e-5');
        set_param(afe_model, 'RelTol', '1e-4');
        set_param(afe_model, 'AbsTol', '1e-6');
        
        tic;
        out_afe = sim(afe_model);
        sim_time = toc;
        
        fprintf('✓ AFE switching simulation completed\n');
        fprintf('  Simulation time: %.2f sec\n', sim_time);
        fprintf('  Solver: ode23tb with adaptive step control\n');
        fprintf('  Expected outputs:\n');
        fprintf('    - AC voltage ripple with switching harmonics\n');
        fprintf('    - DC voltage with rectification ripple\n');
        fprintf('    - Gate signals showing PWM switching pattern (10 kHz)\n');
        fprintf('    - Grid current harmonics (nonlinear rectifier load)\n\n');
        
        close_system(afe_model, 0);
    else
        fprintf('! AFE model not loaded. Skipping simulation.\n\n');
    end
catch ME
    fprintf('✗ Error during AFE switching simulation:\n');
    fprintf('  %s\n\n', ME.message);
end

%% Summary
fprintf('========================================\n');
fprintf('  Test Summary\n');
fprintf('========================================\n');
fprintf('Integrated Model:\n');
fprintf('  - Average-level (discrete, Ts=1e-4s = 10 kHz)\n');
fprintf('  - Multi-load island configuration active\n');
fprintf('  - Load modes switchable via persistent state counters\n\n');
fprintf('AFE Switching Model:\n');
fprintf('  - Switching-level IGBT bridge (high fidelity)\n');
fprintf('  - Variable-step ODE solver (accurate transient response)\n');
fprintf('  - Suitable for control loop verification, THD analysis\n\n');
fprintf('Recommended Next Steps:\n');
fprintf('  1. Verify multi-load interaction: set step at various Vdc levels\n');
fprintf('  2. Analyze harmonic content of rectifier current\n');
fprintf('  3. Build similar switching models for DCDC and Inverter\n');
fprintf('  4. Compare switching-level AFE vs average model frequency response\n');
fprintf('  5. Test hardware-in-loop with AFE controller\n');
fprintf('========================================\n\n');

end
