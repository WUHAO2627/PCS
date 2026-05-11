# PCS Module Flowcharts

This document summarizes the control logic of each core function and advanced algorithm module.

Core functions and advanced algorithms are organized below with flowchart diagrams showing decision logic and signal flow.

---

## Core Functions

### 1. grid_connected_inverter

```mermaid
flowchart TD
    A["Measure ia ib ic<br/>and grid voltages"] --> B["Clarke<br/>transform"]
    B --> C["SRF PLL<br/>estimate theta"]
    C --> D["Park transform<br/>currents and voltages"]
    D --> E["Vdc outer loop<br/>generates id_ref"]
    E --> F["iq_ref set by<br/>reactive power target"]
    F --> G["dq current PI<br/>with decoupling<br/>and grid feedforward"]
    G --> H["Inverse Park<br/>transform"]
    H --> I["SVPWM duty<br/>generation"]
    I --> J["Drive grid-connected<br/>inverter"]
```

---

### 2. black_start_controller

```mermaid
flowchart TD
    A["Start black start<br/>command"] --> B["Initialize state<br/>and timers"]
    B --> C["Generate free-running<br/>angle at nominal<br/>frequency"]
    C --> D["Soft-start<br/>voltage ramp"]
    D --> E["Measure capacitor<br/>voltage and filter<br/>current"]
    E --> F["Clarke and Park<br/>transforms"]
    F --> G["Voltage outer loop<br/>gives id_ref iq_ref"]
    G --> H["Current inner loop<br/>gives ud_ref uq_ref"]
    H --> I["Inverse Park and<br/>linear modulation"]
    I --> J["Build island voltage<br/>from zero"]
```

---

### 3. afe_rectifier

```mermaid
flowchart TD
    A["Measure AC currents<br/>and grid voltages"] --> B["Alpha beta<br/>transform"]
    B --> C["PLL update<br/>theta"]
    C --> D["Transform to<br/>dq frame"]
    D --> E["DC bus voltage loop<br/>computes id_ref"]
    E --> F["Power factor target<br/>computes iq_ref"]
    F --> G["dq current loop<br/>with decoupling"]
    G --> H["Inverse transform<br/>to alpha beta"]
    H --> I["Generate three<br/>duty commands"]
    I --> J["Rectify power<br/>to DC bus"]
```

---

### 4. cccv_charger

```mermaid
flowchart TD
    A["Read Vbatt<br/>Ibatt Tbatt"] --> B["Protection<br/>check"]
    B -->|fault| C["Stop charging<br/>duty = zero"]
    B -->|safe| D{{"Charging<br/>state?"}}
    D -->|Standby| E["Duty = zero"]
    D -->|Precharge| F["Current PI<br/>at low current"]
    D -->|CC| G["Current PI<br/>at Icc"]
    D -->|CV| H["Voltage PI<br/>gives current<br/>reference"]
    H --> I["Current PI<br/>tracks taper<br/>current"]
    F --> J["State transition<br/>logic"]
    G --> J
    I --> J
    J --> K["Update Ah and<br/>charging time"]
```

---

## Advanced Algorithms

### 5. npc_midpoint_balance

```mermaid
flowchart TD
    A["Measure upper and<br/>lower capacitor<br/>voltages"] --> B["Compute<br/>delta V"]
    B --> C["PI balancing<br/>controller"]
    C --> D["Generate zero-<br/>sequence offset"]
    D --> E["Inject offset into<br/>three-phase<br/>references"]
    E --> F["Three-level<br/>quantization or<br/>carrier offset"]
    F --> G["Adjust<br/>switching states"]
    G --> H["Reduce midpoint<br/>voltage imbalance"]
```

---

### 6. islanding_detection

```mermaid
flowchart TD
    A["Read Vrms<br/>frequency theta<br/>and sampled<br/>voltage"] --> B{"Voltage<br/>window?"}
    B -->|trip| C["Declare island<br/>and open PCC"]
    B -->|no trip| D{"Frequency<br/>window?"}
    D -->|trip| C
    D -->|no trip| E{"Phase jump or<br/>ROCOF?"}
    E -->|trip| C
    E -->|no trip| F["Active frequency<br/>drift injection"]
    F --> G{{"Frequency<br/>deviation<br/>enlarged?"}}
    G -->|yes| C
    G -->|no| H["Remain<br/>grid-connected"]
```

---

### 7. circulating_current_suppressor

```mermaid
flowchart TD
    A["Measure arm currents<br/>or inverter phase<br/>currents"] --> B{{"MMC or<br/>parallel?"}}
    B -->|MMC| C["Extract<br/>circulating current"]
    C --> D["Transform to<br/>negative-sequence<br/>2w dq frame"]
    D --> E["PI controller<br/>with decoupling"]
    E --> F["Back transform to<br/>abc compensation"]
    B -->|Parallel| G["Compute zero-<br/>sequence current"]
    G --> H["Zero-sequence PI<br/>suppression"]
    H --> I["Per-phase PR<br/>resonant controller"]
    I --> F
    F --> J["Inject compensation<br/>voltage"]
```

---

### 8. droop_control

```mermaid
flowchart TD
    A["Measure output<br/>voltage and<br/>current"] --> B["Calculate<br/>P and Q"]
    B --> C["Low-pass<br/>filter power"]
    C --> D["Primary droop<br/>P-f and Q-V"]
    D --> E["Optional adaptive<br/>droop update"]
    E --> F["Secondary voltage<br/>and frequency<br/>restoration"]
    F --> G["Compute virtual<br/>impedance drop"]
    G --> H["Generate voltage<br/>reference and<br/>omega_ref"]
    H --> I["Feed grid-forming<br/>voltage controller"]
```

---

### 9. vsg_controller

```mermaid
flowchart TD
    A["Read P_ref Q_ref<br/>P_meas Q_meas<br/>and voltage<br/>current states"] --> B["Swing equation<br/>update omega<br/>and theta"]
    B --> C["Excitation control<br/>updates internal<br/>emf"]
    C --> D["Voltage outer loop<br/>computes id_ref<br/>iq_ref"]
    D --> E["Current inner loop<br/>computes<br/>modulation voltage"]
    E --> F["Output dq<br/>modulation<br/>commands"]
    F --> G["Emulate synchronous<br/>machine inertia<br/>and damping"]
```

---

### 10. multi_inverter_parallel

```mermaid
flowchart TD
    A["Measure inverter<br/>and bus voltage<br/>frequency phase"] --> B{"Check sync<br/>windows<br/>dV df dphi?"}
    B -->|not synced| C["Pre-sync PI<br/>adjusts phase<br/>and frequency"]
    C --> D["Wait sync<br/>hold time"]
    D --> E["Close<br/>contactor"]
    B -->|synced| E
    E --> F["Compute expected<br/>power share<br/>from ratings"]
    F --> G["Power sharing<br/>PI correction"]
    G --> H["Optional hot-plug<br/>ramp and virtual<br/>impedance"]
    H --> I["Adjusted Pref<br/>and Qref for<br/>each inverter"]
```

---

## Recommended Load Models for Islanded Operation

```mermaid
flowchart TD
    A["Islanded AC bus"] --> B["Base RL load"]
    A --> C["Motor load for<br/>inrush and dynamics"]
    A --> D["Rectifier or nonlinear<br/>load for harmonics"]
    A --> E["Step load for<br/>disturbance testing"]
    A --> F["Unbalanced<br/>single-phase branch"]
    A --> G["Constant power<br/>ZIP load"]
```

---

## Quick Reference: Module Purposes

| Module | Key Function | Domain |
|--------|--------------|--------|
| grid_connected_inverter | Grid-following PQ control via PLL + dq current loops | AC bus |
| black_start_controller | Island voltage buildup, V/f soft-start | AC bus |
| afe_rectifier | AC-to-DC power processing with unity PF | AC/DC |
| cccv_charger | Battery charging with 4-stage state machine | DC charging |
| npc_midpoint_balance | 3-level inverter neutral point stabilization | DC midpoint |
| islanding_detection | Grid disconnection detection (passive + active) | System protection |
| circulating_current_suppressor | MMC or parallel inverter circulating current reduction | AC/DC |
| droop_control | Primary frequency/voltage regulation | Microgrid |
| vsg_controller | Virtual synchronous machine emulation | Microgrid AC |
| multi_inverter_parallel | Synchronization and power sharing between units | Microgrid |


