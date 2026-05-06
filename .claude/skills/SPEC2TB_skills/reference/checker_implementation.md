# RTM Checker Implementation Guide

本文档描述如何将RTM Checker List中的checker映射到UVM testbench的具体实现中。

## 目录
1. [Checker分类映射](#checker分类映射)
2. [参考模型模式](#参考模型模式)
3. [计分板模式](#计分板模式)
4. [Monitor协议检查模式](#monitor协议检查模式)
5. [SVA断言模式](#sva断言模式)

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

### Monitor协议检查 (Monitor Protocol Check)

检查接口时序/协议合规性的checker，在各agent的monitor中实现：

| Checker类型 | 实现位置 | 检查内容 |
|------------|---------|---------|
| 帧协议检查 (frame protocol) | SPI monitor | pcs_n时序、pdo_oe时序、turnaround周期、burst连续性 |
| CSR时序检查 (CSR timing) | CSR monitor | wr_en/rd_en单周期脉冲、读延迟1周期、地址范围 |
| AHB协议检查 (AHB protocol) | AHB monitor | hsize固定WORD、haddr对齐、htrans序列、hburst稳定、地址递增+4 |
| Lane模式检查 (lane mode) | SPI monitor | 数据位宽与lane_mode配置一致 |

### SVA断言 (SVA Assertions)

纯信号级检查，在tb.sv或interface中用SystemVerilog断言实现：

| Checker类型 | 检查内容 |
|------------|---------|
| 复位状态检查 (reset state) | 复位释放后FSM回到IDLE、输出信号初始值正确 |
| 空闲行为检查 (low power/idle) | 空闲时RX/TX逻辑不翻转 |
| AHB固定属性 | hsize始终WORD、haddr始终4字节对齐 |

### Coverage采集 (Coverage Collection)

功能覆盖率和统计计数器，在coverage collector中实现：

| Checker类型 | 实现方式 |
|------------|---------|
| DFX统计计数器 | covergroup覆盖opcode、error code、burst类型 |
| 功能覆盖 | coverpoint覆盖lane_mode、burst_len、地址范围 |

---

## 参考模型模式

参考模型是纯功能预测器，接收输入侧事务，预测输出侧行为。

### 类结构

```systemverilog
class dut_ref_model extends uvm_component;

    `uvm_component_utils(dut_ref_model)

    // 输入: 从输入侧monitor接收事务
    uvm_analysis_imp #(input_xtn, dut_ref_model) m_req_imp;

    // 输出: 发送预期事务到scoreboard
    uvm_analysis_port #(output_xtn)  m_output_exp_ap;  // 预期的输出侧事务
    uvm_analysis_port #(response_xtn) m_resp_exp_ap;    // 预期的响应事务

    // 内部状态
    // 根据DUT功能维护必要的配置状态

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_req_imp       = new("m_req_imp", this);
        m_output_exp_ap = new("m_output_exp_ap", this);
        m_resp_exp_ap   = new("m_resp_exp_ap", this);
    endfunction

    function void write(input_xtn req);
        // 1. 解析请求
        // 2. 按优先级检查错误
        // 3. 有错误: 发送错误响应，不发送下游预期事务
        // 4. 无错误: 预测下游事务和响应，分别发送
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

无错误时，根据opcode预测下游事务：

```systemverilog
function void predict_behavior(input_xtn req);
    case (req.opcode)
        WR_CSR: begin
            // 创建预期的CSR写事务
            output_xtn exp = output_xtn::type_id::create("exp");
            exp.write = 1;
            exp.addr  = req.reg_addr;
            exp.data  = req.wdata[0];
            m_output_exp_ap.write(exp);
            // 发送成功响应
            send_response(STS_OK);
        end
        RD_CSR: begin
            // 创建预期的CSR读事务
            output_xtn exp = output_xtn::type_id::create("exp");
            exp.write = 0;
            exp.addr  = req.reg_addr;
            // 读返回数据无法预测（无内存模型），只预测事务类型
            m_output_exp_ap.write(exp);
            send_response(STS_OK, .has_rdata(1));
        end
        AHB_WR32: begin
            // 创建预期的AHB写事务
            output_xtn exp = output_xtn::type_id::create("exp");
            exp.write = 1;
            exp.addr  = req.addr;
            exp.burst = SINGLE;
            exp.data  = req.wdata;
            m_output_exp_ap.write(exp);
            send_response(STS_OK);
        end
        // ... 其他opcode类似
    endcase
endfunction
```

---

## 计分板模式

计分板比较参考模型的预期事务与DUT输出侧monitor采样的实际事务。

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
        // 比较关键字段
        if (act.addr !== exp.addr) match = 0;
        if (act.write !== exp.write) match = 0;
        if (act.burst !== exp.burst) match = 0;
        // 写操作比较数据
        if (exp.write && act.data.size() === exp.data.size()) begin
            foreach (exp.data[i])
                if (act.data[i] !== exp.data[i]) match = 0;
        end
        // 读操作不比较数据（参考模型无内存模型）

        if (match) begin
            m_match_count++;
            `uvm_info(get_type_name(), "MATCH", UVM_HIGH)
        end else begin
            m_mismatch_count++;
            `uvm_error(get_type_name(), $sformatf("MISMATCH: act=%s exp=%s",
                act.convert2string(), exp.convert2string()))
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

当DUT有多个输出接口时，为每个接口建立独立的比较通道：

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

    // run_phase中为每个通道fork一个compare_loop
endclass
```

---

## Monitor协议检查模式

在monitor中添加协议检查逻辑，检测到违规时用uvm_error报告。

### SPI Monitor帧协议检查

```systemverilog
// 在monitor的采集逻辑中添加检查
// 1. Turnaround检查: request结束到response开始之间应有1个clk_i周期pdo_oe=0
if (req_end_cycle > 0 && pdo_oe_rise_cycle > 0) begin
    int ta_cycles = pdo_oe_rise_cycle - req_end_cycle;
    if (ta_cycles != 1) begin
        `uvm_error(get_type_name(),
            $sformatf("Frame protocol violation: turnaround=%0d cycles, expected 1", ta_cycles))
    end
end

// 2. Burst连续性检查: burst响应期间pdo_oe应保持为1
// 3. pcs_n时序检查: 帧期间pcs_n应保持0
```

### AHB Monitor协议检查

```systemverilog
// 在AHB monitor的采集逻辑中添加检查
// 1. hsize固定检查
if (m_vif.hsize !== 3'b010) begin
    `uvm_error(get_type_name(), "AHB protocol: hsize must be WORD(010)")
end

// 2. haddr对齐检查
if (m_vif.haddr[1:0] !== 2'b00) begin
    `uvm_error(get_type_name(), "AHB protocol: haddr must be 4-byte aligned")
end

// 3. htrans序列检查: burst中第一拍应为NONSEQ，后续为SEQ
// 4. hburst稳定性检查: burst期间hburst不应变化
// 5. 地址递增检查: burst中地址应递增+4
```

### CSR Monitor时序检查

```systemverilog
// 1. wr_en/rd_en单周期脉冲检查
if (csr_wr_en_prev && csr_wr_en_curr) begin
    `uvm_error(get_type_name(), "CSR protocol: wr_en must be single-cycle pulse")
end

// 2. 读延迟检查: rd_en后下一周期应有rdata有效
// 3. 地址范围检查
if (csr_addr >= 64) begin
    `uvm_error(get_type_name(), $sformatf("CSR protocol: addr 0x%02h out of range", csr_addr))
end
```

---

## SVA断言模式

在tb.sv或interface中添加SVA断言，检查纯信号级行为。

### 复位状态断言

```systemverilog
// 在tb.sv中，DUT例化后添加
property p_reset_outputs;
    @(posedge clk) !rst_n |=> (
        dut.pdo_oe_o === 1'b0 &&
        dut.htrans_o === 2'b00 &&
        dut.csr_rd_en_o === 1'b0 &&
        dut.csr_wr_en_o === 1'b0
    );
endproperty
assert property(p_reset_outputs) else $error("[CHK_001] Reset state violation");

property p_reset_pdo_zero;
    @(posedge clk) !rst_n |=> dut.pdo_o === '0;
endproperty
assert property(p_reset_pdo_zero) else $error("[CHK_001] Reset pdo_o not zero");
```

注意：这里引用DUT的port信号（如`dut.pdo_oe_o`）是允许的，因为这些都是DUT的port而非内部信号。但不要引用`dut.xxx.yyy`这样的层级路径。

### AHB固定属性断言

```systemverilog
property p_ahb_hsize_word;
    @(posedge clk) rst_n && dut.htrans_o != 2'b00 |-> dut.hsize_o === 3'b010;
endproperty
assert property(p_ahb_hsize_word) else $error("[CHK_015] AHB hsize not WORD");

property p_ahb_addr_aligned;
    @(posedge clk) rst_n && dut.htrans_o != 2'b00 |-> dut.haddr_o[1:0] === 2'b00;
endproperty
assert property(p_ahb_addr_aligned) else $error("[CHK_015] AHB addr not aligned");
```

### 空闲行为断言

```systemverilog
property p_idle_no_rx_update;
    @(posedge clk) rst_n && dut.pcs_n_i === 1'b1 |-> 1; // RX不更新（需结合具体信号）
endproperty
```

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
