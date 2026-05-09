# RTM Checker Implementation Guide

本文档描述如何将RTM Checker List中的checker映射到UVM testbench的具体实现中。

## 目录
1. [Checker分类映射](#checker分类映射)
2. [参考模型模式](#参考模型模式)
3. [计分板模式](#计分板模式)
4. [SVA断言模式](#sva断言模式)

---

## Checker分类映射

对于典型的SPI-to-Bus桥接类DUT，RTM Checker List中的checker可按以下方式分类：

### 参考模型+计分板 (Ref Model + Scoreboard)

需要预测DUT输出行为并与实际输出比较的checker：

| Checker类型 | 实现方式 |
|------------|---------|
| 命令解码检查 (opcode decode) | 参考模型解析opcode，预测应产生的下游事务类型 |
| 错误优先级链 (error priority) | 参考模型按优先级实现完整错误检查链，预测错误响应 |
| CSR访问行为 (CSR access) | 参考模型预测CSR读写事务的地址、数据、方向 |
| AHB主机行为 (AHB master) | 参考模型预测AHB事务的地址、方向、burst类型、数据 |
| Burst帧处理 (burst frame) | 参考模型处理burst解析、beat计数、地址递增 |
| 配置控制 (config/CTRL) | 参考模型维护CTRL寄存器状态，影响条件判断 |
| 状态报告 (status report) | 参考模型预测STATUS/LAST_ERR寄存器值 |
| 帧格式 (frame format) | 参考模型预测响应帧的格式和长度 |

### SVA断言 (SVA Assertions)

纯信号级检查，以及检查接口时序/协议合规性的checker，在interface中用SystemVerilog断言实现：

| Checker类型 | 检查内容 | 断言位置 |
|------------|---------|---------|
| 复位状态检查 (reset state) | 复位释放后FSM回到IDLE、输出信号初始值正确 | 对应interface |
| 空闲行为检查 (low power/idle) | 空闲时RX/TX逻辑不翻转 | spi_if.sv |
| 帧协议检查 (frame protocol) | pcs_n时序、pdo_oe时序、turnaround周期、burst连续性 | spi_if.sv |
| CSR时序检查 (CSR timing) | wr_en/rd_en单周期脉冲、读延迟1周期、地址范围 | csr_if.sv |
| AHB协议检查 (AHB protocol) | hsize固定WORD、haddr对齐、htrans序列、hburst稳定、地址递增+4 | VIP自带（复用时跳过） |
| Lane模式检查 (lane mode) | 数据位宽与lane_mode配置一致 | spi_if.sv |

### Coverage采集 (Coverage Collection)

功能覆盖率和统计计数器，在coverage collector中实现：

| Checker类型 | 实现方式 |
|------------|---------|
| DFX统计计数器 | covergroup覆盖opcode、error code、burst类型 |
| 功能覆盖 | coverpoint覆盖lane_mode、burst_len、地址范围 |

---

## 参考模型模式

参考模型是纯功能预测器，接收输入侧事务，预测输出侧行为。它必须维护寄存器模型和内存模型，才能预测读操作的返回数据。

### 类结构

```systemverilog
class dut_ref_model extends uvm_component;

    `uvm_component_utils(dut_ref_model)

    // 输入: 从输入侧monitor接收事务
    uvm_analysis_imp #(input_xtn, dut_ref_model) m_req_imp;

    // 输出: 发送预期事务到scoreboard
    uvm_analysis_port #(output_xtn)  m_output_exp_ap;  // 预期的输出侧事务
    uvm_analysis_port #(response_xtn) m_resp_exp_ap;    // 预期的响应事务

    // ---- 寄存器模型: CSR影子副本 ----
    // 每个CSR寄存器对应一个影子变量，初始值从Regmap获取
    logic [31:0] m_ctrl_shadow;    // CTRL寄存器，默认值从Regmap读取
    logic [31:0] m_status_shadow;  // STATUS寄存器
    logic [31:0] m_last_err_shadow;// LAST_ERR寄存器
    // ... 其他寄存器按Regmap添加

    // ---- 内存模型: AHB shadow memory ----
    // 关联数组用于预测AHB读返回数据
    logic [31:0] m_ahb_mem[logic [31:0]];

    // ---- 配置状态 ----
    bit m_en;
    bit m_test_mode;
    logic [1:0] m_lane_mode;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_req_imp       = new("m_req_imp", this);
        m_output_exp_ap = new("m_output_exp_ap", this);
        m_resp_exp_ap   = new("m_resp_exp_ap", this);
        // 初始化寄存器影子副本（默认值从Regmap获取）
        init_reg_shadow();
    endfunction

    function void init_reg_shadow();
        // 从Regmap文档获取每个寄存器的默认值
        m_ctrl_shadow     = 32'h0000_000F; // 示例：CTRL默认值
        m_status_shadow   = 32'h0000_0000;
        m_last_err_shadow = 32'h0000_0000;
    endfunction

    function void write(input_xtn req);
        // 1. 更新配置状态（en/test_mode/lane_mode来自输入信号或寄存器）
        // 2. 按优先级检查错误
        // 3. 有错误: 更新STATUS/LAST_ERR影子寄存器，发送错误响应，不发送下游预期事务
        // 4. 无错误: 预测下游事务和响应，更新寄存器影子副本和内存模型
    endfunction

endclass
```

### 错误优先级链实现

错误检查按优先级从高到低排列，命中第一个错误即返回：

```systemverilog
function void check_errors(input_xtn req, output response_status_t status, output bit has_error);
    has_error = 1;
    // 按RTM定义的优先级从高到低检查
    if (/* frame error condition */)     status = STS_FRAME_ERR;
    else if (/* bad opcode */)          status = STS_BAD_OPCODE;
    else if (/* not in test mode */)    status = STS_NOT_IN_TEST;
    else if (/* disabled */)            status = STS_DISABLED;
    else if (/* bad register addr */)   status = STS_BAD_REG;
    else if (/* alignment error */)     status = STS_ALIGN_ERR;
    else if (/* bad burst len */)       status = STS_BAD_BURST;
    else if (/* burst boundary error */) status = STS_BURST_BOUND;
    else begin
        has_error = 0;
        status = STS_OK;
    end
endfunction
```

### 行为预测实现

无错误时，根据opcode预测下游事务。关键是：写操作更新影子状态，读操作从影子状态获取预期数据。

```systemverilog
function void predict_behavior(input_xtn req);
    case (req.opcode)
        WR_CSR: begin
            // 1. 更新寄存器影子副本
            update_csr_shadow(req.reg_addr, req.wdata[0]);
            // 2. 创建预期的CSR写事务
            output_xtn exp = output_xtn::type_id::create("exp");
            exp.write = 1;
            exp.addr  = req.reg_addr;
            exp.data  = req.wdata[0];
            m_output_exp_ap.write(exp);
            // 3. 发送成功响应
            send_response(STS_OK);
        end
        RD_CSR: begin
            // 从影子寄存器读取预期值
            logic [31:0] expected_rdata;
            expected_rdata = get_csr_shadow(req.reg_addr);
            // 创建预期的CSR读事务（包含预期rdata）
            output_xtn exp = output_xtn::type_id::create("exp");
            exp.write = 0;
            exp.addr  = req.reg_addr;
            exp.data  = expected_rdata;  // 有寄存器模型，可以预测读数据
            m_output_exp_ap.write(exp);
            // 发送成功响应（包含预期rdata）
            send_response(STS_OK, .rdata(expected_rdata));
        end
        AHB_WR32: begin
            // 1. 更新shadow memory
            m_ahb_mem[req.addr] = req.wdata[0];
            // 2. 创建预期的AHB写事务
            output_xtn exp = output_xtn::type_id::create("exp");
            exp.write = 1;
            exp.addr  = req.addr;
            exp.burst = SINGLE;
            exp.data  = req.wdata;
            m_output_exp_ap.write(exp);
            send_response(STS_OK);
        end
        AHB_RD32: begin
            // 从shadow memory读取预期值
            logic [31:0] expected_rdata;
            if (m_ahb_mem.exists(req.addr))
                expected_rdata = m_ahb_mem[req.addr];
            else
                expected_rdata = 32'h0;  // 未写过的地址返回0
            // 创建预期的AHB读事务（包含预期rdata）
            output_xtn exp = output_xtn::type_id::create("exp");
            exp.write = 0;
            exp.addr  = req.addr;
            exp.burst = SINGLE;
            exp.data  = {expected_rdata};  // 有内存模型，可以预测读数据
            m_output_exp_ap.write(exp);
            send_response(STS_OK, .rdata(expected_rdata));
        end
        AHB_WR_BURST: begin
            // 1. 逐beat更新shadow memory
            for (int i = 0; i < req.wdata.size(); i++) begin
                m_ahb_mem[req.addr + i*4] = req.wdata[i];
            end
            // 2. 逐beat生成expected AHB transaction
            for (int i = 0; i < req.wdata.size(); i++) begin
                output_xtn exp = output_xtn::type_id::create("exp");
                exp.write = 1;
                exp.addr  = req.addr + i*4;
                exp.burst = (i == 0) ? INCR : INCR;  // 首拍NONSEQ，后续SEQ
                exp.data  = {req.wdata[i]};
                m_output_exp_ap.write(exp);
            end
            send_response(STS_OK);
        end
        // ... 其他opcode类似
    endcase
endfunction

// 寄存器影子副本更新
function void update_csr_shadow(logic [5:0] addr, logic [31:0] wdata);
    case (addr)
        6'h00: m_ctrl_shadow     = wdata;  // CTRL
        // STATUS/LAST_ERR只读，忽略写操作（从Regmap确认哪些寄存器只读）
        default: ; // 其他寄存器按Regmap添加
    endcase
endfunction

// 寄存器影子副本读取
function logic [31:0] get_csr_shadow(logic [5:0] addr);
    case (addr)
        6'h00: return m_ctrl_shadow;
        6'h01: return m_status_shadow;
        6'h02: return m_last_err_shadow;
        default: return 32'h0;
    endcase
endfunction
```

---

## 计分板模式

计分板比较参考模型的预期事务与DUT输出侧monitor采样的实际事务。由于ref_model维护了寄存器模型和内存模型，读操作的数据也可以完整比较。

### 类结构

```systemverilog
class dut_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(dut_scoreboard)

    // 实际事务 (来自DUT输出侧monitor)
    uvm_analysis_imp_output #(output_xtn, dut_scoreboard) m_output_act_imp;

    // 预期事务 (来自参考模型)
    uvm_analysis_imp_output #(output_xtn, dut_scoreboard) m_output_exp_imp;

    // FIFO用于匹配expected和actual
    uvm_tlm_analysis_fifo #(output_xtn) m_act_fifo;
    uvm_tlm_analysis_fifo #(output_xtn) m_exp_fifo;

    int m_match_count;
    int m_mismatch_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_output_act_imp = new("m_output_act_imp", this);
        m_output_exp_imp = new("m_output_exp_imp", this);
        m_act_fifo = new("m_act_fifo", this);
        m_exp_fifo = new("m_exp_fifo", this);
    endfunction

    // 接收实际/预期事务，放入FIFO
    function void write_output(output_xtn xtn); // actual
        m_act_fifo.write(xtn);
    endfunction

    // FIFO匹配和比较在run_phase中执行
    task run_phase(uvm_phase phase);
        fork
            compare_loop();
        join_none
    endtask

    task compare_loop();
        output_xtn act, exp;
        forever begin
            m_act_fifo.get(act);
            m_exp_fifo.get(exp);
            compare(act, exp);
        end
    endtask

    function void compare(output_xtn act, output_xtn exp);
        bit match = 1;
        string detail = "";
        // 比较关键字段
        if (act.addr !== exp.addr) begin
            match = 0; detail = {detail, $sformatf(" addr:act=0x%02h exp=0x%02h", act.addr, exp.addr)};
        end
        if (act.write !== exp.write) begin
            match = 0; detail = {detail, $sformatf(" dir:act=%0b exp=%0b", act.write, exp.write)};
        end
        if (act.burst !== exp.burst) begin
            match = 0; detail = {detail, $sformatf(" burst:act=%0d exp=%0d", act.burst, exp.burst)};
        end
        // 写操作比较数据
        if (exp.write) begin
            if (act.data.size() !== exp.data.size()) begin
                match = 0; detail = {detail, $sformatf(" data_size:act=%0d exp=%0d", act.data.size(), exp.data.size())};
            end else begin
                foreach (exp.data[i])
                    if (act.data[i] !== exp.data[i]) begin
                        match = 0; detail = {detail, $sformatf(" wdata[%0d]:act=0x%08h exp=0x%08h", i, act.data[i], exp.data[i])};
                    end
            end
        end
        // 读操作也比较数据（ref_model有寄存器模型/内存模型可预测读返回值）
        if (!exp.write) begin
            if (act.data.size() !== exp.data.size()) begin
                match = 0; detail = {detail, $sformatf(" rdata_size:act=%0d exp=%0d", act.data.size(), exp.data.size())};
            end else begin
                foreach (exp.data[i])
                    if (act.data[i] !== exp.data[i]) begin
                        match = 0; detail = {detail, $sformatf(" rdata[%0d]:act=0x%08h exp=0x%08h", i, act.data[i], exp.data[i])};
                    end
            end
        end

        if (match) begin
            m_match_count++;
            `uvm_info(get_type_name(), "MATCH", UVM_HIGH)
        end else begin
            m_mismatch_count++;
            `uvm_error(get_type_name(), $sformatf("MISMATCH:%s  act=%s  exp=%s",
                detail, act.convert2string(), exp.convert2string()))
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(),
            $sformatf("Match: %0d  Mismatch: %0d", m_match_count, m_mismatch_count),
            UVM_NONE)
        if (m_mismatch_count > 0)
            `uvm_error(get_type_name(), "SCOREBOARD FAIL")
    endfunction

endclass
```

### 多通道计分板

当DUT有多个输出接口时，为每个接口建立独立的比较通道。Response通道需比较status和rdata。

```systemverilog
class dut_scoreboard extends uvm_scoreboard;
    // AHB通道
    `uvm_analysis_imp_decl(_ahb_act)
    `uvm_analysis_imp_decl(_ahb_exp)
    uvm_analysis_imp_ahb_act #(ahb_xtn, dut_scoreboard) m_ahb_act_imp;
    uvm_analysis_imp_ahb_exp #(ahb_xtn, dut_scoreboard) m_ahb_exp_imp;
    uvm_tlm_analysis_fifo #(ahb_xtn) m_ahb_act_fifo;
    uvm_tlm_analysis_fifo #(ahb_xtn) m_ahb_exp_fifo;

    // CSR通道
    `uvm_analysis_imp_decl(_csr_act)
    `uvm_analysis_imp_decl(_csr_exp)
    uvm_analysis_imp_csr_act #(csr_xtn, dut_scoreboard) m_csr_act_imp;
    uvm_analysis_imp_csr_exp #(csr_xtn, dut_scoreboard) m_csr_exp_imp;
    uvm_tlm_analysis_fifo #(csr_xtn) m_csr_act_fifo;
    uvm_tlm_analysis_fifo #(csr_xtn) m_csr_exp_fifo;

    // Response通道
    `uvm_analysis_imp_decl(_resp_act)
    `uvm_analysis_imp_decl(_resp_exp)
    uvm_analysis_imp_resp_act #(resp_xtn, dut_scoreboard) m_resp_act_imp;
    uvm_analysis_imp_resp_exp #(resp_xtn, dut_scoreboard) m_resp_exp_imp;
    uvm_tlm_analysis_fifo #(resp_xtn) m_resp_act_fifo;
    uvm_tlm_analysis_fifo #(resp_xtn) m_resp_exp_fifo;

    // run_phase中为每个通道fork一个compare_loop
    task run_phase(uvm_phase phase);
        fork
            csr_compare_loop();
            ahb_compare_loop();
            resp_compare_loop();
        join_none
    endtask
endclass
```

### Response比较

Response通道需完整比较status、opcode和rdata：

```systemverilog
function void compare_resp(resp_xtn act, resp_xtn exp);
    bit match = 1;
    string detail = "";
    if (act.status !== exp.status) begin
        match = 0; detail = {detail, $sformatf(" status:act=0x%02h exp=0x%02h", act.status, exp.status)};
    end
    if (act.opcode !== exp.opcode) begin
        match = 0; detail = {detail, $sformatf(" opcode:act=0x%02h exp=0x%02h", act.opcode, exp.opcode)};
    end
    // 有读数据的响应需比较rdata
    if (exp.has_rdata) begin
        if (act.rdata.size() !== exp.rdata.size()) begin
            match = 0; detail = {detail, $sformatf(" rdata_size:act=%0d exp=%0d", act.rdata.size(), exp.rdata.size())};
        end else begin
            foreach (exp.rdata[i])
                if (act.rdata[i] !== exp.rdata[i]) begin
                    match = 0; detail = {detail, $sformatf(" rdata[%0d]:act=0x%08h exp=0x%08h", i, act.rdata[i], exp.rdata[i])};
                end
        end
    end
    // 比较结果报告...
endfunction
```

### Monitor对象隔离

Monitor向多个analysis port发送事务时，必须为每个port创建独立的transaction副本，避免共享对象突变导致的竞态问题：

```systemverilog
// 错误做法：同一对象发给多个port
m_req_ap.write(xtn);    // ref_model通过此port接收
m_resp_ap.write(xtn);   // 同一对象再发一次，response字段可能覆盖request字段

// 正确做法：为每个port创建独立副本
req_xtn req_clone;
resp_xtn resp_clone;

req_clone = xtn.clone();  // 先发request副本
m_req_ap.write(req_clone);

// 然后在response阶段创建response对象
resp_clone = resp_xtn::type_id::create("resp");
resp_clone.copy_from(xtn);  // 复制公共字段
resp_clone.status = captured_status;
resp_clone.rdata  = captured_rdata;
m_resp_ap.write(resp_clone);
```

---

## Monitor协议检查模式

**注意：接口时序/协议合规性检查由interface中的SVA断言负责（见SVA断言模式），Monitor不需要重复做信号级协议检查。** Monitor的职责是事务打包和事务级检查，仅处理SVA无法表达的多周期/跨事务协议违规。

### Monitor与SVA断言的分工

| 检查类型 | 实现位置 | 说明 |
|---------|---------|------|
| 单周期信号级检查 | interface SVA | 如：wr_en单周期脉冲、pdo_oe在idle时为0、hsize固定 |
| 跨周期时序检查 | interface SVA | 如：复位后输出初始状态、rd_en后rdata延迟有效 |
| 多周期/跨事务协议检查 | Monitor | 如：burst地址递增+4、turnaround周期计数、帧格式完整性 |
| 数据正确性检查 | Scoreboard | 如：读数据比较、响应状态比较 |

Monitor中可添加的**事务级**协议检查（SVA难以表达的）：

```systemverilog
// SPI Monitor: burst响应期间pdo_oe保持检查（需要跨事务状态跟踪）
// CSR Monitor: 连续写同一寄存器检测（事务级统计）
// AHB Monitor: burst地址递增检查（复用VIP时VIP已包含此检查）
```

---

## SVA断言模式

SVA断言放在**对应的interface文件**中，而非tb.sv中。每个interface负责承载该接口的时序/协议断言。复用VIP的接口（如yuu_ahb_interface）不需要添加断言，VIP自带完备检查。

### SPI接口断言（spi_if.sv）

在spi_if的clocking/modport声明之后，添加以下断言。**注意：断言失败时使用`uvm_error()`宏报告错误，而非`$error`，以便通过UVM报告系统统一管理。**

```systemverilog
// ---- SVA Assertions in spi_if ----

// CHK_001: 复位后输出初始状态
property p_rst_pdo_oe;
    @(posedge clk_i) !rst_n_i |=> pdo_oe_o === 1'b0;
endproperty
assert property(p_rst_pdo_oe) else
    `uvm_error("CHK_001", "Reset: pdo_oe not 0 after reset")

property p_rst_pdo_zero;
    @(posedge clk_i) !rst_n_i |=> pdo_o === '0;
endproperty
assert property(p_rst_pdo_zero) else
    `uvm_error("CHK_001", "Reset: pdo_o not 0 after reset")

// CHK_002: 空闲状态检查 - pcs_n=1时pdo_oe=0且pdo_o不翻转
property p_idle_pdo_oe_off;
    @(posedge clk_i) rst_n_i && pcs_n_i === 1'b1 |-> pdo_oe_o === 1'b0;
endproperty
assert property(p_idle_pdo_oe_off) else
    `uvm_error("CHK_002", "Idle: pdo_oe active when pcs_n=1")

// CHK_003: 帧期间pcs_n保持低电平
// (此检查需要跟踪帧状态，用sequence实现)
sequence s_in_frame;
    @(posedge clk_i) pcs_n_i === 1'b0 ##1 pcs_n_i === 1'b0;
endsequence

// CHK_004: pdo_oe仅在帧内有效
property p_pdo_oe_only_in_frame;
    @(posedge clk_i) rst_n_i && pcs_n_i === 1'b1 |-> pdo_oe_o === 1'b0;
endproperty
assert property(p_pdo_oe_only_in_frame) else
    `uvm_error("CHK_004", "pdo_oe active outside frame")

// CHK_005: turnaround周期检查
// request结束后pdo_oe=0的周期数应符合LRS定义（通常1个周期）
// 注意：此断言需要结合具体DUT的时序定义

// CHK_006: burst连续性 - burst响应期间pdo_oe保持1
// 注意：此断言需要跟踪burst状态，具体实现需结合LRS
```

### CSR接口断言（csr_if.sv）

在csr_if的clocking/modport声明之后，添加以下断言：

```systemverilog
// ---- SVA Assertions in csr_if ----

// CHK_010: 复位后CSR输出初始状态
property p_rst_csr_idle;
    @(posedge clk_i) !rst_n_i |=> csr_rd_en_o === 1'b0 && csr_wr_en_o === 1'b0;
endproperty
assert property(p_rst_csr_idle) else
    `uvm_error("CHK_010", "Reset: CSR en not 0 after reset")

// CHK_011: wr_en单周期脉冲
property p_csr_wr_pulse;
    @(posedge clk_i) rst_n_i && csr_wr_en_o === 1'b1 |=> csr_wr_en_o === 1'b0;
endproperty
assert property(p_csr_wr_pulse) else
    `uvm_error("CHK_011", "CSR wr_en not single-cycle pulse")

// CHK_012: rd_en单周期脉冲
property p_csr_rd_pulse;
    @(posedge clk_i) rst_n_i && csr_rd_en_o === 1'b1 |=> csr_rd_en_o === 1'b0;
endproperty
assert property(p_csr_rd_pulse) else
    `uvm_error("CHK_012", "CSR rd_en not single-cycle pulse")

// CHK_013: wr_en和rd_en互斥
property p_csr_rw_excl;
    @(posedge clk_i) rst_n_i |-> !(csr_wr_en_o === 1'b1 && csr_rd_en_o === 1'b1);
endproperty
assert property(p_csr_rw_excl) else
    `uvm_error("CHK_013", "CSR wr_en and rd_en both active")

// CHK_014: CSR地址范围检查
property p_csr_addr_range;
    @(posedge clk_i) rst_n_i && (csr_wr_en_o || csr_rd_en_o) |-> csr_addr_o < 8'h40;
endproperty
assert property(p_csr_addr_range) else
    `uvm_error("CHK_014", $sformatf("CSR addr out of range: 0x%02h", $sampled(csr_addr_o)))

// CHK_016: 读延迟 - rd_en后下一周期rdata有效
property p_csr_rd_latency;
    @(posedge clk_i) rst_n_i && csr_rd_en_o === 1'b1 |=> !$isunknown(csr_rdata_i);
endproperty
assert property(p_csr_rd_latency) else
    `uvm_error("CHK_016", "CSR rdata not valid after rd_en")
```

### AHB接口断言

复用VIP时（如yuu_ahb），VIP自带完备的AHB协议检查断言，不需要在TB中添加AHB断言。如果AHB接口是自建agent，则在ahb_if.sv中添加类似以下断言：

```systemverilog
// AHB固定属性（仅自建AHB agent时需要，复用VIP时跳过）
property p_ahb_hsize_word;
    @(posedge clk_i) rst_n_i && htrans_o != 2'b00 |-> hsize_o === 3'b010;
endproperty
assert property(p_ahb_hsize_word) else
    `uvm_error("CHK_015", "AHB hsize not WORD")

property p_ahb_addr_aligned;
    @(posedge clk_i) rst_n_i && htrans_o != 2'b00 |-> haddr_o[1:0] === 2'b00;
endproperty
assert property(p_ahb_addr_aligned) else
    `uvm_error("CHK_015", "AHB addr not aligned")
```

### 断言编写原则

1. **断言只使用interface内声明的信号**：不引用DUT内部信号（如dut.xxx.yyy）或跨interface信号
2. **每个断言关联一个checker ID**：用$error中的[CHK_xxx]标签与RTM Checker List对应
3. **复位条件必须包含**：大部分断言需在rst_n_i有效时才检查，避免复位期间误报
4. **基于LRS/HLD的时序参数**：turnaround周期数、读延迟等具体参数需从LRS/HLD文档中获取，不应硬编码猜测
5. **覆盖所有RTM checker**：RTM中归类为SVA的每个checker必须至少有一个对应的assert property

---

## 环境连接模式

参考模型、计分板和各agent在env中的连接关系：

```
SPI Agent (input side)
  └── monitor.ap ──┬──> ref_model.m_req_imp
                   │
  └── monitor.ap ──┴──> coverage.analysis_export

Ref Model
  ├── m_output_exp_ap ──> scoreboard.m_xxx_exp_imp  (预期事务)
  └── m_resp_exp_ap  ──> (可选：SPI响应比较)

CSR Agent (output side)
  └── monitor.ap ──> scoreboard.m_csr_act_imp  (实际CSR事务)

AHB Agent/VIP (output side)
  └── monitor.ap ──> scoreboard.m_ahb_act_imp  (实际AHB事务)

Scoreboard
  ├── 比较CSR预期 vs 实际
  └── 比较AHB预期 vs 实际
```

在env的connect_phase中：

```systemverilog
function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // 输入侧: SPI monitor -> ref model + coverage
    m_spi_agent.m_monitor.ap.connect(m_ref_model.m_req_imp);
    m_spi_agent.m_monitor.ap.connect(m_coverage.analysis_export);

    // 参考模型 -> scoreboard (预期)
    m_ref_model.m_csr_exp_ap.connect(m_scoreboard.m_csr_exp_imp);
    m_ref_model.m_ahb_exp_ap.connect(m_scoreboard.m_ahb_exp_imp);

    // 输出侧: CSR monitor -> scoreboard (实际)
    m_csr_agent.m_monitor.ap.connect(m_scoreboard.m_csr_act_imp);

    // 输出侧: AHB VIP monitor -> scoreboard (实际)
    // VIP的monitor连接方式取决于VIP的analysis port名称
    m_ahb_env.m_master_agent.m_monitor.ap.connect(m_scoreboard.m_ahb_act_imp);
endfunction
```
