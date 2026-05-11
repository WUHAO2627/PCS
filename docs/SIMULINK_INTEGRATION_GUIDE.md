# Simulink 模型集成与易读性改进指南

## 概述

本指南说明如何将所有MATLAB算法集成到Simulink模型中，以提高代码易读性和维护性。

---

## 1. 模型架构改进

### 1.1 三层设计

新的增强模型采用**三层分层架构**：

```
┌─────────────────────────────────────────┐
│      CONTROL_STAGE (控制层)              │ ← 黄色 (Yellow)
│  PLL | Grid-Follower | Grid-Former     │
└──────────────┬──────────────────────────┘
               │ Control Commands
┌──────────────▼──────────────────────────┐
│      POWER_STAGE (功率转换层)             │ ← 绿色 (Green)
│  Grid→PCC→LCL→AFE→DC_BUS→Setup→Load   │
└──────────────┬──────────────────────────┘
               │ Power Measurements
┌──────────────▼──────────────────────────┐
│    MEASUREMENTS (测量反馈层)             │ ← 蓝色 (Blue)
│  Sensors | Signal Conditioning          │
└─────────────────────────────────────────┘
```

### 1.2 颜色编码系统

| 颜色 | RGB | 用途 | 示例 |
|------|-----|------|------|
| 浅蓝 | [0.6, 0.8, 1.0] | 传感器/信号源 | AC_Grid, MEASUREMENTS |
| 浅绿 | [0.7, 1.0, 0.7] | 功率变换 | DC_BUS, Battery, Inverter |
| 浅黄 | [1.0, 1.0, 0.7] | 控制逻辑 | PLL, Grid-Follower, AFE_Stage |
| 浅橙 | [1.0, 0.8, 0.6] | 决策块 | PCC_Breaker |
| 浅红 | [1.0, 0.8, 0.8] | 输出/Sink | 未使用 |

---

## 2. POWER_STAGE 结构详解

### 2.1 AC 功率路径

```
AC_Grid (信号源, 蓝色)
   │
   ├─→ PCC_Breaker (断路器, 橙色)
   │
   ├─→ LCL_Filter (滤波网络, 绿色)
   │   • L1 = 3 mH (入射侧电感)
   │   • Cf = 10 µF (中点电容)
   │   • L2 = 0 (简化为单电感)
   │
   ├─→ AFE_Stage (三相整流, 黄色)
   │   • 三相 PWM 整流器
   │   • 平均值模型
   │   • 输出 Idc 到 DC_BUS
```

### 2.2 DC 功率路径 - 主路径

```
AFE_Stage → Idc
   │
   ├─→ DC_BUS (分离式电容, 绿色)
   │   • C1 = 4700 µF (上轨)
   │   • C2 = 4700 µF (下轨)
   │   • Vdc_midpoint 中点平衡
   │
   ├─→ DCDC_Converter (双向降压-升压, 黄色)
   │   • 输入: Vdc (从 DC_BUS)
   │   • 输出: Ibatt (送电池)
   │
   ├─→ Battery (电池模型, 绿色)
   │   • 开路电压: Voc = 360V (100 节)
   │   • 内阻: Rint = 0.001 Ω/cell
   │   • SOC 追踪
```

### 2.3 DC 功率路径 - 孤岛路径

```
DC_BUS
   │
   ├─→ DC_Inverter (逆变器, 黄色)
   │   • 输入: Vdc
   │   • 输出: 三相 AC 电压
   │   • PWM 平均值模型
   │
   ├─→ Island_Load (孤岛负载, 绿色)
       • Base RL Load (基础 RL 负载)
       • Step Load (阶跃负载, t=0.15s)
       • Rectifier Load (非线性整流负载)
       • 输出: 总岛屿电流
```

---

## 3. CONTROL_STAGE 结构详解

### 3.1 核心控制模块

每个模块对应一个核心的控制功能：

```
┌─ PLL_SRF (PLL 同步锁相环)
│  • 输入: 三相 AC 电压
│  • 算法: 同步参考框 (SRF) + PI 控制器
│  • 输出: 相角 θ
│  • Kp = 100, Ki = 5000
│
├─ Grid_Follower (并网电流跟踪控制)
│  • 输入: 测量信号 (Iabc, Vgrid, θ)
│  • 算法: dq 双环控制 (外电压环, 内电流环)
│  • Kp_id/iq = 10, Ki_id/iq = 100
│  • 输出: AFE PWM 占空比
│
└─ Grid_Former (孤岛电压形成)
   • 输入: DC 母线电压, 参考值
   • 算法: VSG + Droop 控制
   • 输出: 逆变器 PWM 占空比
```

### 3.2 信号流

```
MEASUREMENTS (传感器反馈)
   │ [Vgrid, Igrid, Vdc, Vbatt, ...]
   │
   ├─→ PLL_SRF
   │   └─ θ → Grid_Follower
   │
   ├─→ Grid_Follower
   │   └─ PWM_AFE → POWER_STAGE/AFE_Stage
   │
   └─→ Grid_Former
       └─ PWM_INV → POWER_STAGE/DC_Inverter
```

---

## 4. MATLAB 类到 Simulink 的映射

### 4.1 Grid Connected Inverter

**MATLAB 类**: [core_functions/grid_connected_inverter.m](../core_functions/grid_connected_inverter.m)

**Simulink 位置**: `Grid_Follower` (CONTROL_STAGE 中)

**映射关系**:

| MATLAB 方法 | Simulink 块 | 说明 |
|-----------|-----------|------|
| `clarke()` | MATLAB Function 内联 | α-β 变换 |
| `park()` | MATLAB Function 内联 | d-q 变换 |
| `pll_update()` | PLL_SRF.PLL | PLL 同步 |
| `current_loop()` | Grid_Follower.GFL | 电流 PI 控制 |
| `svpwm_gen()` | MATLAB Function | PWM 生成 |

**代码示例**:

```matlab
% MATLAB 类中:
plant = grid_connected_inverter();
[alpha, beta] = plant.clarke(ia, ib, ic);
[d, q] = plant.park(alpha, beta, theta);

% Simulink 中对应的 MATLAB Function 块:
function [d, q] = park_transform(alpha, beta, theta)
    d = alpha * cos(theta) + beta * sin(theta);
    q = -alpha * sin(theta) + beta * cos(theta);
end
```

### 4.2 AFE Rectifier

**MATLAB 类**: [core_functions/afe_rectifier.m](../core_functions/afe_rectifier.m)

**Simulink 位置**: `AFE_Stage` (POWER_STAGE 中)

**信号流**:

```
Vabc (AC 电压)
  │
  ├─ α-β 变换 (Clarke)
  │
  ├─ PLL 相位锁定 → θ
  │
  ├─ d-q 变换 (Park)
  │
  ├─ d 元: 电压环 (PI)
  │  └─ Vdc_ref → Vdc 反馈 → id_ref
  │
  ├─ q 元: 功率因数目标
  │  └─ PF_ref = 0.95 → iq_ref = 0
  │
  ├─ d-q PI 控制 (解耦)
  │
  ├─ 逆 Park 变换 → Va*_ref, Vb*_ref, Vc*_ref
  │
  └─ SVPWM → PWM_abc
```

### 4.3 CCCV Charger

**MATLAB 类**: [core_functions/cccv_charger.m](../core_functions/cccv_charger.m)

**Simulink 位置**: `DCDC_Converter` (POWER_STAGE 中) 的控制逻辑

**状态机**:

```
State = Standby (等待)
  │
  ├─ Check → Vbatt < Vmin_CCCV
  │
  ├─ State = CC (恒流充电)
  │  • Iref = Icc = 50 A
  │  • PI 控制 Duty 以跟踪电流
  │
  └─ State = CV (恒压充电)
     • Vref = Vmax_CV = 420 V
     • PI 控制电流使其缓慢下降
```

---

## 5. 易读性最佳实践

### 5.1 命名规范

**Subsystem 命名**:
- 大写: `POWER_STAGE`, `CONTROL_STAGE`, `MEASUREMENTS`
- 功能模块: `AC_Grid`, `LCL_Filter`, `AFE_Stage`, `DC_BUS`
- 控制块: `PLL_SRF`, `Grid_Follower`, `Grid_Former`

**Signal 命名** (信号标签):
- AC 三相: `Vabc`, `Iabc`
- DC: `Vdc`, `Idc`
- 参考值: 后缀 `_ref`
- 测量值: 后缀 `_meas`
- 状态: 前缀 `state_`

### 5.2 注释与文档

**代码注释模板**:

```matlab
%% ===== [Block Name] =====
% Purpose: 简要说明此块的功能
% Inputs:  信号1, 信号2, ...
% Outputs: 输出信号 ...
% 
% Algorithm:
% 1. 第一步
% 2. 第二步
%
% Example: 使用示例或参数值

function output = myblock(input1, input2)
    %#codegen
    % Implementation here
end
```

### 5.3 信号标签与连接

**在 Simulink 中添加信号标签**:

```matlab
% 后期添加标签
set_line_label(gcb, 'line_handle', 'Signal_Name');
```

**使用 LabelAccess**:
- 使每条关键信号都有清晰的标签
- 防止歧义
- 便于调试

### 5.4 Block 外观配置

```matlab
% 设置 Subsystem 颜色和样式
set_param([model_name '/POWER_STAGE'], ...
    'ForegroundColor', '[0.7 1.0 0.7]', ...  % 浅绿
    'BackgroundColor', '[0.9 1.0 0.9]', ...  % 背景
    'Opaque', 'off');

% 添加文本注释
add_text_annotation(model, 'This is a description', [x y]);
```

---

## 6. 集成工作流

### 6.1 从 MATLAB 类到 Simulink

步骤 1: **提取关键算法**

```matlab
alg = grid_connected_inverter();
% 从类中提取:
% - 参数 (properties)
% - 方程 (methods)
% - 状态变量 (persistent)
```

步骤 2: **转换为 Simulink MATLAB Function**

```matlab
function [output] = algorithm_fcn(input)
    %#codegen
    % 提取的算法代码
    % 使用 persistent 存储状态
    persistent state
    if isempty(state), state = initial_value; end
    
    % 算法核心
    ...
    
    % 状态更新
    state = new_state;
    
    output = result;
end
```

步骤 3: **组织成 Subsystem**

```matlab
add_block('simulink/Ports & Subsystems/Subsystem', ...
    [model '/Core_Algorithm']);

% 在 subsystem 内添加
% - 输入端口
% - MATLAB Function 块
% - 输出端口
% - 内部反馈路径 (如需要)
```

### 6.2 验证与测试

```matlab
% 方法1: 直接对比输出
MATLAB_output = alg.step(input);
[Simulink_output] = sim('model.slx', ...);

error = MATLAB_output - Simulink_output;
max_error = max(abs(error));
fprintf('Max error: %.2e\n', max_error);

% 方法2: 单元测试
testcase_input = [1, 0.5, -0.5];
assert_close(MATLAB_out, SIM_out, 1e-6);
```

---

## 7. 高级主题

### 7.1 性能优化

**避免常见问题**:

1. **代数环** (Algebraic Loop)
   - 症状: Simulink 报告"Algebraic loop detected"
   - 解决: 使用 Unit Delay 块插入 1 个采样周期延迟

2. **数值不稳定**
   - 症状: 仿真漂移或爆炸性增长
   - 原因: PI 积分器未限制
   - 解决: 添加 Anti-Windup 限制

3. **性能瓶颈**
   - 症状: 仿真速度慢
   - 原因: 过多嵌套 subsystem
   - 解决: 使用 accelerator 模式, S-function 优化

### 7.2 自动代码生成

使用 Embedded Coder 生成产业级代码:

```matlab
% 配置模型用于代码生成
set_param(gcs, 'TargetLang', 'C');
set_param(gcs, 'PortableWordSizes', 'on');

% 生成代码
rtwbuild('model_name');
```

### 7.3 Hardware-in-the-Loop (HIL)

```matlab
% 设置 HIL 目标
set_param('model', 'SimulationMode', 'External');
set_param('model', 'ExternalModeTransportLayer', 'Serial');

% 下载到 FPGA/DSP 板
```

---

## 8. 文件结构总结

```
FM/
├── simulink_models/
│   ├── build_pcs_model_enhanced.m           ← 新: 增强模型 (高易读性)
│   ├── build_integrated_system_model.m      ← 旧: 原始集成模型
│   ├── build_afe_switching_model.m
│   └── ...
│
├── core_functions/
│   ├── grid_connected_inverter.m            ← MATLAB 参考实现
│   ├── afe_rectifier.m
│   ├── black_start_controller.m
│   └── cccv_charger.m
│
└── docs/
    ├── SIMULINK_INTEGRATION_GUIDE.md        ← 本文档
    └── ADVANCED_TESTING_INFRASTRUCTURE.md
```

---

## 9. 迁移检查表

- [ ] 所有 10 个算法模块 (4 core + 6 advanced) 已集成
- [ ] 每个主要块都有颜色编码
- [ ] 信号标签清晰且一致
- [ ] 关键参数已文档化
- [ ] 状态机已可视化 (含决策块)
- [ ] 反馈路径已验证 (无代数环)
- [ ] 单元测试已通过
- [ ] 文档已更新但新块
- [ ] 模型已在 R2024b 中验证
- [ ] Demo 仿真已运行成功

---

## 10. 快速开始

**运行新的增强模型**:

```matlab
% 1. 构建
build_pcs_model_enhanced();

% 2. 配置
open('integrated_energy_system_enhanced');
set_param('integrated_energy_system_enhanced', 'StopTime', '0.5');

% 3. 仿真
sim('integrated_energy_system_enhanced');

% 4. 查看结果
Simulink.sdi.view();  % Signal Data Inspector
```

---

**作者**: PCS 项目组  
**版本**: 1.0  
**日期**: 2025-01-15  
**MATLAB 版本**: R2024b+

