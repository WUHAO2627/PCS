%% Three-Level NPC Neutral-Point Potential Balancing
% Methods: zero-sequence injection, redundant vector selection, carrier offset.

classdef npc_midpoint_balance < handle
    properties
        Vdc = 800;              % Total DC bus voltage (V)
        C1 = 4700e-6;           % Upper capacitor (F)
        C2 = 4700e-6;           % Lower capacitor (F)
        Ts = 5e-5;

        Kp_bal = 5.0; Ki_bal = 200;
        max_offset = 0.1;       % Max zero-sequence injection (pu)
        int_bal = 0;
        Vup = 400; Vdn = 400;
    end

    methods
        function obj = npc_midpoint_balance()
        end

        %% Zero-sequence voltage injection
        function v_offset = zero_sequence_injection(obj, Vup_meas, Vdn_meas, ~, ~, ~)
            delta_V = Vup_meas - Vdn_meas;
            obj.int_bal = obj.int_bal + obj.Ki_bal*delta_V*obj.Ts;
            obj.int_bal = max(min(obj.int_bal, obj.max_offset*obj.Vdc), -obj.max_offset*obj.Vdc);
            v_offset = obj.Kp_bal*delta_V + obj.int_bal;
            v_offset = max(min(v_offset, obj.max_offset*obj.Vdc), -obj.max_offset*obj.Vdc);
        end

        %% Redundant vector selection
        function [Sa, Sb, Sc] = redundant_vector_selection(obj, ~, ~, ~, Vup_meas, Vdn_meas)
            delta_V = Vup_meas - Vdn_meas;
            k = 0.5 - obj.Kp_bal*delta_V/obj.Vdc;
            k = max(min(k, 1.0), 0.0); %#ok<NASGU>
            Sa = 0; Sb = 0; Sc = 0;
        end

        %% Carrier offset method
        function [ref_a, ref_b, ref_c] = carrier_offset_method(obj, va_ref, vb_ref, vc_ref, Vup_meas, Vdn_meas)
            delta_V = Vup_meas - Vdn_meas;
            offset = obj.Kp_bal*delta_V/obj.Vdc;
            offset = max(min(offset, obj.max_offset), -obj.max_offset);
            ref_a = va_ref/(obj.Vdc/2) + offset;
            ref_b = vb_ref/(obj.Vdc/2) + offset;
            ref_c = vc_ref/(obj.Vdc/2) + offset;
            v_max = max([ref_a, ref_b, ref_c]);
            v_min = min([ref_a, ref_b, ref_c]);
            if v_max > 1, d = v_max-1; ref_a=ref_a-d; ref_b=ref_b-d; ref_c=ref_c-d; end
            if v_min < -1, d = -1-v_min; ref_a=ref_a+d; ref_b=ref_b+d; ref_c=ref_c+d; end
        end

        %% Three-level modulation with balance
        function [Sa, Sb, Sc] = three_level_modulation(obj, v_alpha, v_beta, Vup_meas, Vdn_meas)
            Vdc_half = obj.Vdc/2;
            va = v_alpha/Vdc_half;
            vb = (-0.5*v_alpha + sqrt(3)/2*v_beta)/Vdc_half;
            vc = (-0.5*v_alpha - sqrt(3)/2*v_beta)/Vdc_half;
            v_ofs = obj.zero_sequence_injection(Vup_meas, Vdn_meas, 0, 0, 0)/Vdc_half;
            va = va+v_ofs; vb = vb+v_ofs; vc = vc+v_ofs;
            Sa = obj.quantize_3level(va);
            Sb = obj.quantize_3level(vb);
            Sc = obj.quantize_3level(vc);
        end

        function level = quantize_3level(~, ref)
            if ref > 0.5, level = 1;
            elseif ref > -0.5, level = 0;
            else, level = -1; end
        end

        function [Vup_new, Vdn_new] = update_capacitor_voltage(obj, Sa, Sb, Sc, ia, ib, ic)
            i_p = (Sa==1)*ia + (Sb==1)*ib + (Sc==1)*ic;
            i_n = -(Sa==-1)*ia - (Sb==-1)*ib - (Sc==-1)*ic;
            obj.Vup = obj.Vup + i_p*obj.Ts/obj.C1;
            obj.Vdn = obj.Vdn + i_n*obj.Ts/obj.C2;
            Vup_new = obj.Vup; Vdn_new = obj.Vdn;
        end
    end
end
