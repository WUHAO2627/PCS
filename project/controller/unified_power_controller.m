classdef unified_power_controller < handle
    % Unified controller that coordinates all created modules under one project.

    properties
        cfg
        mode

        afe
        inv
        bstart
        charger

        npb
        island
        circ
        droop
        vsg
        parallel

        pcc_closed logical = true
        island_trip_latched logical = false
    end

    methods
        function obj = unified_power_controller(cfg)
            if nargin < 1
                cfg = system_config();
            end
            obj.cfg = cfg;
            obj.mode = char(cfg.mode.default);

            obj.afe = afe_rectifier();
            obj.inv = grid_connected_inverter();
            obj.bstart = black_start_controller();
            obj.charger = cccv_charger();

            obj.npb = npc_midpoint_balance();
            obj.island = islanding_detection();
            obj.circ = circulating_current_suppressor();
            obj.droop = droop_control();
            obj.vsg = vsg_controller();
            obj.parallel = multi_inverter_parallel(cfg.parallel.max_units);

            obj.afe.Ts = cfg.Ts;
            obj.inv.Ts = cfg.Ts;
            obj.bstart.Ts = cfg.Ts;
            obj.charger.Ts = cfg.Ts;
            obj.npb.Ts = cfg.Ts;
            obj.island.Ts = cfg.Ts;
            obj.droop.Ts = cfg.Ts;
            obj.vsg.Ts = cfg.Ts;

            obj.afe.Vdc_ref = cfg.vdc_ref;
            obj.inv.Vdc_ref = cfg.vdc_ref;
            obj.charger.I_cc = cfg.battery.cc_current;
            obj.charger.I_taper = cfg.battery.taper_current;
            obj.charger.n_cells = cfg.battery.cells_series;
            obj.charger.V_cutoff = cfg.battery.cv_voltage_per_cell;
        end

        function set_mode(obj, new_mode)
            valid = ["GRID_CONNECTED", "ISLANDED", "CHARGING", "BLACK_START"];
            if ~any(valid == string(new_mode))
                error('Unsupported mode: %s', string(new_mode));
            end
            obj.mode = char(new_mode);
        end

        function out = step(obj, m)
            out = struct();
            out.pcc_cmd_close = obj.pcc_closed;
            out.afe_pwm = [0 0 0];
            out.inv_pwm = [0 0 0];
            out.dcdc_duty = 0;
            out.mode = obj.mode;
            out.trip_reason = '';

            % Anti-islanding protection path.
            [islanded, reason] = obj.island.detect(m.V_rms, m.freq, m.theta, m.v_sample);
            if islanded && ~obj.island_trip_latched
                obj.island_trip_latched = true;
                obj.pcc_closed = false;
                out.trip_reason = reason;
            end
            out.pcc_cmd_close = obj.pcc_closed;

            switch obj.mode
                case 'GRID_CONNECTED'
                    [Sa, Sb, Sc] = obj.afe.control_step(...
                        m.ia, m.ib, m.ic, m.vga, m.vgb, m.vgc, m.Vdc);
                    out.afe_pwm = [Sa, Sb, Sc];

                case 'CHARGING'
                    [duty, state] = obj.charger.control_step(m.Vbatt, m.Ibatt, m.Tbatt);
                    out.dcdc_duty = duty;
                    out.charge_state = state;

                case 'ISLANDED'
                    obj.vsg.Pref = m.Pref;
                    obj.vsg.Qref = m.Qref;
                    [ua, ub, uc] = obj.vsg.control_step(...
                        m.va, m.vb, m.vc, m.ia, m.ib, m.ic, m.iLa, m.iLb, m.iLc);
                    out.inv_pwm = duty_from_abc_voltage([ua ub uc], max(m.Vdc, 1));

                case 'BLACK_START'
                    [da, db, dc] = obj.bstart.control_step(...
                        m.vca, m.vcb, m.vcc, m.iLa, m.iLb, m.iLc);
                    out.inv_pwm = [da, db, dc];
            end

            % Common advanced algorithms hooks.
            out.np_offset = obj.npb.zero_sequence_injection(m.Vc1, m.Vc2, m.ia, m.ib, m.ic);
            out.zero_seq_comp = obj.circ.zero_sequence_suppression((m.ia + m.ib + m.ic) / 3);
        end
    end
end

function duty = duty_from_abc_voltage(vabc, Vdc)
% Simple linear modulation to produce duty references from phase voltages.
va = vabc(1);
vb = vabc(2);
vc = vabc(3);
duty = [
    0.5 + va / Vdc, ...
    0.5 + vb / Vdc, ...
    0.5 + vc / Vdc ...
];
duty = min(max(duty, 0.05), 0.95);
end
