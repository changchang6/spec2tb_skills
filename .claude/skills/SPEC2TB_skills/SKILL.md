---
name: SPEC2TB_skills
description: 依据用户提供的RTM、DV_SPEC、LRS、HLD、Regmap、DUT_TOP和VIP文件，生成完整的UVM testbench。当用户需要生成验证环境、UVM testbench、验证平台、checker、scoreboard、reference model时，应使用此skill。
allowed-tools: Read,Edit,Grep,Bash(python3:*,ls,find)
---

你是一名资深芯片验证工程师，依据工作目录下input_config.json中提供的RTM、DV_SPEC、LRS、HLD、Regmap、DUT_TOP和VIP文件，生成完整的UVM testbench。

## 工作流程

### 步骤1: 理解输入文件

 - 理解DUT中各个寄存器的功能和默认配置，冒烟测试中需根据各个寄存器的配置输入激励
 - **读取RTM中的Checker List**，理解每个checker的检查内容和预期行为，将checker按实现方式分类（见步骤2.2）
 - 从LRS/HLD中理解DUT各接口的时序协议，作为monitor和driver实现的依据

### 步骤2: 生成TB

#### 2.1 基础环境搭建
 - agent优先复用提供的VIP，可以复用的VIP在TB中直接例化使用
 - 代码中的UVM遵循UVM1.2
 - 需生成编译TB的makefile脚本，脚本用vcs命令编译TB，用Verdi查看波形。vcs编译选项中添加"-LDFLAGS -Wl,--no-as-needed"
 - TB默认dump波形和编译/仿真日志，dump波形用fsdb格式
 - TB中添加仿真超时结束机制，防止测试用例卡死无法结束仿真
 - DUT的输入信号不要tie成固定值，要能根据配置驱动相应激励

#### 2.2 RTM Checker分类与实现

读取RTM Checker List后，将每个checker归类到以下3种实现方式：

| 实现方式 | 适用checker类型 | 实现位置 |
|---------|---------------|---------|
| **参考模型+计分板** | 需要预测DUT输出行为、比较预期与实际的checker | ref_model + scoreboard |
| **SVA断言** | 纯信号级检查（复位状态、空闲行为等）、接口时序/协议合规性检查 | 对应的interface文件中 |
| **Coverage采集** | 功能点覆盖率和统计计数器 | coverage collector |

分类原则：
 - 如果checker需要"预测DUT应该产生什么输出"，用参考模型+计分板（如：opcode解码后应产生正确的CSR/AHB事务、错误优先级链、burst行为预测）
 - 如果checker检查"特定信号状态/转换"或"接口信号是否符合时序协议"，用SVA断言（如：复位后所有FSM回到IDLE、空闲时输出不翻转、CSR单周期脉冲、AHB协议合规、SPI帧时序）
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
 - **寄存器模型**: 必须维护CSR寄存器影子副本，才能预测CSR读操作返回数据。详见 `.claude/skills/SPEC2TB_skills/reference/checker_implementation.md`
 - **内存模型**: 必须维护shadow memory，才能预测AHB读操作返回数据。详见 `.claude/skills/SPEC2TB_skills/reference/checker_implementation.md`

#### 2.4 计分板(scoreboard)生成

计分板接收参考模型输出的预期事务和DUT输出侧monitor采样的实际事务，进行比较：

 - 建立expected和actual两个FIFO通道，每收到一对事务进行比较
 - 比较字段应覆盖：地址、方向（读/写）、burst类型、数据、数据长度
 - **读操作必须比较数据**：ref_model维护寄存器模型和内存模型后，可以预测读返回数据，scoreboard应完整比较读数据
 - 写操作比较：地址、方向、数据、burst类型
 - 读操作比较：地址、方向、预期rdata、burst类型
 - Response通道比较：status、opcode、rdata（对于有读数据的响应）
 - 比较结果用uvm_error报告mismatch，用uvm_info(HIGH)报告match
 - report_phase中输出比较统计

#### 2.5 SVA断言

SVA断言放在**对应的interface文件**中（如spi_if.sv、csr_if.sv），而非tb.sv中。每个interface负责承载该接口的时序/协议断言。tb.sv中不放任何断言。

**基本原则：**
 - 每个interface文件中，在clocking/modport声明之后添加本接口相关的SVA断言
 - 断言必须基于RTM Checker List和LRS/HLD文档中定义的接口时序要求生成，确保覆盖所有checker
 - 复用VIP的接口（如yuu_ahb_interface）已有完备断言检查，不需要也不应该修改VIP源文件
 - 断言仅使用interface内可见的信号（即interface声明的信号），不引用DUT内部信号
 - **断言失败时使用`uvm_error()`宏报告错误，而非`$error`，以便通过UVM报告系统统一管理**

**断言生成步骤：**
 1. 从RTM Checker List中提取所有归类为"SVA断言"的checker
 2. 从LRS/HLD中提取每个接口的时序协议要求（如信号有效条件、时序关系、状态转换规则）
 3. 将每个checker和时序要求映射为具体的SVA property + assert语句
 4. 按接口分组放入对应的interface文件

**典型接口断言覆盖：**

SPI接口（spi_if.sv）:
 - 帧开始/结束：pcs_n下降沿表示帧开始，上升沿表示帧结束
 - pcs_n期间稳定：帧期间pcs_n应保持低电平
 - pdo_oe时序：pdo_oe仅在pcs_n低时有效，pcs_n拉高后pdo_oe应在规定周期内拉低
 - turnaround检查：request结束到response开始之间pdo_oe=0的周期数符合LRS定义
 - burst连续性：burst响应期间pdo_oe保持为1，不出现中间断开
 - 数据位宽：pdi/pdo有效数据位与lane_mode配置一致
 - 空闲检查：pcs_n=1时pdo_oe=0、pdo_o不翻转

CSR接口（csr_if.sv）:
 - wr_en/rd_en单周期脉冲：有效后下一周期必须无效
 - wr_en和rd_en互斥：同一周期不应同时为1
 - 读延迟：rd_en有效后，rdata在LRS规定的周期数后有效
 - 地址范围：addr在Regmap定义的有效范围内
 - 只读寄存器保护：wr_en=1且addr指向只读寄存器时，该写操作不应生效

AHB接口（复用VIP时跳过，VIP自带断言）

详细的SVA断言代码模式见 `.claude/skills/SPEC2TB_skills/reference/checker_implementation.md`

### 步骤3: 跑通冒烟测试

 - 跑通生成TB中的冒烟测试，冒烟测试至少包含寄存器读写，且需要检查读回的值符合预期
 - 冒烟测试调试时，可以添加DUT接口信号的打印信息，来检查读写是否符合预期

### 步骤4: 验证输出

 - TB可以编译通过
 - 代码规范符合指定文件要求
 - TB目录结构符合指定文件要求
 - RTM中每个checker都有对应的实现（在ref_model/scoreboard/SVA/coverage中），SVA断言放在对应interface文件中
 - 参考模型实现了RTM中的错误优先级链
 - 参考模型维护了寄存器影子副本和内存模型，可以预测CSR和AHB读返回数据
 - 计分板实现了预期与实际的完整比较（包括读数据比较和Response通道比较）

## 注意事项

 - 代码规范遵循.claude/skills/SPEC2TB_skills/reference/UVM_coding_style.md
 - testbench目录结构遵循.claude/skills/SPEC2TB_skills/reference/tb_dir_structure.md
 - checker实现模式参考.claude/skills/SPEC2TB_skills/reference/checker_implementation.md
 - Makefile参考.claude/skills/SPEC2TB_skills/examples/Makefile
 - **严禁修改VIP源文件**：复用的VIP（如yuu_ahb）自带完备断言检查，不应修改VIP任何源文件
 - **严禁修改设计源文件**：DUT RTL是验证对象，不应修改
 - **SVA断言放在interface文件中**：tb.sv不放断言，每个interface承载自己的时序/协议断言
