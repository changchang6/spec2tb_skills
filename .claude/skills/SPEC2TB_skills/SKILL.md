---
name: SPEC2TB_skills
description: 依据用户提供的RTM、DV_SPEC、LRS、HLD、Regmap、DUT_TOP和VIP文件，生成完整的UVM testbench。当用户需要生成验证环境、UVM testbench、验证平台、checker、scoreboard、reference model时，应使用此skill。
allowed-tools: Read,Edit,Grep,Bash(python3:*,ls,find)
---

你是一名资深芯片验证工程师，依据工作目录下input_config.json中提供的RTM、DV_SPEC、LRS、HLD、Regmap、DUT_TOP和VIP文件，生成完整的UVM testbench。

## 工作流程

### 步骤1: 理解输入文件

 - DUT源文件只看DUT port list，不看内部具体代码实现。生成TB为了验证DUT功能，需将DUT当作黑盒处理
 - 理解DUT中各个寄存器的功能和默认配置，冒烟测试中需根据各个寄存器的配置输入激励
 - **读取RTM中的Checker List**，理解每个checker的检查内容和预期行为，将checker按实现方式分类（见步骤2.2）
 - 从LRS/HLD中理解DUT各接口的时序协议，作为monitor和driver实现的依据

### 步骤2: 生成TB

#### 2.1 基础环境搭建
 - agent优先复用提供的VIP，可以复用的VIP在TB中直接例化使用
 - 代码中的UVM遵循UVM1.2
 - 需生成编译TB的makefile脚本，脚本用vcs命令编译TB，用Verdi查看波形。vcs编译选项中添加"-LDFLAGS -Wl,--no-as-needed"
 - TB默认dump波形和编译/仿真日志
 - TB中添加仿真超时结束机制，防止测试用例卡死无法结束仿真
 - DUT的输入信号不要tie成固定值，要能根据配置驱动相应激励
 - **严禁在tb.sv中引用DUT内部信号（如dut.xxx.yyy），tb.sv只能连接DUT的port信号**

#### 2.2 RTM Checker分类与实现

读取RTM Checker List后，将每个checker归类到以下四种实现方式：

| 实现方式 | 适用checker类型 | 实现位置 |
|---------|---------------|---------|
| **参考模型+计分板** | 需要预测DUT输出行为、比较预期与实际的checker | ref_model + scoreboard |
| **Monitor协议检查** | 接口时序/协议合规性检查 | 各agent的monitor |
| **SVA断言** | 纯信号级检查（复位状态、空闲行为等） | tb.sv或interface |
| **Coverage采集** | 功能点覆盖率和统计计数器 | coverage collector |

分类原则：
 - 如果checker需要"预测DUT应该产生什么输出"，用参考模型+计分板（如：opcode解码后应产生正确的CSR/AHB事务、错误优先级链、burst行为预测）
 - 如果checker检查"接口信号是否符合时序协议"，用Monitor检查（如：CSR单周期脉冲、AHB协议合规、SPI帧时序）
 - 如果checker检查"特定信号状态/转换"，用SVA断言（如：复位后所有FSM回到IDLE、空闲时输出不翻转）
 - 如果checker是"统计计数或功能覆盖"，用Coverage采集（如：opcode成功计数、错误码覆盖）

详细的checker实现模式和代码模板见 `.claude/skills/SPEC2TB_skills/reference/checker_implementation.md`

#### 2.3 参考模型(ref_model)生成

参考模型是checker实现的核心，它接收DUT输入侧事务，预测DUT输出侧行为。参考模型需要：

 - **输入**: 从DUT输入侧monitor接收事务（如SPI request transaction）
 - **输出**: 通过analysis port发送预期事务到scoreboard（如预期的CSR transaction、AHB transaction、SPI response）
 - **功能**:
   1. 命令解析：从输入事务中解析opcode和参数
   2. 错误检查：实现完整的错误优先级链（从RTM/LRS中获取），按优先级从高到低检查，命中第一个错误即返回对应status
   3. 行为预测：无错误时，预测DUT应产生的下游事务（CSR读写、AHB读写）和响应
   4. 状态维护：跟踪内部状态（如CTRL寄存器、test_mode/en配置）用于条件判断
 - **无时序**: 参考模型是纯功能模型，不建模时序，只预测功能行为

#### 2.4 计分板(scoreboard)生成

计分板接收参考模型输出的预期事务和DUT输出侧monitor采样的实际事务，进行比较：

 - 建立expected和actual两个FIFO通道，每收到一对事务进行比较
 - 比较字段应覆盖：地址、方向（读/写）、burst类型、数据（写操作）、数据长度
 - 对于读操作的数据比较：如果参考模型没有内存模型（无法预测读返回数据），则只比较事务类型和地址，不比较数据
 - 比较结果用uvm_error报告mismatch，用uvm_info(HIGH)报告match
 - report_phase中输出比较统计

#### 2.5 Monitor协议检查

在非复用agent的monitor中添加协议检查逻辑：

 - SPI monitor: 检查帧协议（pcs_n时序、pdo_oe时序、turnaround周期、burst连续性）
 - AHB monitor: 检查AHB协议（hsize固定、haddr对齐、htrans序列、hburst稳定性、地址递增+4）
 - CSR monitor: 检查CSR时序（wr_en/rd_en单周期脉冲、读延迟1周期、地址范围合规）

Monitor检查到违规时用uvm_error报告，并提供具体的违规信息

#### 2.6 SVA断言

在tb.sv或interface中添加SVA断言检查纯信号级行为：

 - 复位检查：复位释放后DUT输出信号初始状态正确（pdo_oe=0、htrans=IDLE等）
 - 空闲检查：pcs_n=1时RX逻辑不更新、非TX状态时TX逻辑不翻转
 - AHB固定属性：hsize始终为WORD、haddr始终4字节对齐

### 步骤3: 跑通冒烟测试

 - 跑通生成TB中的冒烟测试，冒烟测试至少包含寄存器读写，且需要检查读回的值符合预期
 - 冒烟测试调试时，可以观察DUT接口信号，来检查读写是否符合预期
 - **严禁通过引用DUT内部信号来调试**，只能通过DUT port信号和波形观察

### 步骤4: 验证输出

 - TB可以编译通过
 - 代码规范符合指定文件要求
 - TB目录结构符合指定文件要求
 - RTM中每个checker都有对应的实现（在ref_model/scoreboard/monitor/SVA/coverage中）
 - 参考模型实现了RTM中的错误优先级链
 - 计分板实现了预期与实际的比较

## 注意事项

 - 代码规范遵循.claude/skills/SPEC2TB_skills/reference/UVM_coding_style.md
 - testbench目录结构遵循.claude/skills/SPEC2TB_skills/reference/tb_dir_structure.md
 - checker实现模式参考.claude/skills/SPEC2TB_skills/reference/checker_implementation.md
 - Makefile参考.claude/skills/SPEC2TB_skills/examples/Makefile
