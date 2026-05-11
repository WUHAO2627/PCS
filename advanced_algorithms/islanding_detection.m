%% Islanding Detection
% Passive: OVP/UVP, OFP/UFP, phase-jump (ROCOF), THD.
% Active: Active Frequency Drift (AFD), active power perturbation.

classdef islanding_detection < handle
    properties
        Vnom = 220; fnom = 50; Ts = 1e-4;
        V_over = 1.1; V_under = 0.88;
        f_over = 50.5; f_under = 49.5;
        dtheta_max = 0.1; thd_max = 0.05;
        trip_delay_V = 2.0; trip_delay_f = 0.5;

        % AFD parameters
        afd_cf = 0.05; afd_gain = 0.05;

        % State
        theta_prev = 0; freq_prev = 50; V_rms_prev = 220;
        timer_V = 0; timer_f = 0;
        island_detected = false;
        afd_phase_offset = 0;
        v_buffer = []; buffer_size = 200;
    end

    methods
        function obj = islanding_detection()
            obj.v_buffer = zeros(1, obj.buffer_size);
        end

        function [trip, reason] = check_voltage(obj, V_rms)
            V_pu = V_rms / obj.Vnom;
            trip = false; reason = '';
            if V_pu > obj.V_over || V_pu < obj.V_under
                obj.timer_V = obj.timer_V + obj.Ts;
                if obj.timer_V >= obj.trip_delay_V
                    trip = true;
                    if V_pu > obj.V_over, reason = sprintf('OVP: V=%.2f pu', V_pu);
                    else, reason = sprintf('UVP: V=%.2f pu', V_pu); end
                end
            else
                obj.timer_V = 0;
            end
        end

        function [trip, reason] = check_frequency(obj, freq)
            trip = false; reason = '';
            if freq > obj.f_over || freq < obj.f_under
                obj.timer_f = obj.timer_f + obj.Ts;
                if obj.timer_f >= obj.trip_delay_f
                    trip = true;
                    if freq > obj.f_over, reason = sprintf('OFP: f=%.2f Hz', freq);
                    else, reason = sprintf('UFP: f=%.2f Hz', freq); end
                end
            else
                obj.timer_f = 0;
            end
        end

        function [trip, reason] = check_phase_jump(obj, theta)
            trip = false; reason = '';
            dtheta = theta - obj.theta_prev;
            if dtheta > pi, dtheta = dtheta - 2*pi; end
            if dtheta < -pi, dtheta = dtheta + 2*pi; end
            expected = 2*pi*obj.fnom*obj.Ts;
            phase_error = abs(dtheta - expected);
            if phase_error > obj.dtheta_max
                trip = true;
                reason = sprintf('Phase jump: d_theta=%.4f rad', phase_error);
            end
            obj.theta_prev = theta;
        end

        function [trip_afd, ~, iq_inject] = active_afd(obj, freq_meas)
            trip_afd = false;
            df = freq_meas - obj.fnom;
            obj.afd_phase_offset = obj.afd_phase_offset + obj.afd_cf*sign(df)*2*pi*obj.Ts;
            iq_inject = max(min(obj.afd_gain*obj.afd_phase_offset, 5), -5);
            if abs(freq_meas - obj.fnom) > 1.0
                trip_afd = true;
            end
        end

        function [island, method] = detect(obj, V_rms, freq, theta, ~)
            island = false; method = '';
            [tv, rv] = obj.check_voltage(V_rms);
            if tv, island = true; method = rv; obj.island_detected = true; return; end
            [tf, rf] = obj.check_frequency(freq);
            if tf, island = true; method = rf; obj.island_detected = true; return; end
            [tp, rp] = obj.check_phase_jump(theta);
            if tp, island = true; method = rp; obj.island_detected = true; return; end
            [ta, ~, ~] = obj.active_afd(freq);
            if ta, island = true; method = 'AFD active detection'; obj.island_detected = true; end
            obj.V_rms_prev = V_rms; obj.freq_prev = freq;
        end

        function reset(obj)
            obj.island_detected = false;
            obj.timer_V = 0; obj.timer_f = 0;
            obj.afd_phase_offset = 0;
        end
    end
end
