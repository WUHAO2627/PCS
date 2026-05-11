%% Black Start Controller
% Builds microgrid voltage from zero (no grid present) using V/f mode.
% Features: soft-start voltage ramp, voltage/current dual-loop.

classdef black_start_controller < handle
    properties
        Vdc = 700;              % DC bus voltage (V)
        Vnom = 311;             % Rated phase voltage peak (V)
        fnom = 50;              % Rated frequency (Hz)
        Lf = 2e-3;             % Filter inductance (H)
        Cf = 20e-6;            % Filter capacitance (F)
        Ts = 1e-4;             % Control period (s)

        % Voltage loop PI
        Kp_vd = 0.5; Ki_vd = 50;
        Kp_vq = 0.5; Ki_vq = 50;

        % Current loop PI
        Kp_id = 15; Ki_id = 200;
        Kp_iq = 15; Ki_iq = 200;

        % Soft-start
        ramp_time = 2.0;        % Voltage ramp duration (s)
        ramp_step = 0;

        % State
        theta = 0;
        int_vd = 0; int_vq = 0;
        int_id = 0; int_iq = 0;
        state = 0;              % 0:standby 1:ramping 2:running 3:loaded
        elapsed_time = 0;
        Vd_ref = 0; Vq_ref = 0;
    end

    methods
        function obj = black_start_controller()
        end

        function start(obj)
            obj.state = 1;
            obj.elapsed_time = 0;
            obj.theta = 0;
            obj.int_vd = 0; obj.int_vq = 0;
            obj.int_id = 0; obj.int_iq = 0;
            fprintf('Black start initiated, voltage ramping...\n');
        end

        function V_target = soft_start_ramp(obj)
            if obj.elapsed_time < obj.ramp_time
                V_target = obj.Vnom * (obj.elapsed_time / obj.ramp_time);
            else
                V_target = obj.Vnom;
                if obj.state == 1
                    obj.state = 2;
                    fprintf('Voltage established, entering V/f mode.\n');
                end
            end
        end

        function [duty_a, duty_b, duty_c] = control_step(obj, v_cap_a, v_cap_b, v_cap_c, ...
                                                           iL_a, iL_b, iL_c)
            obj.elapsed_time = obj.elapsed_time + obj.Ts;

            % Free-running angle (no PLL needed)
            obj.theta = mod(obj.theta + 2*pi*obj.fnom*obj.Ts, 2*pi);

            V_target = obj.soft_start_ramp();
            obj.Vd_ref = V_target; obj.Vq_ref = 0;

            % Clarke
            v_alpha = 2/3*(v_cap_a - 0.5*v_cap_b - 0.5*v_cap_c);
            v_beta  = 2/3*(sqrt(3)/2*v_cap_b - sqrt(3)/2*v_cap_c);
            i_alpha = 2/3*(iL_a - 0.5*iL_b - 0.5*iL_c);
            i_beta  = 2/3*(sqrt(3)/2*iL_b - sqrt(3)/2*iL_c);

            % Park
            vd =  v_alpha*cos(obj.theta) + v_beta*sin(obj.theta);
            vq = -v_alpha*sin(obj.theta) + v_beta*cos(obj.theta);
            id =  i_alpha*cos(obj.theta) + i_beta*sin(obj.theta);
            iq = -i_alpha*sin(obj.theta) + i_beta*cos(obj.theta);

            % Voltage outer loop
            err_vd = obj.Vd_ref - vd;
            obj.int_vd = obj.int_vd + obj.Ki_vd*err_vd*obj.Ts;
            id_ref = obj.Kp_vd*err_vd + obj.int_vd + 2*pi*obj.fnom*obj.Cf*vq;

            err_vq = obj.Vq_ref - vq;
            obj.int_vq = obj.int_vq + obj.Ki_vq*err_vq*obj.Ts;
            iq_ref = obj.Kp_vq*err_vq + obj.int_vq - 2*pi*obj.fnom*obj.Cf*vd;

            id_ref = max(min(id_ref, 80), -80);
            iq_ref = max(min(iq_ref, 80), -80);

            % Current inner loop
            err_id = id_ref - id;
            obj.int_id = obj.int_id + obj.Ki_id*err_id*obj.Ts;
            ud_ref = obj.Kp_id*err_id + obj.int_id - 2*pi*obj.fnom*obj.Lf*iq + vd;

            err_iq = iq_ref - iq;
            obj.int_iq = obj.int_iq + obj.Ki_iq*err_iq*obj.Ts;
            uq_ref = obj.Kp_iq*err_iq + obj.int_iq + 2*pi*obj.fnom*obj.Lf*id + vq;

            % Inverse Park -> SPWM
            u_alpha = ud_ref*cos(obj.theta) - uq_ref*sin(obj.theta);
            u_beta  = ud_ref*sin(obj.theta) + uq_ref*cos(obj.theta);

            duty_a = max(min(0.5 + u_alpha/obj.Vdc, 0.95), 0.05);
            duty_b = max(min(0.5 + (-0.5*u_alpha + sqrt(3)/2*u_beta)/obj.Vdc, 0.95), 0.05);
            duty_c = max(min(0.5 + (-0.5*u_alpha - sqrt(3)/2*u_beta)/obj.Vdc, 0.95), 0.05);
        end

        function ok = check_load_capacity(obj, load_power)
            max_power = obj.Vnom * 50 * 3 / sqrt(2);
            ok = (obj.state >= 2) && (load_power < max_power*0.8);
            if ok, obj.state = 3; end
        end
    end
end
