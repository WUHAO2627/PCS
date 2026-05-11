%% Circulating Current Suppression Controller
% For MMC: CCSC in negative-sequence 2w dq frame.
% For parallel inverters: zero-sequence PI + per-phase PR controller.

classdef circulating_current_suppressor < handle
    properties
        Vdc = 800; fgrid = 50; Larm = 5e-3; Rarm = 0.1; N_sm = 10; Ts = 5e-5;

        % CCSC PI (2nd harmonic dq frame)
        Kp_cc = 10; Ki_cc = 500;
        % PR controller
        Kp_pr = 5; Kr_pr = 1000;
        omega_r = 2*pi*100; omega_c = 5;
        % Zero-sequence PI
        Kp_zero = 8; Ki_zero = 400;

        % State
        int_d2 = 0; int_q2 = 0; int_zero = 0;
        pr_x1 = [0;0;0]; pr_x2 = [0;0;0];
        i_zero_ref = 0;
    end

    methods
        function obj = circulating_current_suppressor()
        end

        %% CCSC in negative-sequence 2w dq frame (for MMC)
        function [v_a, v_b, v_c] = ccsc_dq(obj, i_circ_a, i_circ_b, i_circ_c, theta)
            theta2 = -2*theta;
            i_al = 2/3*(i_circ_a - 0.5*i_circ_b - 0.5*i_circ_c);
            i_be = 2/3*(sqrt(3)/2*i_circ_b - sqrt(3)/2*i_circ_c);
            id2 =  i_al*cos(theta2) + i_be*sin(theta2);
            iq2 = -i_al*sin(theta2) + i_be*cos(theta2);

            obj.int_d2 = obj.int_d2 + obj.Ki_cc*(0-id2)*obj.Ts;
            obj.int_q2 = obj.int_q2 + obj.Ki_cc*(0-iq2)*obj.Ts;
            vd2 = obj.Kp_cc*(0-id2) + obj.int_d2 - 2*2*pi*obj.fgrid*obj.Larm*iq2;
            vq2 = obj.Kp_cc*(0-iq2) + obj.int_q2 + 2*2*pi*obj.fgrid*obj.Larm*id2;

            v_al = vd2*cos(theta2) - vq2*sin(theta2);
            v_be = vd2*sin(theta2) + vq2*cos(theta2);
            v_a = v_al;
            v_b = -0.5*v_al + sqrt(3)/2*v_be;
            v_c = -0.5*v_al - sqrt(3)/2*v_be;
        end

        %% PR controller (SOGI-based, per phase)
        function v_out = pr_controller(obj, i_circ, phase_idx)
            wr = obj.omega_r; wc = obj.omega_c;
            x1 = obj.pr_x1(phase_idx); x2 = obj.pr_x2(phase_idx);
            x1_new = x1 + obj.Ts*x2;
            x2_new = x2 + obj.Ts*(-wr^2*x1 - 2*wc*x2 + 2*wc*obj.Kr_pr*i_circ);
            obj.pr_x1(phase_idx) = x1_new;
            obj.pr_x2(phase_idx) = x2_new;
            v_out = -(obj.Kp_pr*i_circ + x2_new);
        end

        %% Zero-sequence suppression (parallel inverters)
        function v_zero = zero_sequence_suppression(obj, i_zero)
            err = obj.i_zero_ref - i_zero;
            obj.int_zero = obj.int_zero + obj.Ki_zero*err*obj.Ts;
            obj.int_zero = max(min(obj.int_zero, 50), -50);
            v_zero = obj.Kp_zero*err + obj.int_zero;
        end

        %% Extract circulating current from MMC arm currents
        function [ic_a, ic_b, ic_c] = extract_circulating_current(~, iu_a, iu_b, iu_c, il_a, il_b, il_c)
            com_a = (iu_a+il_a)/2; com_b = (iu_b+il_b)/2; com_c = (iu_c+il_c)/2;
            Idc_avg = (com_a+com_b+com_c)/3;
            ic_a = com_a - Idc_avg; ic_b = com_b - Idc_avg; ic_c = com_c - Idc_avg;
        end

        function [v_a, v_b, v_c] = control_step_mmc(obj, iu_a, iu_b, iu_c, il_a, il_b, il_c, theta)
            [ic_a, ic_b, ic_c] = obj.extract_circulating_current(iu_a, iu_b, iu_c, il_a, il_b, il_c);
            [v_a, v_b, v_c] = obj.ccsc_dq(ic_a, ic_b, ic_c, theta);
        end

        function [v_a, v_b, v_c] = control_step_parallel(obj, ia, ib, ic)
            i_zero = (ia+ib+ic)/3;
            v_z = obj.zero_sequence_suppression(i_zero);
            v_a = v_z + obj.pr_controller(ia, 1);
            v_b = v_z + obj.pr_controller(ib, 2);
            v_c = v_z + obj.pr_controller(ic, 3);
        end
    end
end
