%% Grid-Connected Inverter Control
% Dual-loop control in dq rotating frame.
% Includes: SRF-PLL, Clarke/Park transforms, PI regulators, SVPWM.

classdef grid_connected_inverter < handle
    properties
        % System parameters
        Vdc = 700;          % DC bus voltage (V)
        Vgrid = 311;        % Grid phase voltage peak (V)
        fgrid = 50;         % Grid frequency (Hz)
        Lf = 3e-3;          % Filter inductance (H)
        Rf = 0.1;           % Filter resistance (Ohm)
        Cf = 10e-6;         % Filter capacitance (F)
        Ts = 1e-4;          % Control period (s)

        % Current loop PI gains
        Kp_id = 10;
        Ki_id = 100;
        Kp_iq = 10;
        Ki_iq = 100;

        % DC bus voltage loop PI gains
        Kp_vdc = 1;
        Ki_vdc = 50;

        % PLL gains
        Kp_pll = 100;
        Ki_pll = 5000;

        % State variables
        theta = 0;          % PLL angle
        omega = 2*pi*50;    % PLL estimated frequency
        int_id = 0;         % id integrator
        int_iq = 0;         % iq integrator
        int_vdc = 0;        % Vdc integrator
        int_pll = 0;        % PLL integrator

        % References
        id_ref = 0;         % d-axis current reference
        iq_ref = 0;         % q-axis current reference (reactive)
        Vdc_ref = 700;      % DC bus voltage reference
    end

    methods
        function obj = grid_connected_inverter()
        end

        %% Clarke transform (abc -> alpha-beta)
        function [alpha, beta] = clarke(~, a, b, c)
            alpha = 2/3 * (a - 0.5*b - 0.5*c);
            beta = 2/3 * (sqrt(3)/2*b - sqrt(3)/2*c);
        end

        %% Park transform (alpha-beta -> dq)
        function [d, q] = park(~, alpha, beta, theta)
            d = alpha * cos(theta) + beta * sin(theta);
            q = -alpha * sin(theta) + beta * cos(theta);
        end

        %% Inverse Park transform (dq -> alpha-beta)
        function [alpha, beta] = inv_park(~, d, q, theta)
            alpha = d * cos(theta) - q * sin(theta);
            beta = d * sin(theta) + q * cos(theta);
        end

        %% SRF-PLL
        function [theta_out, omega_out] = pll(obj, v_alpha, v_beta)
            vq = -v_alpha * sin(obj.theta) + v_beta * cos(obj.theta);
            obj.int_pll = obj.int_pll + obj.Ki_pll * vq * obj.Ts;
            omega_out = obj.Kp_pll * vq + obj.int_pll + 2*pi*obj.fgrid;
            obj.theta = obj.theta + omega_out * obj.Ts;
            obj.theta = mod(obj.theta, 2*pi);
            obj.omega = omega_out;
            theta_out = obj.theta;
        end

        %% DC bus voltage outer loop
        function id_ref = voltage_loop(obj, Vdc_meas)
            err = obj.Vdc_ref - Vdc_meas;
            obj.int_vdc = obj.int_vdc + obj.Ki_vdc * err * obj.Ts;
            id_ref = obj.Kp_vdc * err + obj.int_vdc;
            id_ref = max(min(id_ref, 50), -50);
            obj.id_ref = id_ref;
        end

        %% Current inner loop (with decoupling and feed-forward)
        function [vd_ref, vq_ref] = current_loop(obj, id_meas, iq_meas, vd_grid, vq_grid)
            err_d = obj.id_ref - id_meas;
            obj.int_id = obj.int_id + obj.Ki_id * err_d * obj.Ts;
            vd_ref = obj.Kp_id * err_d + obj.int_id ...
                     - obj.omega * obj.Lf * iq_meas + vd_grid;

            err_q = obj.iq_ref - iq_meas;
            obj.int_iq = obj.int_iq + obj.Ki_iq * err_q * obj.Ts;
            vq_ref = obj.Kp_iq * err_q + obj.int_iq ...
                     + obj.omega * obj.Lf * id_meas + vq_grid;
        end

        %% SVPWM space-vector modulation
        function [Ta, Tb, Tc] = svpwm(obj, v_alpha, v_beta)
            Vdc = obj.Vdc;
            V1 = v_beta;
            V2 = sqrt(3)/2 * v_alpha - 0.5 * v_beta;
            V3 = -sqrt(3)/2 * v_alpha - 0.5 * v_beta;

            sector = 0;
            if V1 > 0, sector = sector + 1; end
            if V2 > 0, sector = sector + 2; end
            if V3 > 0, sector = sector + 4; end

            sector_map = [0, 1, 5, 2, 3, 6, 4, 0];
            sector = sector_map(sector + 1);
            if sector == 0, sector = 1; end

            Ts_pwm = obj.Ts;
            K = sqrt(3) * Ts_pwm / Vdc;

            switch sector
                case 1, T1 = K*(sqrt(3)/2*v_alpha-0.5*v_beta); T2 = K*v_beta;
                case 2, T1 = K*(sqrt(3)/2*v_alpha+0.5*v_beta); T2 = K*(-sqrt(3)/2*v_alpha+0.5*v_beta);
                case 3, T1 = K*v_beta; T2 = K*(-sqrt(3)/2*v_alpha-0.5*v_beta);
                case 4, T1 = K*(-sqrt(3)/2*v_alpha+0.5*v_beta); T2 = -K*v_beta;
                case 5, T1 = K*(-sqrt(3)/2*v_alpha-0.5*v_beta); T2 = K*(sqrt(3)/2*v_alpha-0.5*v_beta);
                case 6, T1 = -K*v_beta; T2 = K*(sqrt(3)/2*v_alpha+0.5*v_beta);
                otherwise, T1 = 0; T2 = 0;
            end

            if (T1 + T2) > Ts_pwm
                ratio = Ts_pwm / (T1 + T2);
                T1 = T1 * ratio; T2 = T2 * ratio;
            end
            T0 = (Ts_pwm - T1 - T2) / 2;

            switch sector
                case 1, Ta=T1+T2+T0; Tb=T2+T0; Tc=T0;
                case 2, Ta=T1+T0; Tb=T1+T2+T0; Tc=T0;
                case 3, Ta=T0; Tb=T1+T2+T0; Tc=T2+T0;
                case 4, Ta=T0; Tb=T1+T0; Tc=T1+T2+T0;
                case 5, Ta=T2+T0; Tb=T0; Tc=T1+T2+T0;
                case 6, Ta=T1+T2+T0; Tb=T0; Tc=T1+T0;
                otherwise, Ta=0; Tb=0; Tc=0;
            end
            Ta = Ta/Ts_pwm; Tb = Tb/Ts_pwm; Tc = Tc/Ts_pwm;
        end

        %% Main control step
        function [duty_a, duty_b, duty_c] = control_step(obj, ia, ib, ic, vga, vgb, vgc, Vdc_meas)
            [i_alpha, i_beta] = obj.clarke(ia, ib, ic);
            [vg_alpha, vg_beta] = obj.clarke(vga, vgb, vgc);
            [theta_pll, ~] = obj.pll(vg_alpha, vg_beta);
            [id, iq] = obj.park(i_alpha, i_beta, theta_pll);
            [vd_grid, vq_grid] = obj.park(vg_alpha, vg_beta, theta_pll);
            obj.voltage_loop(Vdc_meas);
            [vd_ref, vq_ref] = obj.current_loop(id, iq, vd_grid, vq_grid);
            [v_alpha_ref, v_beta_ref] = obj.inv_park(vd_ref, vq_ref, theta_pll);
            [duty_a, duty_b, duty_c] = obj.svpwm(v_alpha_ref, v_beta_ref);
        end
    end
end
