# Module Flowchart Files - Separate Mermaid Diagrams

This directory contains individual Mermaid flowchart files for each PCS control module.

## Why Separate Files?

Each module is defined in its own `.mmd` file for:
1. **Better rendering**: Direct Mermaid support on GitHub and VS Code extensions
2. **Easier viewing**: Open any file directly in a Mermaid viewer
3. **Independent maintenance**: Update diagrams without affecting other modules

## File Listing

### Core Functions

| File | Module | Purpose |
|------|--------|---------|
| [01_grid_connected_inverter.mmd](01_grid_connected_inverter.mmd) | grid_connected_inverter | Grid-following PQ control via PLL + dq loops |
| [02_black_start_controller.mmd](02_black_start_controller.mmd) | black_start_controller | Island voltage buildup, V/f soft-start |
| [03_afe_rectifier.mmd](03_afe_rectifier.mmd) | afe_rectifier | AC-to-DC power processing with unity PF |
| [04_cccv_charger.mmd](04_cccv_charger.mmd) | cccv_charger | Battery charging with 4-stage state machine |

### Advanced Algorithms

| File | Module | Purpose |
|------|--------|---------|
| [05_npc_midpoint_balance.mmd](05_npc_midpoint_balance.mmd) | npc_midpoint_balance | 3-level inverter neutral point stabilization |
| [06_islanding_detection.mmd](06_islanding_detection.mmd) | islanding_detection | Grid disconnection detection (passive + active) |
| [07_circulating_current_suppressor.mmd](07_circulating_current_suppressor.mmd) | circulating_current_suppressor | MMC/parallel inverter circulating suppression |
| [08_droop_control.mmd](08_droop_control.mmd) | droop_control | Primary frequency/voltage regulation |
| [09_vsg_controller.mmd](09_vsg_controller.mmd) | vsg_controller | Virtual synchronous machine emulation |
| [10_multi_inverter_parallel.mmd](10_multi_inverter_parallel.mmd) | multi_inverter_parallel | Synchronization and power sharing |

## How to View

### Option 1: GitHub
Upload any `.mmd` file to a GitHub repository. GitHub automatically renders Mermaid diagrams in the web interface.

### Option 2: VS Code
1. Install "Markdown Preview Enhanced" or "Mermaid" extension
2. Open the `.mmd` file in VS Code
3. Right-click → "Preview" or press `Ctrl+Shift+V`

### Option 3: Online Mermaid Editor
Paste the contents of any `.mmd` file into [mermaid.live](https://mermaid.live)

### Option 4: Print/Export
Use the Mermaid editor to export as PNG, SVG, or PDF for presentations/documentation.

## Integrated Document

For an overview with all diagrams in one place, see [module_flowcharts.md](../module_flowcharts.md).

## Maintenance

When updating control logic:
1. Identify which module(s) changed
2. Update the corresponding `.mmd` file(s)
3. Optionally update the summary in `module_flowcharts.md`

## Technical Notes

- **Diagram type**: Flowchart (TD = top-down layout)
- **Syntax**: Mermaid v10+
- **File encoding**: UTF-8 (no special characters)
