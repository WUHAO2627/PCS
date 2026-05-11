# PCS Control Library

MATLAB/Simulink project for power conversion control algorithms and integrated system simulation.

## Contents

- `core_functions/`: core controllers (grid-connected inverter, black start, AFE, CCCV)
- `advanced_algorithms/`: advanced control modules (NPC balance, islanding detection, droop, VSG, etc.)
- `project/`: integration scripts and unified controller
- `simulation/`: standalone MATLAB simulations
- `simulink_models/`: Simulink model files
- `docs/`: integration notes and flowcharts

## Quick Start

From project root:

```matlab
run_integrated_project
```

This script:

1. Adds required paths
2. Builds/updates the integrated model
3. Runs `simulation/integrated/run_integrated_project_demo.m`

## Useful Commands

Run algorithm-level MATLAB simulations:

```matlab
cd simulation
run_all_simulations
```

Run integrated test script:

```matlab
test_advanced_models
```

Build integrated model only:

```matlab
addpath('project/integration')
build_integrated_system_model
```

## Requirements

- MATLAB R2024b or later
- Simulink
- Simscape Electrical (for power-system blocks)

## Notes

- The repository currently keeps both source scripts and generated `.slx` model files.
- Detailed module flowcharts are in `docs/module_flowcharts.md` and `docs/flowcharts/`.
