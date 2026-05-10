# Power Electronics Core Control Algorithm Library

## Project Structure

```
FM/
├── core_functions/                  # Core function modules
│   ├── grid_connected_inverter.m       # Grid-connected inverter (PLL + dual-loop + SVPWM)
│   ├── black_start_controller.m        # Black start controller (V/f + soft-start)
│   ├── afe_rectifier.m                 # Active Front End rectifier (unity PF)
│   └── cccv_charger.m                  # CC/CV charging controller
│
├── advanced_algorithms/             # Advanced algorithm modules
│   ├── npc_midpoint_balance.m          # Three-level NPC midpoint balance
│   ├── islanding_detection.m           # Islanding detection (passive + active)
│   ├── circulating_current_suppressor.m  # Circulating current suppression (CCSC/PR/zero-seq)
│   ├── droop_control.m                 # Droop control (P-f/Q-V + virtual impedance)
│   ├── vsg_controller.m               # Virtual synchronous generator (swing eq + excitation)
│   └── multi_inverter_parallel.m       # Multi-inverter parallel coordination
│
├── simulink_models/                 # Simulink model builder scripts
│   ├── build_grid_connected_model.m    # Grid-connected inverter Simulink model
│   ├── build_vsg_model.m              # VSG simulation model
│   ├── build_cccv_model.m             # CCCV charging model
│   ├── build_npc_3level_model.m       # Three-level NPC model
│   └── build_droop_parallel_model.m   # Multi-inverter parallel model
│
├── simulation/                      # Pure MATLAB simulation scripts
│   └── run_all_simulations.m           # Comprehensive verification (no Simulink needed)
│
├── project/                         # Unified project integration layer
│   ├── config/
│   │   └── system_config.m            # Parameter center
│   ├── controller/
│   │   └── unified_power_controller.m # Mode orchestration and unified dispatch
│   └── integration/
│       └── build_integrated_system_model.m  # Top-level system model generator
│
├── simulation/integrated/
│   └── run_integrated_project_demo.m   # Unified project co-simulation script
│
├── run_integrated_project.m          # One-click build + test entry point
│
└── README.md
```

## Unified Integration Architecture

```mermaid
flowchart TB
  Grid["[Utility Grid]"] --- PCC[Grid Switch / PCC]
  PCC --- LCL[L/LCL Filter]
  LCL --- AFE["AFE 3-Level AC/DC<br/>(Grid Rectifier / Regen)"]
  AFE --- DCBUS["(DC Bus Vdc<br/>C1/C2 Midpoint N)"]
  DCBUS --- DCDC["Bidirectional DC/DC<br/>CCCV Charge/Discharge"]
  DCDC --- Batt["[Battery Pack]"]

  DCBUS --- INV["DC/AC Inverter<br/>(Grid-Forming)"]
  INV --- Load["[Island Load / Microgrid Bus]"]

  subgraph Control[Single Controller Firmware (DSP/MCU/FPGA)]
    PLL[PLL / Synchronization]:::c
    GFL["Grid-Following (GFL)<br/>dq Current PI"]:::c
    VdcLoop[Vdc Outer Loop PI -> id*]:::c
    NPV["3-Level Midpoint Balance<br/>Zero-Seq Injection / Redundant Vectors"]:::c
    AI["Islanding Detection<br/>Trip within 2s"]:::c
    GFM["Grid-Forming (GFM): Droop/VSG<br/>Voltage & Frequency Reference"]:::c
    VIMP[Virtual Impedance / Circ. Current Suppression]:::c
    PAR[Multi-Inverter Sync / Power Sharing]:::c
    CCCV[CCCV Mode Manager]:::c
  end

  PLL --> GFL --> AFE
  VdcLoop --> GFL
  NPV --> AFE
  AI --> PCC
  GFM --> INV
  VIMP --> INV
  PAR --> GFM
  CCCV --> DCDC

  classDef c fill:#eef,stroke:#446,stroke-width:1px;
```

---

## Module Descriptions

### Part I: Core Functions

#### 1. Grid-Connected Inverter (`grid_connected_inverter`)
- **Topology**: Three-phase two-level VSI + LCL filter
- **Control Strategy**: SRF-PLL -> Vdc voltage outer loop -> id/iq current inner loop -> SVPWM
- **Key Features**:
  - dq decoupled control, independent P/Q regulation
  - Grid voltage feedforward compensation
  - 7-sector SVPWM modulation with over-modulation handling

#### 2. Black Start Controller (`black_start_controller`)
- **Scenario**: No grid supply; storage/diesel builds microgrid voltage from zero
- **Control Strategy**: V/f master mode (voltage source behavior)
- **Key Features**:
  - Voltage ramp soft-start (linear 2s rise)
  - Voltage/current dual loop
  - Load switching capacity assessment

#### 3. Active Front End Rectifier (`afe_rectifier`)
- **Topology**: Three-phase PWM rectifier
- **Control Strategy**: VOC (Voltage Oriented Control)
- **Key Features**:
  - Unity power factor rectification (iq_ref=0)
  - DC bus voltage stabilization
  - Pre-charge logic

#### 4. CC/CV Charger (`cccv_charger`)
- **Application**: Lithium battery pack charging management
- **Control Strategy**: CC -> CV automatic switching + pre-charge
- **Key Features**:
  - Four stages: Standby -> Pre-charge -> CC -> CV -> Done
  - Over-voltage / over-current / over-temperature triple protection
  - Bumpless CC/CV transition

---

### Part II: Advanced Algorithms

#### 5. NPC Midpoint Balance (`npc_midpoint_balance`)
- **Method 1**: Zero-sequence voltage injection — PI controller computes offset
- **Method 2**: Redundant vector selection — adjusts positive/negative small-vector ratios
- **Method 3**: Carrier offset — shifts dual-carrier DC levels

#### 6. Islanding Detection (`islanding_detection`)
- **Passive Detection**: OVP/UVP, OFP/UFP, phase jump (ROCOF), THD
- **Active Detection**: AFD frequency drift, active power perturbation
- **NDZ**: Active + passive combination eliminates detection blind zone

#### 7. Circulating Current Suppression (`circulating_current_suppressor`)
- **MMC**: CCSC (negative-sequence 2nd harmonic dq-frame PI)
- **Parallel Inverters**: Zero-sequence PI + per-phase PR controller
- **PR Controller**: SOGI-based proportional-resonant, precise tracking of specific frequencies

#### 8. Droop Control (`droop_control`)
- **P-f Droop**: w = w0 - mp*(P - P_ref)
- **Q-V Droop**: V = V0 - nq*(Q - Q_ref)
- **Enhancements**: Virtual impedance, secondary regulation, adaptive droop

#### 9. Virtual Synchronous Generator (`vsg_controller`)
- **Swing Equation**: J*dw/dt = Tm - Te - D*(w - w0)
- **Excitation**: First-order inertia + Q-V droop
- **Advantage**: Provides virtual inertia, suppresses RoCoF

#### 10. Multi-Inverter Parallel (`multi_inverter_parallel`)
- **Strategy**: Sync detection -> Pre-sync control -> Breaker close -> Droop operation
- **Power Sharing**: Droop coefficients allocated inversely proportional to capacity
- **Advanced Features**: Hot-plug, virtual impedance matching, secondary regulation

---

## Quick Start

### Pure MATLAB Simulation (No Simulink Required)
```matlab
cd simulation
run_all_simulations
```

### Unified Project One-Click Entry
```matlab
cd FM
run_integrated_project
```

### Build Integrated Architecture Model Only
```matlab
addpath('project/integration')
build_integrated_system_model
```

### Generate Individual Simulink Models
```matlab
cd simulink_models
build_grid_connected_model    % Grid-connected inverter
build_vsg_model               % Virtual synchronous generator
build_cccv_model              % CCCV charging
build_npc_3level_model        % Three-level NPC
build_droop_parallel_model    % Multi-inverter parallel
```

### Use a Single Controller
```matlab
% Example: VSG controller
vsg = vsg_controller();
vsg.J = 5; vsg.D = 50;
[vd, vq, theta, omega] = vsg.control_step(P_ref, Q_ref, P_meas, Q_meas, ...
    V_meas, vd, vq, id, iq, iod, ioq);
```

---

## Requirements
- MATLAB R2024b (or later)
- Simulink (for model builder scripts)
- Simscape Electrical / Specialized Power Systems (for power circuit models)
