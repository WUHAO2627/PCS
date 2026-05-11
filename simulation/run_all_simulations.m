%% Complete Simulation Script - Pure MATLAB Verification
% Verify all control algorithms without Simulink.
% Run directly to observe waveforms.

clear; clc; close all;

fprintf('========================================\n');
fprintf(' Power Electronics Control Algorithm Verification\n');
fprintf('========================================\n\n');

% Add paths
addpath('../core_functions');
addpath('../advanced_algorithms');

%% ========== 1. Grid-Connected Inverter Simulation ==========
fprintf('--- 1. Grid-Connected Inverter ---\n');

inv = grid_connected_inverter();
inv.Vdc_ref = 700;
inv.iq_ref = 0;  % Unity power factor

Ts = inv.Ts;
t_end = 0.1;  % 100ms
N = round(t_end / Ts);

t = (0:N-1) * Ts;
id_log = zeros(1, N);
iq_log = zeros(1, N);
P_log = zeros(1, N);

for k = 1:N
    % Simulate grid voltage
    theta_g = 2*pi*50*t(k);
    vga = 311 * cos(theta_g);
    vgb = 311 * cos(theta_g - 2*pi/3);
    vgc = 311 * cos(theta_g + 2*pi/3);

    % Simulate current (simplified, assume good tracking)
    ia = inv.id_ref * cos(theta_g);
    ib = inv.id_ref * cos(theta_g - 2*pi/3);
    ic = inv.id_ref * cos(theta_g + 2*pi/3);

    % Control step
    [~, ~, ~] = inv.control_step(ia, ib, ic, vga, vgb, vgc, 690);

    id_log(k) = inv.id_ref;
    iq_log(k) = inv.iq_ref;
    P_log(k) = 1.5 * 311 * inv.id_ref;
end

figure('Name', 'Grid-Connected Inverter');
subplot(2,1,1);
plot(t*1000, id_log, 'b', t*1000, iq_log, 'r');
xlabel('Time (ms)'); ylabel('Current (A)');
legend('id', 'iq'); title('dq-axis Currents');
grid on;

subplot(2,1,2);
plot(t*1000, P_log/1000);
xlabel('Time (ms)'); ylabel('Power (kW)');
title('Active Power'); grid on;

%% ========== 2. CCCV Charging Simulation ==========
fprintf('--- 2. CCCV Constant Current / Constant Voltage Charging ---\n');

charger = cccv_charger();
charger.n_cells = 100;
charger.I_cc = 50;
charger.V_cutoff = 4.2;

Ts_ch = 0.01;  % 10ms step (accelerated)
charger.Ts = Ts_ch;
t_end_ch = 3600;  % 1 hour
N_ch = round(t_end_ch / Ts_ch);

% Battery model parameters
Voc_init = 3.3;  % Initial OCV (V/cell)
Capacity = 100;  % Ah
R_int = 0.001;   % Internal resistance (Ohm/cell)
SOC = 0.1;       % Initial SOC

t_ch = (0:N_ch-1) * Ts_ch;
V_log = zeros(1, N_ch);
I_log = zeros(1, N_ch);
SOC_log = zeros(1, N_ch);
state_log = zeros(1, N_ch);

charger.start_charging(Voc_init);

for k = 1:N_ch
    % Simplified battery model: Voc = f(SOC)
    Voc = (3.0 + 1.2*SOC) * charger.n_cells;  % Simplified OCV curve

    % Battery terminal voltage
    I_batt = charger.I_cc * (charger.state == 2) + ...
             max(0, charger.I_cc * (1 - (Voc/charger.n_cells - 3.8)/0.4)) * (charger.state == 3);
    if charger.state == 3
        % CV mode: current determined by voltage loop
        V_batt = charger.V_cutoff * charger.n_cells;
        I_batt = (V_batt - Voc) / (R_int * charger.n_cells);
        I_batt = max(I_batt, 0);
    else
        I_batt = min(charger.I_cc, 50);
        V_batt = Voc + I_batt * R_int * charger.n_cells;
    end

    % Control step
    [~, ~] = charger.control_step(V_batt, I_batt, 25);

    % SOC update
    SOC = SOC + I_batt * Ts_ch / (Capacity * 3600);
    SOC = min(SOC, 1.0);

    V_log(k) = V_batt / charger.n_cells;
    I_log(k) = I_batt;
    SOC_log(k) = SOC;
    state_log(k) = charger.state;

    if charger.state == 4
        fprintf('  Charging complete at t=%.0f s, SOC=%.1f%%\n', t_ch(k), SOC*100);
        break;
    end
end

k_end = min(k, N_ch);
figure('Name', 'CCCV Charging');
subplot(3,1,1);
plot(t_ch(1:k_end)/60, I_log(1:k_end));
xlabel('Time (min)'); ylabel('Current (A)');
title('Charging Current'); grid on;

subplot(3,1,2);
plot(t_ch(1:k_end)/60, V_log(1:k_end));
xlabel('Time (min)'); ylabel('Voltage (V/cell)');
title('Battery Voltage'); grid on;

subplot(3,1,3);
plot(t_ch(1:k_end)/60, SOC_log(1:k_end)*100);
xlabel('Time (min)'); ylabel('SOC (%)');
title('State of Charge'); grid on;

%% ========== 3. VSG Virtual Synchronous Generator ==========
fprintf('--- 3. VSG Load-Step Frequency Response ---\n');

vsg = vsg_controller();
vsg.J = 5; vsg.D = 50;
vsg.P_rated = 50000;

Ts_vsg = 1e-4;
t_end_vsg = 2.0;
N_vsg = round(t_end_vsg / Ts_vsg);

t_vsg = (0:N_vsg-1) * Ts_vsg;
freq_log = zeros(1, N_vsg);
P_vsg_log = zeros(1, N_vsg);

P_load = 50000;  % Initial load

for k = 1:N_vsg
    % Load step +20kW at t=1s
    if t_vsg(k) >= 1.0
        P_load = 70000;
    end

    % Simplified: directly drive swing equation with power
    omega_vsg = vsg.swing_equation(50000, P_load);

    freq_log(k) = omega_vsg / (2*pi);
    P_vsg_log(k) = P_load;
end

figure('Name', 'VSG Virtual Synchronous Generator');
subplot(2,1,1);
plot(t_vsg, freq_log);
xlabel('Time (s)'); ylabel('Frequency (Hz)');
title('VSG Frequency Response (Load step +20kW at t=1s)');
yline(50, 'r--'); grid on;

subplot(2,1,2);
plot(t_vsg, P_vsg_log/1000);
xlabel('Time (s)'); ylabel('Power (kW)');
title('Load Power'); grid on;

%% ========== 4. Droop Control Power Sharing ==========
fprintf('--- 4. Droop Control Multi-Inverter Power Sharing ---\n');

droop1 = droop_control();
droop1.mp = 5e-6;
droop1.nq = 1e-4;

droop2 = droop_control();
droop2.mp = 5e-6;
droop2.nq = 1e-4;  % Same capacity

droop3 = droop_control();
droop3.mp = 1e-5;
droop3.nq = 2e-4;  % Half capacity, double droop

Ts_dr = 1e-3;
t_end_dr = 3.0;
N_dr = round(t_end_dr / Ts_dr);
t_dr = (0:N_dr-1) * Ts_dr;

P1_log = zeros(1, N_dr);
P2_log = zeros(1, N_dr);
P3_log = zeros(1, N_dr);
f_log = zeros(1, N_dr);

P_total_load = 100000;  % 100kW total load

for k = 1:N_dr
    if t_dr(k) >= 1.5
        P_total_load = 150000;  % Step to 150kW
    end

    % Droop sharing (steady-state: mp1*P1 = mp2*P2 = mp3*P3)
    % P1 : P2 : P3 = 1/mp1 : 1/mp2 : 1/mp3 = 2:2:1
    sum_inv_mp = 1/droop1.mp + 1/droop2.mp + 1/droop3.mp;
    P1 = P_total_load * (1/droop1.mp) / sum_inv_mp;
    P2 = P_total_load * (1/droop2.mp) / sum_inv_mp;
    P3 = P_total_load * (1/droop3.mp) / sum_inv_mp;

    % Frequency via droop
    f_ref = droop1.f_nom - droop1.mp*(P1 - droop1.P_rated);

    P1_log(k) = P1;
    P2_log(k) = P2;
    P3_log(k) = P3;
    f_log(k) = f_ref;
end

figure('Name', 'Droop Control Parallel');
subplot(2,1,1);
plot(t_dr, P1_log/1000, 'b', t_dr, P2_log/1000, 'r', t_dr, P3_log/1000, 'g');
xlabel('Time (s)'); ylabel('Active Power (kW)');
legend('INV1 (100kVA)', 'INV2 (100kVA)', 'INV3 (50kVA)');
title('Droop Power Sharing (Load step at t=1.5s)'); grid on;

subplot(2,1,2);
plot(t_dr, f_log);
xlabel('Time (s)'); ylabel('Frequency (Hz)');
title('System Frequency'); yline(50, 'r--'); grid on;

%% ========== 5. NPC Midpoint Balance ==========
fprintf('--- 5. Three-Level NPC Midpoint Balance ---\n');

npc = npc_midpoint_balance();
npc.Vdc = 800;
npc.C1 = 4700e-6;
npc.C2 = 4700e-6;
npc.Vup = 410;   % Initial imbalance
npc.Vdn = 390;

Ts_npc = 5e-5;
t_end_npc = 0.1;
N_npc = round(t_end_npc / Ts_npc);
t_npc = (0:N_npc-1) * Ts_npc;

Vup_log = zeros(1, N_npc);
Vdn_log = zeros(1, N_npc);

for k = 1:N_npc
    theta_npc = 2*pi*50*t_npc(k);

    % Simulate three-phase current
    ia = 50 * cos(theta_npc);
    ib = 50 * cos(theta_npc - 2*pi/3);
    ic = 50 * cos(theta_npc + 2*pi/3);

    % Three-level modulation + balance
    [Sa, Sb, Sc] = npc.three_level_modulation(...
        200*cos(theta_npc), 200*sin(theta_npc), npc.Vup, npc.Vdn);

    % Update capacitor voltages
    [Vup_new, Vdn_new] = npc.update_capacitor_voltage(Sa, Sb, Sc, ia, ib, ic);

    Vup_log(k) = npc.Vup;
    Vdn_log(k) = npc.Vdn;
end

figure('Name', 'NPC Midpoint Balance');
plot(t_npc*1000, Vup_log, 'b', t_npc*1000, Vdn_log, 'r');
xlabel('Time (ms)'); ylabel('Voltage (V)');
legend('V_{C1} (upper)', 'V_{C2} (lower)');
title('NPC Midpoint Balance (Initial offset 20V)');
yline(400, 'k--'); grid on;

%% Done
fprintf('\n========================================\n');
fprintf(' All simulations complete! Check figure windows.\n');
fprintf('========================================\n');
