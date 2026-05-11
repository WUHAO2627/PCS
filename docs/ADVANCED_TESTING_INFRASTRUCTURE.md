# Multi-Load Island Test Platform & AFE Switching Model
## Advanced Testing Infrastructure for PCS

---

## Overview

This document describes two major enhancements:

1. **Multi-Load Island Test Platform**: An extended islanded load configuration that combines multiple load types into a single testbed
2. **AFE Switching-Level Model**: A high-fidelity switching-level rectifier implementation for control validation

---

## Part 1: Multi-Load Island Test Platform

### Architecture

The enhanced island load subsystem now contains three parallel load branches:

```
┌─ Base RL Load (always active)
├─ Step Load (engages at t=0.15s)
├─ Nonlinear Rectifier (6-pulse diode bridge)
└─ [Future] Motor Load (inductive machine simulation)
      │
      └─→ Sum → Island Load Current (Iabc)
```

### Load Components

#### 1. **Base RL Load** (Continuous)
- **Resistance**: R = 10 Ω
- **Inductance**: L = 5 mH
- **Purpose**: Steady-state AC load, nominal reference
- **Model**: First-order RL circuit with Euler integration
- **Equation**: 
  $$\frac{dI}{dt} = \frac{V - RI}{L}$$

#### 2. **Step Load** (Transient, t ≥ 0.15s)
- **Trigger**: Activates 150 ms into simulation
- **Resistance**: R = 15 Ω  
- **Inductance**: L = 3 mH
- **Current Jump**: ~50% increase in steady-state load
- **Purpose**: Tests inverter transient response, voltage sag recovery time
- **Application**: Validates islanding detection robustness

#### 3. **Nonlinear Rectifier Load**
- **Topology**: Three-phase diode bridge (6-pulse)
- **AC-side inductance**: L = 2 mH (with R = 0.5 Ω)
- **DC-side capacitor**: C = 1 mF  
- **DC-side resistance**: R = 20 Ω (load)
- **Diode forward drop**: Vf = 0.7V
- **Purpose**: 
  - Tests harmonic injection (6th, 12th, 18th harmonics)
  - Validates PLL robustness to distorted voltage
  - Requires active harmonic management or islanding detection tuning
- **Model Features**:
  - Simplified rectifier nonlinearity (conducts when AC > DC - Vf)
  - DC-side capacitor charging/discharging
  - AC current clipping based on DC voltage

#### 4. **Motor Load** (Optional, for future extension)
- **Not yet active** in default configuration
- **Planned model**: Induction motor with simple torque equation
- **Characteristics**: 
  - Back-EMF counter-voltage (`e = Ke·ω`)
  - Mechanical inertia and friction
  - Load torque + viscous damping

### Simulator Integration

**File**: [project/integration/build_integrated_system_model.m](../project/integration/build_integrated_system_model.m)  
**Function**: `populate_island_load(model_name)`

```matlab
% Example: Create integrated model with multi-load platform
build_integrated_system_model();

% Simulation will show:
% - 0 to 0.15s: Base RL load only (I_steady ~ 18 A RMS per phase)
% - 0.15s onward: Base RL + Step RL + Rectifier (total current ripple increases)
```

### Expected Behavior

| Time (s) | Load State | Expected DC Voltage Sag | Inverter Response |
|----------|-----------|----------------------|------------------|
| 0.00–0.15 | Base RL only | <2% | Steady |
| 0.15–0.20 | +Step transient | 5–8% sag | Transient recovery |
| 0.20+ | Steady (all 3 loads) | 3–5% AC-side ripple | Equilibrium with harmonics |

---

## Part 2: AFE Switching-Level Model

### Overview

A high-fidelity, component-level implementation of the 3-phase PFC rectifier with real IGBT switching dynamics.

**File**: [simulink_models/build_afe_switching_model.m](../simulink_models/build_afe_switching_model.m)  
**Model**: `afe_switching_rectifier.slx` (generated)

### Architecture

```
Grid (380V, 50Hz)
    ↓
[Series RL: ~Rac=1Ω, Lac=10mH]
    ↓
┌─── Phase A ──┐
├─── Phase B ──┼─→ Universal Bridge (IGBT + Diodes)
└─── Phase C ──┘  │  • 6 IGBTs + 6 Diodes  
                 │  • Ron = 0.01 Ω (ON resistance)
                 │  • Vf = 0.8 V (forward drop)
                 │  • Switching freq. = 10 kHz
                 │
                 ↓
            PWM Comparator
            (Carrier: △ 0-1, Ts=1e-5s)
                 │
                 ├─ Gate Gate A/B/C (6 signals)
                 │
                 ↓
        Split DC Bus (C1, C2 = 2350µF each)
               Total: 750V nominal
```

### Key Features

#### Power Stage
| Parameter | Value | Unit |
|-----------|-------|------|
| AC voltage (RMS, L-L) | 380 | V |
| Grid frequency | 50 | Hz |
| Series impedance (R+jωL) | 1Ω + j3.14Ω | — |
| IGBT module | Universal Bridge IGBT module | — |
| DC bus voltage | 750 | V |
| Split cap C1, C2 | 2350 | µF |
| NPC neutral point resistor | 0.1 | Ω |

#### Control
| Parameter | Description |
|-----------|-------------|
| **PLL** | Synchronous Reference Frame, PI (Kp=100, Ki=5000) |
| **Current Controller** | dq-axis dual loop, PI (Kp=10, Ki=100) |
| **DC Loop** | Voltage feedback, Vref = 750V |
| **PWM** | Center-aligned, 10 kHz carrier, deadtime = 500ns |
| **Reference** | Id_ref = 10A, Iq_ref = 0 (unity power factor) |

### Solver Configuration

For high-fidelity switching transients, the model uses **variable-step ODE**:

```matlab
set_param(model, 'Solver', 'ode23tb');  % Stiff equation solver
set_param(model, 'MaxStep', '1e-5');     % Max 100 kHz resolution
set_param(model, 'RelTol', '1e-4');      % 0.01% relative tolerance
set_param(model, 'AbsTol', '1e-6');      % Absolute tolerance
```

**Why ode23tb?**
- Implicit integration handles stiff switching transients (ns-level events)
- Adaptive time-step captures both fast (10 kHz PWM) and slow (50 Hz grid) dynamics
- More efficient than fixed 1-microsecond solver for this application

### Observable Signals

1. **Three-phase AC voltage** (V_abc): Distorted by grid impedance
2. **Three-phase AC current** (I_abc): PWM rectifier input current waveforms
3. **DC voltage upper/lower** (Vdc_1, Vdc_2): Split bus voltage ripple (~2-3%)
4. **Gate signals** (G_A, G_B, G_C): 10 kHz PWM duty cycles
5. **Switching frequency harmonics**: Up to ~50 kHz measurable

### Comparison: Average vs. Switching

| Aspect | Average Model (10 kHz) | Switching Model (100+ kHz) |
|--------|------------------------|--------------------------|
| **Solver** | FixedStepDiscrete | ode23tb variable-step |
| **Time step** | 1e-4 s | ~1e-5 s (adaptive) |
| **Components** | Transfer functions | IGBT + Diodes + Snubbers |
| **Harmonics visible** | Up to 10 kHz | Up to 50+ kHz |
| **Switching losses** | Averaged out | Explicit (conduction + switching) |
| **Use case** | System-level control | Component verification, EMI prediction |

### Simulation Example

```matlab
% Build and run switching model
build_afe_switching_model();
model = 'afe_switching_rectifier';
sim(model, 'StopTime', 0.1, 'Solver', 'ode23tb', 'MaxStep', 1e-5);

% Expected results:
% - Vdc ripple: 5–10 V peak (average version: ~50 V)
% - AC current THD: ~6–8% (typical for 3-phase PWM rectifier)
% - Switching transient settling: <1 ms
% - IGBT loss = ~200 W typical operation
```

---

## Test & Validation

### Running Both Models

```matlab
% Execute comprehensive test:
test_advanced_models();
```

**This will:**
1. Rebuild integrated model with new island load
2. Simulate integrated model (0.5 s, full system operation)
3. Build AFE switching model
4. Simulate AFE model (0.1 s, high resolution)

### Scope Captures to Verify

**Integrated Model Scopes:**
- `Scope_Vdc`: DC bus voltage (should show ripple increase at t=0.15s)
- `Scope_Iabc`: Grid AC current (should show harmonic spikes from rectifier load)
- `Scope_Batt`: Battery voltage/current (CCCV charging activity)

**AFE Switching Model Scopes:**
- AC voltage and current (single-sided power spectrum analyzer)
- DC voltage ripple
- Gate signals (verify PWM at 10 kHz)

---

## Future Extensions

### Short Term
- [ ] Add DC-side fault current limiter (series resistance or active control)
- [ ] Implement active harmonic filter or SRF controller to suppress 5th/7th harmonics
- [ ] Build similar switching models for DCDC and Inverter

### Medium Term
- [ ] Motor/compressor load model (for thermal/mechanical simulations)
- [ ] Real-time hardware-in-loop (HIL) with TI C2000 or dSPACE
- [ ] Fault injection: phase loss, DC bus collapse, component faults

### Long Term
- [ ] Three-phase imbalance/unbalance scenarios
- [ ] Dynamic harmonic sweep for frequency response
- [ ] Thermal modeling: IGBT junction temperature vs. switching loss
- [ ] Formal small-signal analysis: eigenvalue stability margins

---

## References

- **IEC 61000-3-2**: Limits and methods of measurement of radio disturbance characteristics of industrial, scientific, medical (ISM) RF equipment
- **IEEE 519**: IEEE Recommended Practice and Requirements for Harmonic Control in Electric Power Systems
- **Mattavelli et al. (2002)**: Digital Control of High-Power Converters
- **Erickson & Maksimovic (2001)**: Fundamentals of Power Electronics

---

## Authors & Revision

| Date | Version | Changes |
|------|---------|---------|
| 2025-01-15 | v1.0 | Initial multi-load platform + AFE switching model |

