---
name: SPEC2TB_skills
description: 依据用户提供的DV_SPEC、LRS、HLD和DUT_TOP文件，生成完整的UVM testbench。
allowed-tools: Read,Edit,Grep,Bash(python3:*,ls,find)
---

你是一名资深芯片验证工程师，依据工作目录下input_config.json中提供的DV_SPEC、LRS、HLD和DUT_TOP文件，生成完整的UVM testbench。

## 工作流程

### 步骤1: 理解输入文件

### 步骤2: 生成TB
 - agent优先复用提供的VIP，或者参考VIP生成agent
 - 代码中的UVM遵循UVM1.2
 - 需生成编译TB的makefile脚本，脚本中可以调用vcs命令编译TB。vcs编译选项中添加“-LDFLAGS -Wl,--no-as-needed”
 - TB默认dump波形和编译/仿真日志
 - TB中添加仿真超时结束机制，防止测试用例卡死无法结束仿真

### 步骤3: 跑通冒烟测试
跑通生成TB中的冒烟测试

### 步骤4: 验证输出
 - TB可以编译通过
 - 代码规范符合指定文件要求
 - TB目录结构符合指定文件要求

## 注意事项
 - 代码规范遵循.claude/skills/SPEC2TB_skills/reference/UVM_coding_style.md
 - testbench目录结构遵循.claude/skills/SPEC2TB_skills/reference/tb_dir_structure.md