%% Virtual Synchronous Generator (VSG) Controller
% Implements swing equation, excitation control, and voltage/current
% dual-loop for grid-forming inverters emulating synchronous machine.

classdef vsg_controller < handle
    properties
        % Machine inertia
        J  = 0.5;   % Virtual inertia (kg*m^2)
        D  = 10;    % Damping coefficient
        % Excitation / Q-V loop
        Kq = 50;    % Q-V droop gain
        tau_v = 0.02; % Voltage filter time constant
        % Rated
        P_rated = 10e3; Q_rated = 5e3;
        omega_nom = 2*pi*50; V_nom = 311;
        % Voltage loop PI
        Kp_v = 0.5; Ki_v = 50;
        % Current loop PI
        Kp_i = 10; Ki_i = 500;
        % Filter
        Lf = 1.5e-3; Cf = 20e-6; Rf = 0.1;
        Ts = 1e-4;

        % State
        omega  = 2*pi*50; theta = 0; delta_omega = 0;
        E_mag  = 311;
        int_vd = 0; int_vq = 0;
        int_id = 0; int_iq = 0;
        V_filt = 311;
    end

    methods
        function obj = vsg_controller()
        end

        %% Swing equation: J*d(omega)/dt = P_ref - P_meas - D*(omega-omega0)
        function omega_out = swing_equation(obj, P_ref, P_meas)
            dw = (1/obj.J)*(P_ref/obj.omega - P_meas/obj.omega - obj.D*(obj.omega - obj.omega_nom));
            obj.omega = obj.omega + dw*obj.Ts;
            obj.omega = max(min(obj.omega, 2*pi*52), 2*pi*48); % frequency limits
            obj.theta = obj.theta + obj.omega*obj.Ts;
            obj.theta = mod(obj.theta, 2*pi);
            omega_out = obj.omega;
        end

        %% Excitation control (Q-V droop + filter)
        function E = excitation_control(obj, Q_ref, Q_meas, V_meas)
            alpha = obj.Ts/(obj.tau_v+obj.Ts);
            obj.V_filt = (1-alpha)*obj.V_filt + alpha*V_meas;
            E = obj.V_nom + obj.Kq*(Q_ref - Q_meas) + (obj.V_nom - obj.V_filt);
            E = max(min(E, 1.1*obj.V_nom), 0.8*obj.V_nom);
            obj.E_mag = E;
        end

        %% Voltage loop (dq frame)
        function [id_ref, iq_ref] = voltage_loop(obj, vd_ref, vq_ref, vd, vq, iod, ioq)
            ed = vd_ref - vd;
            eq = vq_ref - vq;
            obj.int_vd = obj.int_vd + obj.Ki_v*ed*obj.Ts;
            obj.int_vq = obj.int_vq + obj.Ki_v*eq*obj.Ts;
            obj.int_vd = max(min(obj.int_vd, 50), -50);
            obj.int_vq = max(min(obj.int_vq, 50), -50);
            id_ref = obj.Kp_v*ed + obj.int_vd + iod - obj.omega*obj.Cf*vq;
            iq_ref = obj.Kp_v*eq + obj.int_vq + ioq + obj.omega*obj.Cf*vd;
        end

        %% Current loop (dq frame)
        function [vd_out, vq_out] = current_loop(obj, id_ref, iq_ref, id, iq, vd_ff, vq_ff)
            ed = id_ref - id;
            eq = iq_ref - iq;
            obj.int_id = obj.int_id + obj.Ki_i*ed*obj.Ts;
            obj.int_iq = obj.int_iq + obj.Ki_i*eq*obj.Ts;
            obj.int_id = max(min(obj.int_id, 200), -200);
            obj.int_iq = max(min(obj.int_iq, 200), -200);
            vd_out = obj.Kp_i*ed + obj.int_id - obj.omega*obj.Lf*iq + vd_ff;
            vq_out = obj.Kp_i*eq + obj.int_iq + obj.omega*obj.Lf*id + vq_ff;
        end

        %% Full control step
        function [vd_mod, vq_mod, theta_out, omega_out] = control_step(obj, P_ref, Q_ref, P_meas, Q_meas, ...
                V_meas, vd, vq, id, iq, iod, ioq)
            omega_out = obj.swing_equation(P_ref, P_meas);
            E = obj.excitation_control(Q_ref, Q_meas, V_meas);
            vd_ref = E; vq_ref = 0;
            [id_ref, iq_ref] = obj.voltage_loop(vd_ref, vq_ref, vd, vq, iod, ioq);
            [vd_mod, vq_mod] = obj.current_loop(id_ref, iq_ref, id, iq, vd, vq);
            theta_out = obj.theta;
        end

        %% Power calculation helper
        function [P, Q] = calc_power(~, vd, vq, id, iq)
            P = 1.5*(vd*id + vq*iq);
            Q = 1.5*(vq*id - vd*iq);
        end
    end
end
