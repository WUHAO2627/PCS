%% Multi-Inverter Parallel Operation Controller
% Synchronization detection, pre-synchronization control,
% power sharing, hot-plug management, and circulating current mitigation.

classdef multi_inverter_parallel < handle
    properties
        n_inv = 2;     % Number of parallel inverters
        S_rated;       % Rated power per inverter (vector)
        V_nom = 311; f_nom = 50;
        Ts = 1e-4;

        % Synchronization thresholds
        dV_thr = 5;      % Voltage difference threshold (V)
        df_thr = 0.05;   % Frequency difference threshold (Hz)
        dphi_thr = 0.05; % Phase difference threshold (rad)

        % Pre-sync PI
        Kp_sync = 2; Ki_sync = 20;

        % Power sharing PI
        Kp_share = 0.01; Ki_share = 0.5;

        % States
        int_sync = 0;
        int_share;
        is_synced = false;
        sync_timer = 0; sync_hold_time = 0.1;
    end

    methods
        function obj = multi_inverter_parallel(n, S_rated_vec)
            if nargin>=1, obj.n_inv = n; end
            if nargin>=2
                obj.S_rated = S_rated_vec;
            else
                obj.S_rated = ones(1, obj.n_inv)*10e3;
            end
            obj.int_share = zeros(1, obj.n_inv);
        end

        %% Check synchronization conditions
        function [synced, dV, df, dphi] = check_sync(obj, V1, f1, phi1, V2, f2, phi2)
            dV = abs(V1 - V2);
            df = abs(f1 - f2);
            dphi = abs(angle(exp(1j*(phi1 - phi2))));
            synced = (dV < obj.dV_thr) && (df < obj.df_thr) && (dphi < obj.dphi_thr);
            if synced
                obj.sync_timer = obj.sync_timer + obj.Ts;
                if obj.sync_timer >= obj.sync_hold_time
                    obj.is_synced = true;
                end
            else
                obj.sync_timer = 0;
                obj.is_synced = false;
            end
        end

        %% Pre-synchronization: adjust frequency/phase to match grid
        function delta_f = pre_sync_control(obj, phi_inv, phi_grid)
            err = angle(exp(1j*(phi_grid - phi_inv)));
            obj.int_sync = obj.int_sync + obj.Ki_sync*err*obj.Ts;
            obj.int_sync = max(min(obj.int_sync, 2), -2);
            delta_f = obj.Kp_sync*err + obj.int_sync;
        end

        %% Power sharing correction
        function delta_P = power_sharing(obj, P_meas, idx)
            % Compute proper share for inverter idx
            total_S = sum(obj.S_rated);
            share_ratio = obj.S_rated(idx)/total_S;
            P_total = sum(P_meas);
            P_expected = share_ratio * P_total;
            err = P_expected - P_meas(idx);
            obj.int_share(idx) = obj.int_share(idx) + obj.Ki_share*err*obj.Ts;
            obj.int_share(idx) = max(min(obj.int_share(idx), 500), -500);
            delta_P = obj.Kp_share*err + obj.int_share(idx);
        end

        %% Hot-plug management (ramp-up new inverter)
        function P_ref = hot_plug_ramp(~, P_target, t_elapsed, ramp_time)
            if t_elapsed < ramp_time
                P_ref = P_target * (t_elapsed/ramp_time);
            else
                P_ref = P_target;
            end
        end

        %% Communication-free power sharing using virtual impedance
        function Zv = compute_virtual_impedance(obj, idx)
            % Larger rated inverter gets smaller virtual impedance
            Zv_base = 0.05;
            ratio = max(obj.S_rated) / max(obj.S_rated(idx), 1);
            Zv = Zv_base * ratio;
        end

        %% Full parallel control step for one inverter
        function [P_ref_adj, Q_ref_adj, close_contactor] = control_step(obj, idx, ...
                P_ref, Q_ref, P_meas_all, V_inv, f_inv, phi_inv, V_grid, f_grid, phi_grid)
            close_contactor = false;
            if ~obj.is_synced
                [synced, ~, ~, ~] = obj.check_sync(V_inv, f_inv, phi_inv, V_grid, f_grid, phi_grid);
                if synced
                    close_contactor = true;
                end
                delta_f = obj.pre_sync_control(phi_inv, phi_grid);
                P_ref_adj = P_ref + delta_f*obj.S_rated(idx)*0.01;
                Q_ref_adj = Q_ref;
            else
                close_contactor = true;
                delta_P = obj.power_sharing(P_meas_all, idx);
                P_ref_adj = P_ref + delta_P;
                Q_ref_adj = Q_ref;
            end
        end

        %% Reset states (e.g., after inverter disconnect)
        function reset(obj)
            obj.int_sync = 0;
            obj.int_share = zeros(1, obj.n_inv);
            obj.is_synced = false;
            obj.sync_timer = 0;
        end
    end
end
