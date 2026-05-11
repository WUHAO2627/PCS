%% Active Front End Rectifier (AFE)
% Three-phase PWM rectifier with unity power factor.
% Dual-loop: DC voltage outer loop + dq current inner loop.

classdef afe_rectifier < handle
    properties
        Vdc_ref = 750;          % DC bus voltage reference (V)
        Vgrid_peak = 311;       % Grid phase voltage peak (V)
        fgrid = 50;             % Grid frequency (Hz)
        Lac = 5e-3;             % AC-side inductance (H)
        Rac = 0.05;            % AC-side resistance (Ohm)
        Cdc = 4700e-6;          % DC bus capacitance (F)
        Ts = 5e-5;             % Control period (s)

        % Voltage loop PI
        Kp_vdc = 2.0; Ki_vdc = 100;
        % Current loop PI
        Kp_i = 20; Ki_i = 500;
        % PLL gains
        Kp_pll = 150; Ki_pll = 8000;
        % Power factor reference (1.0 = unity)
        pf_ref = 1.0;

        % State
        theta_pll = 0; omega_pll = 2*pi*50; int_pll = 0;
        int_vdc = 0; int_id = 0; int_iq = 0;
        vdc_filt = 750; vdc_filt_tc = 0.01;
    end

    methods
        function obj = afe_rectifier()
        end

        %% SRF-PLL
        function theta = pll_update(obj, vg_alpha, vg_beta)
            vq = -vg_alpha*sin(obj.theta_pll) + vg_beta*cos(obj.theta_pll);
            obj.int_pll = obj.int_pll + obj.Ki_pll*vq*obj.Ts;
            obj.omega_pll = obj.Kp_pll*vq + obj.int_pll + 2*pi*obj.fgrid;
            obj.omega_pll = max(min(obj.omega_pll, 2*pi*55), 2*pi*45);
            obj.theta_pll = mod(obj.theta_pll + obj.omega_pll*obj.Ts, 2*pi);
            theta = obj.theta_pll;
        end

        %% DC voltage outer loop
        function id_ref = dc_voltage_loop(obj, Vdc_meas)
            alpha_f = obj.Ts / (obj.vdc_filt_tc + obj.Ts);
            obj.vdc_filt = (1-alpha_f)*obj.vdc_filt + alpha_f*Vdc_meas;
            err = obj.Vdc_ref - obj.vdc_filt;
            obj.int_vdc = obj.int_vdc + obj.Ki_vdc*err*obj.Ts;
            obj.int_vdc = max(min(obj.int_vdc, 60), -60);
            id_ref = obj.Kp_vdc*err + obj.int_vdc;
            id_ref = max(min(id_ref, 80), -80);
        end

        %% dq current inner loop with decoupling
        function [ud, uq] = current_loop(obj, id_meas, iq_meas, id_ref, iq_ref, vd_grid, vq_grid)
            err_d = id_ref - id_meas;
            obj.int_id = obj.int_id + obj.Ki_i*err_d*obj.Ts;
            obj.int_id = max(min(obj.int_id, 300), -300);
            ud = obj.Kp_i*err_d + obj.int_id - obj.omega_pll*obj.Lac*iq_meas + vd_grid;

            err_q = iq_ref - iq_meas;
            obj.int_iq = obj.int_iq + obj.Ki_i*err_q*obj.Ts;
            obj.int_iq = max(min(obj.int_iq, 300), -300);
            uq = obj.Kp_i*err_q + obj.int_iq + obj.omega_pll*obj.Lac*id_meas + vq_grid;
        end

        %% Main control step
        function [Sa, Sb, Sc] = control_step(obj, ia, ib, ic, vga, vgb, vgc, Vdc_meas)
            i_alpha = 2/3*(ia - 0.5*ib - 0.5*ic);
            i_beta  = 2/3*(sqrt(3)/2*ib - sqrt(3)/2*ic);
            vg_alpha = 2/3*(vga - 0.5*vgb - 0.5*vgc);
            vg_beta  = 2/3*(sqrt(3)/2*vgb - sqrt(3)/2*vgc);

            theta = obj.pll_update(vg_alpha, vg_beta);
            id =  i_alpha*cos(theta) + i_beta*sin(theta);
            iq = -i_alpha*sin(theta) + i_beta*cos(theta);
            vd =  vg_alpha*cos(theta) + vg_beta*sin(theta);
            vq = -vg_alpha*sin(theta) + vg_beta*cos(theta);

            id_ref = obj.dc_voltage_loop(Vdc_meas);
            iq_ref = 0;
            if obj.pf_ref < 1.0
                iq_ref = id_ref * tan(acos(obj.pf_ref));
            end

            [ud_ref, uq_ref] = obj.current_loop(id, iq, id_ref, iq_ref, vd, vq);
            u_alpha = ud_ref*cos(theta) - uq_ref*sin(theta);
            u_beta  = ud_ref*sin(theta) + uq_ref*cos(theta);

            Sa = max(min(0.5 + u_alpha/Vdc_meas, 0.95), 0.05);
            Sb = max(min(0.5 + (-0.5*u_alpha + sqrt(3)/2*u_beta)/Vdc_meas, 0.95), 0.05);
            Sc = max(min(0.5 + (-0.5*u_alpha - sqrt(3)/2*u_beta)/Vdc_meas, 0.95), 0.05);
        end

        function done = precharge(obj, Vdc_meas, threshold)
            if nargin < 3, threshold = 0.9; end
            done = (Vdc_meas >= threshold * obj.Vdc_ref);
        end
    end
end
