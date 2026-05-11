%% Droop Control for Grid-Forming Inverters
% P-f droop, Q-V droop, virtual impedance, secondary regulation.
% Supports adaptive droop and power-sharing accuracy enhancement.

classdef droop_control < handle
    properties
        % Rated values
        P_rated = 10e3; Q_rated = 5e3;
        f_nom   = 50;   V_nom   = 311;
        % Droop gains
        mp = 2e-5;  % P-f droop slope (Hz/W)
        nq = 1e-4;  % Q-V droop slope (V/Var)
        % Virtual impedance
        Rv = 0.05; Lv = 0.5e-3;
        % Secondary regulation PI
        Kp_sec_f = 0.5; Ki_sec_f = 5;
        Kp_sec_v = 0.3; Ki_sec_v = 3;
        % Low pass filter
        omega_lp = 2*pi*5; Ts = 1e-4;
        % Adaptive droop
        enable_adaptive = false;
        mp_min = 1e-5; mp_max = 5e-5;
        nq_min = 5e-5; nq_max = 3e-4;

        % States
        P_filt = 0; Q_filt = 0;
        int_sec_f = 0; int_sec_v = 0;
        theta = 0;
    end

    methods
        function obj = droop_control()
        end

        %% Power measurement with low-pass filter
        function [P, Q] = measure_power(obj, v_alpha, v_beta, i_alpha, i_beta)
            P_inst = 1.5*(v_alpha*i_alpha + v_beta*i_beta);
            Q_inst = 1.5*(v_beta*i_alpha - v_alpha*i_beta);
            alpha = obj.omega_lp*obj.Ts/(1+obj.omega_lp*obj.Ts);
            obj.P_filt = (1-alpha)*obj.P_filt + alpha*P_inst;
            obj.Q_filt = (1-alpha)*obj.Q_filt + alpha*Q_inst;
            P = obj.P_filt; Q = obj.Q_filt;
        end

        %% Primary droop
        function [f_ref, V_ref] = primary_droop(obj, P_meas, Q_meas)
            f_ref = obj.f_nom - obj.mp*(P_meas - obj.P_rated);
            V_ref = obj.V_nom - obj.nq*(Q_meas - obj.Q_rated);
        end

        %% Secondary regulation (restore frequency and voltage)
        function [df, dV] = secondary_regulation(obj, f_meas, V_meas)
            ef = obj.f_nom - f_meas;
            ev = obj.V_nom - V_meas;
            obj.int_sec_f = obj.int_sec_f + obj.Ki_sec_f*ef*obj.Ts;
            obj.int_sec_v = obj.int_sec_v + obj.Ki_sec_v*ev*obj.Ts;
            obj.int_sec_f = max(min(obj.int_sec_f, 2), -2);
            obj.int_sec_v = max(min(obj.int_sec_v, 20), -20);
            df = obj.Kp_sec_f*ef + obj.int_sec_f;
            dV = obj.Kp_sec_v*ev + obj.int_sec_v;
        end

        %% Virtual impedance voltage drop
        function [vR_d, vR_q] = virtual_impedance(obj, id, iq, omega)
            vR_d = obj.Rv*id - omega*obj.Lv*iq;
            vR_q = obj.Rv*iq + omega*obj.Lv*id;
        end

        %% Adaptive droop (adjust slopes based on loading)
        function update_adaptive_droop(obj, P_meas, Q_meas)
            if obj.enable_adaptive
                load_ratio_p = abs(P_meas)/max(obj.P_rated, 1);
                load_ratio_q = abs(Q_meas)/max(obj.Q_rated, 1);
                obj.mp = obj.mp_min + (obj.mp_max-obj.mp_min)*load_ratio_p;
                obj.nq = obj.nq_min + (obj.nq_max-obj.nq_min)*load_ratio_q;
            end
        end

        %% Full control step
        function [v_ref_d, v_ref_q, omega_ref, theta_ref] = control_step(obj, v_alpha, v_beta, i_alpha, i_beta, id, iq, f_meas, V_meas)
            [P, Q] = obj.measure_power(v_alpha, v_beta, i_alpha, i_beta);
            obj.update_adaptive_droop(P, Q);
            [f_r, V_r] = obj.primary_droop(P, Q);
            [df, dV] = obj.secondary_regulation(f_meas, V_meas);
            f_ref = f_r + df;
            V_ref = V_r + dV;
            omega_ref = 2*pi*f_ref;
            obj.theta = obj.theta + omega_ref*obj.Ts;
            obj.theta = mod(obj.theta, 2*pi);
            theta_ref = obj.theta;
            [vR_d, vR_q] = obj.virtual_impedance(id, iq, omega_ref);
            v_ref_d = V_ref - vR_d;
            v_ref_q = 0     - vR_q;
        end
    end
end
