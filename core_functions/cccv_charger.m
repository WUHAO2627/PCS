%% Constant-Current Constant-Voltage (CCCV) Charging Controller
% Stages: standby -> pre-charge -> CC -> CV -> complete.
% Includes over-voltage, over-current, over-temperature protection.

classdef cccv_charger < handle
    properties
        V_cutoff = 4.2;         % Cutoff voltage (V/cell)
        I_cc = 50;              % CC-mode current (A)
        I_taper = 2;            % CV end-of-charge current (A)
        V_precharge = 3.0;      % Pre-charge threshold (V/cell)
        I_precharge = 5;        % Pre-charge current (A)
        n_cells = 100;          % Series cell count

        % Current loop PI
        Kp_i = 0.5; Ki_i = 50;
        % Voltage loop PI
        Kp_v = 2.0; Ki_v = 20;

        Ts = 1e-4; Vdc_bus = 750; L_buck = 1e-3;

        % State
        state = 0;              % 0:standby 1:precharge 2:CC 3:CV 4:done
        int_i = 0; int_v = 0;
        charge_Ah = 0; charge_time = 0;

        % Protection limits
        V_max = 4.25; I_max = 60; T_max = 45;
    end

    methods
        function obj = cccv_charger()
        end

        function start_charging(obj, V_batt_cell)
            if V_batt_cell < obj.V_precharge
                obj.state = 1;
            else
                obj.state = 2;
            end
            obj.charge_Ah = 0; obj.charge_time = 0;
            obj.int_i = 0; obj.int_v = 0;
        end

        function safe = protection_check(obj, V_cell, I_batt, T_batt)
            safe = true;
            if V_cell > obj.V_max || I_batt > obj.I_max || T_batt > obj.T_max
                obj.state = 0; safe = false;
            end
        end

        function duty = current_pi(obj, I_ref, I_meas)
            err = I_ref - I_meas;
            obj.int_i = obj.int_i + obj.Ki_i*err*obj.Ts;
            obj.int_i = max(min(obj.int_i, 0.9), 0);
            duty = max(min(obj.Kp_i*err + obj.int_i, 0.95), 0);
        end

        function I_ref = voltage_pi(obj, V_ref, V_meas)
            err = V_ref - V_meas;
            obj.int_v = obj.int_v + obj.Ki_v*err*obj.Ts;
            obj.int_v = max(min(obj.int_v, obj.I_cc), 0);
            I_ref = max(min(obj.Kp_v*err + obj.int_v, obj.I_cc), 0);
        end

        function [duty, state_out] = control_step(obj, V_batt, I_batt, T_batt)
            obj.charge_time = obj.charge_time + obj.Ts;
            obj.charge_Ah = obj.charge_Ah + I_batt*obj.Ts/3600;
            V_cell = V_batt / obj.n_cells;

            if ~obj.protection_check(V_cell, I_batt, T_batt)
                duty = 0; state_out = obj.state; return;
            end

            switch obj.state
                case 0, duty = 0;
                case 1
                    duty = obj.current_pi(obj.I_precharge, I_batt);
                    if V_cell >= obj.V_precharge
                        obj.state = 2; obj.int_i = 0;
                    end
                case 2
                    duty = obj.current_pi(obj.I_cc, I_batt);
                    if V_cell >= obj.V_cutoff
                        obj.state = 3; obj.int_v = obj.int_i;
                    end
                case 3
                    V_ref_total = obj.V_cutoff * obj.n_cells;
                    I_ref = obj.voltage_pi(V_ref_total, V_batt);
                    duty = obj.current_pi(I_ref, I_batt);
                    if I_batt <= obj.I_taper
                        obj.state = 4;
                    end
                case 4, duty = 0;
                otherwise, duty = 0;
            end
            state_out = obj.state;
        end

        function info = get_status(obj)
            names = {'Standby','PreCharge','CC','CV','Complete'};
            info.state_name = names{obj.state+1};
            info.charge_Ah = obj.charge_Ah;
            info.charge_time_min = obj.charge_time/60;
            info.state_code = obj.state;
        end
    end
end
