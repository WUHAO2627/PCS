# Simulink Model Integration Guide

## Overview

This guide describes how the MATLAB algorithms in this repository map into Simulink models. The focus is on readable structure, clear signal flow, and maintainable integration.

## 1. Model Architecture

### 1.1 Three-Layer Layout

The integrated model is organized into three layers:

```text
┌─────────────────────────────────────────┐
│           CONTROL_STAGE                 │  Yellow
│  PLL | Grid_Follower | Grid_Former      │
└──────────────┬──────────────────────────┘
               │ Control commands
┌──────────────▼──────────────────────────┐
│            POWER_STAGE                  │  Green
│  Grid -> PCC -> LCL -> AFE -> DC Bus    │
└──────────────┬──────────────────────────┘
               │ Power measurements
┌──────────────▼──────────────────────────┐
│            MEASUREMENTS                 │  Blue
│  Sensors | Signal conditioning          │
└─────────────────────────────────────────┘
```

### 1.2 Color Coding

| Color | RGB | Purpose | Example |
|------|-----|---------|---------|
| Light blue | [0.6, 0.8, 1.0] | Sensors and sources | `AC_Grid`, `MEASUREMENTS` |
| Light green | [0.7, 1.0, 0.7] | Power conversion blocks | `DC_BUS`, `Battery`, `Inverter` |
| Light yellow | [1.0, 1.0, 0.7] | Control logic | `PLL`, `Grid_Follower`, `AFE_Stage` |
| Light orange | [1.0, 0.8, 0.6] | Decision blocks | `PCC_Breaker` |
| Light red | [1.0, 0.8, 0.8] | Sinks or unused outputs | Not used |

## 2. POWER_STAGE Structure

### 2.1 AC Power Path

```text
AC_Grid (source, blue)
   |
   +--> PCC_Breaker (breaker, orange)
   |
   +--> LCL_Filter (filter network, green)
   |      - L1 = 3 mH (input-side inductor)
   |      - Cf = 10 uF (filter capacitor)
   |      - L2 = 0 (simplified single-inductor model)
   |
   +--> AFE_Stage (three-phase rectifier, yellow)
          - Three-phase PWM rectifier
          - Average-value model
          - Outputs Idc to DC_BUS
```

### 2.2 DC Power Path, Main Branch

```text
AFE_Stage -> Idc
   |
   +--> DC_BUS (split capacitors, green)
   |      - C1 = 4700 uF (upper capacitor)
   |      - C2 = 4700 uF (lower capacitor)
   |      - Midpoint balancing
   |
   +--> DCDC_Converter (bidirectional buck-boost, yellow)
   |      - Input: Vdc from DC_BUS
   |      - Output: Ibatt to battery
   |
   +--> Battery (battery model, green)
          - Open-circuit voltage: Voc = 360 V for 100 cells
          - Internal resistance: Rint = 0.001 ohm/cell
          - SOC tracking
```

### 2.3 DC Power Path, Island Branch

```text
DC_BUS
   |
   +--> DC_Inverter (inverter, yellow)
   |      - Input: Vdc
   |      - Output: three-phase AC voltage
   |      - PWM average-value model
   |
   +--> Island_Load (island load, green)
          - Base RL load
          - Step load at t = 0.15 s
          - Rectifier load
          - Total island current output
```

## 3. CONTROL_STAGE Structure

### 3.1 Core Control Modules

```text
PLL_SRF
  - Input: three-phase AC voltage
  - Method: synchronous reference frame PLL with PI control
  - Output: phase angle theta
  - Gains: Kp = 100, Ki = 5000

Grid_Follower
  - Input: measured current, grid voltage, theta
  - Method: dq current control with outer voltage loop
  - Gains: Kp = 10, Ki = 100
  - Output: AFE PWM duty cycles

Grid_Former
  - Input: DC bus voltage and references
  - Method: VSG and droop control
  - Output: inverter PWM duty cycles
```

### 3.2 Signal Flow

```text
MEASUREMENTS
   |
   +--> PLL_SRF
   |      -> theta -> Grid_Follower
   |
   +--> Grid_Follower
   |      -> PWM_AFE -> POWER_STAGE/AFE_Stage
   |
   +--> Grid_Former
          -> PWM_INV -> POWER_STAGE/DC_Inverter
```

## 4. MATLAB to Simulink Mapping

### 4.1 Grid-Connected Inverter

MATLAB class: [core_functions/grid_connected_inverter.m](../core_functions/grid_connected_inverter.m)

Simulink location: `Grid_Follower` inside `CONTROL_STAGE`

| MATLAB method | Simulink block | Purpose |
|--------------|----------------|---------|
| `clarke()` | MATLAB Function block | Alpha-beta transform |
| `park()` | MATLAB Function block | DQ transform |
| `pll_update()` | `PLL_SRF.PLL` | Phase synchronization |
| `current_loop()` | `Grid_Follower.GFL` | Current control |
| `svpwm_gen()` | MATLAB Function block | PWM generation |

Example:

```matlab
plant = grid_connected_inverter();
[alpha, beta] = plant.clarke(ia, ib, ic);
[d, q] = plant.park(alpha, beta, theta);
```

### 4.2 AFE Rectifier

MATLAB class: [core_functions/afe_rectifier.m](../core_functions/afe_rectifier.m)

Simulink location: `AFE_Stage` inside `POWER_STAGE`

```text
Vabc
  -> Clarke transform
  -> PLL -> theta
  -> Park transform
  -> d-axis voltage loop -> id_ref
  -> q-axis power-factor target -> iq_ref
  -> dq PI control with decoupling
  -> inverse Park transform
  -> SVPWM -> PWM_abc
```

### 4.3 CCCV Charger

MATLAB class: [core_functions/cccv_charger.m](../core_functions/cccv_charger.m)

Simulink location: `DCDC_Converter` control logic

```text
Standby
  -> Check battery voltage
  -> CC mode (Iref = 50 A)
  -> CV mode (Vref = 420 V)
```

## 5. Readability Best Practices

### 5.1 Naming Convention

Subsystem names:

- `POWER_STAGE`, `CONTROL_STAGE`, `MEASUREMENTS`
- `AC_Grid`, `LCL_Filter`, `AFE_Stage`, `DC_BUS`
- `PLL_SRF`, `Grid_Follower`, `Grid_Former`

Signal names:

- Three-phase AC: `Vabc`, `Iabc`
- DC signals: `Vdc`, `Idc`
- Reference values: suffix `_ref`
- Measured values: suffix `_meas`
- Internal states: prefix `state_`

### 5.2 Comments and Documentation

Use short, factual comments:

```matlab
%% ===== Block Name =====
% Purpose: brief description of the block
% Inputs:  signal1, signal2, ...
% Outputs: output signal(s)
%
% Algorithm:
% 1. Step one
% 2. Step two

function output = myblock(input1, input2)
    %#codegen
    % Implementation here
end
```

### 5.3 Signal Labels and Connections

Keep important signal labels visible in Simulink. Clear labels make debugging and traceability easier.

### 5.4 Block Appearance

Use consistent colors and simple annotations. Avoid styling that does not help debugging.

## 6. Integration Workflow

### 6.1 From MATLAB Class to Simulink Block

Step 1: Extract the algorithm

```matlab
alg = grid_connected_inverter();
```

Step 2: Move the core logic into a MATLAB Function block

```matlab
function output = algorithm_fcn(input)
    %#codegen
    persistent state
    if isempty(state)
        state = initial_value;
    end

    output = input;
    state = next_state;
end
```

Step 3: Organize the block into a subsystem

```matlab
add_block('simulink/Ports & Subsystems/Subsystem', [model '/Core_Algorithm']);
```

### 6.2 Verification

Compare the MATLAB class output against the Simulink model output and check the maximum error.

```matlab
error = MATLAB_output - Simulink_output;
max_error = max(abs(error));
```

## 7. Advanced Topics

### 7.1 Common Problems

1. Algebraic loops
   - Symptom: Simulink reports an algebraic loop
   - Fix: insert a Unit Delay or equivalent sample delay

2. Numerical instability
   - Symptom: simulation drifts or blows up
   - Fix: add saturation and anti-windup to PI controllers

3. Slow simulation
   - Symptom: long run times
   - Fix: reduce nested hierarchy where possible, or use accelerator mode

### 7.2 Code Generation

```matlab
set_param(gcs, 'TargetLang', 'C');
set_param(gcs, 'PortableWordSizes', 'on');
rtwbuild('model_name');
```

### 7.3 Hardware-in-the-Loop

```matlab
set_param('model', 'SimulationMode', 'External');
set_param('model', 'ExternalModeTransportLayer', 'Serial');
```

## 8. File Structure Summary

```text
FM/
├── simulink_models/
│   ├── build_pcs_model_enhanced.m
│   ├── build_integrated_system_model.m
│   ├── build_afe_switching_model.m
│   └── ...
│
├── core_functions/
│   ├── grid_connected_inverter.m
│   ├── afe_rectifier.m
│   ├── black_start_controller.m
│   └── cccv_charger.m
│
└── docs/
    ├── SIMULINK_INTEGRATION_GUIDE.md
    └── ADVANCED_TESTING_INFRASTRUCTURE.md
```

## 9. Migration Checklist

- All 10 algorithm modules are integrated
- Main blocks have consistent color coding
- Signal labels are clear and consistent
- Key parameters are documented
- State machines are visible
- Feedback paths are validated
- Unit tests pass
- Documentation matches the current model
- The model runs in R2024b
- Demo simulations complete successfully

## 10. Quick Start

```matlab
build_pcs_model_enhanced();
open('integrated_energy_system_enhanced');
set_param('integrated_energy_system_enhanced', 'StopTime', '0.5');
sim('integrated_energy_system_enhanced');
Simulink.sdi.view();
```
