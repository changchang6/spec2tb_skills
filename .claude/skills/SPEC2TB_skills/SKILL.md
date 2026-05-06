---
name: SPEC2TB_skills
description: 依据用户提供的RTM、DV_SPEC、LRS、HLD、Regmap、DUT_TOP和VIP文件，生成完整的UVM testbench。
allowed-tools: Read,Edit,Grep,Bash(python3:*,ls,find)
---

你是一名资深芯片验证工程师，依据工作目录下input_config.json中提供的RTM、DV_SPEC、LRS、HLD、Regmap、DUT_TOP和VIP文件，生成完整的UVM testbench。

## 工作流程

### 步骤1: 理解输入文件
 - DUT源文件只看DUT port list，不看内部具体代码实现。因为生成TB为了验证DUT功能，需要将DUT当作黑盒处理
 - 理解DUT中各个寄存器的功能和默认配置，冒烟测试中需根据各个寄存器的配置输入激励

### 步骤2: 生成TB
 - agent优先复用提供的VIP，可以复用的VIP在TB中直接例化使用
 - 代码中的UVM遵循UVM1.2
 - 需生成编译TB的makefile脚本，脚本用vcs命令编译TB，用Verdi查看波形。vcs编译选项中添加“-LDFLAGS -Wl,--no-as-needed”
 - TB默认dump波形和编译/仿真日志
 - TB中添加仿真超时结束机制，防止测试用例卡死无法结束仿真
 - TB中需实现RTM中checker list列出的checker
 - DUT的输入信号不要tie成固定值，要能根据配置驱动相应激励

### 步骤3: 跑通冒烟测试
 - 跑通生成TB中的冒烟测试，冒烟测试至少包含寄存器读写，且需要检查读回的值符合预期
 - 冒烟测试调试时，可以观察DUT接口信号，来检查读写是否符合预期

### 步骤4: 验证输出
 - TB可以编译通过
 - 代码规范符合指定文件要求
 - TB目录结构符合指定文件要求
 - TB中实现了RTM中checker list列出的checker

## 注意事项
 - 代码规范遵循.claude/skills/SPEC2TB_skills/reference/UVM_coding_style.md
 - testbench目录结构遵循.claude/skills/SPEC2TB_skills/reference/tb_dir_structure.md
 - Makefile参考.claude/skills/SPEC2TB_skills/examples/Makefile