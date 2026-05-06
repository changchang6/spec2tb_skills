class spi_monitor extends uvm_monitor;

    `uvm_component_utils(spi_monitor)

    virtual spi_if m_vif;
    spi_config     m_cfg;

    uvm_analysis_port #(spi_xtn) req_ap;
    uvm_analysis_port #(spi_xtn) resp_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(spi_config)::get(this, "", "cfg", m_cfg))
            `uvm_fatal(get_type_name(), "Cannot get spi_config")
        m_vif = m_cfg.m_vif;
        req_ap  = new("req_ap", this);
        resp_ap = new("resp_ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            bit req_bits[$];
            bit resp_bits[$];
            bit [7:0] opcode;
            bit opcode_latched;
            int expected_bits;
            bit [4:0] burst_len_latched;
            bit frame_aborted;

            // Wait for pcs_n to go low (frame start)
            @(m_vif.mon_cb);
            while (m_vif.mon_cb.pcs_n !== 1'b0)
                @(m_vif.mon_cb);

            opcode_latched = 0;
            expected_bits  = 0;
            burst_len_latched = 0;
            frame_aborted   = 0;

            // Phase 1: Capture request bits while pcs_n=0 and pdo_oe=0
            while (m_vif.mon_cb.pcs_n === 1'b0 && m_vif.mon_cb.pdo_oe !== 1'b1) begin
                capture_bits(req_bits);
                if (!opcode_latched && req_bits.size() >= 8) begin
                    opcode = 8'b0;
                    for (int i = 0; i < 8; i++)
                        opcode[i] = req_bits[7 - i];
                    opcode_latched = 1;
                    expected_bits = get_header_length(opcode);
                end
                if (opcode_latched && !burst_len_latched && req_bits.size() >= 16) begin
                    if (opcode inside {8'h22, 8'h23}) begin
                        burst_len_latched = 5'b0;
                        for (int i = 0; i < 5; i++)
                            burst_len_latched[i] = req_bits[15 - i];
                        if (opcode == 8'h22)
                            expected_bits = 48 + 32 * burst_len_latched;
                    end else begin
                        burst_len_latched = 5'b1;
                    end
                end
                if (opcode_latched && req_bits.size() >= expected_bits && expected_bits > 0)
                    break;
                @(m_vif.mon_cb);
            end

            // Check for frame abort (pcs_n went high before request complete)
            if (m_vif.mon_cb.pcs_n === 1'b1 && opcode_latched &&
                req_bits.size() < expected_bits)
                frame_aborted = 1;

            // Emit request transaction
            if (opcode_latched) begin
                spi_xtn xtn;
                xtn = spi_xtn::type_id::create("req_xtn");
                xtn.opcode = opcode;
                parse_request(xtn, req_bits);
                xtn.lane_mode  = m_vif.mon_cb.lane_mode;
                xtn.en         = m_vif.mon_cb.en;
                xtn.test_mode  = m_vif.mon_cb.test_mode;
                xtn.frame_abort = frame_aborted;
                xtn.is_csr   = xtn.opcode inside {8'h10, 8'h11};
                xtn.is_ahb   = xtn.opcode inside {8'h20, 8'h21, 8'h22, 8'h23};
                xtn.is_read  = xtn.opcode inside {8'h11, 8'h21, 8'h23};
                xtn.is_burst = xtn.opcode inside {8'h22, 8'h23};
                req_ap.write(xtn);
            end

            // Phase 2: Capture response bits while pdo_oe=1
            if (m_vif.mon_cb.pdo_oe === 1'b1) begin
                while (m_vif.mon_cb.pdo_oe === 1'b1) begin
                    capture_resp_bits(resp_bits);
                    @(m_vif.mon_cb);
                end

                // Emit response transaction
                if (resp_bits.size() >= 8) begin
                    spi_xtn resp_xtn;
                    bit [7:0] status;
                    resp_xtn = spi_xtn::type_id::create("resp_xtn");
                    status = 8'b0;
                    for (int i = 0; i < 8; i++)
                        status[i] = resp_bits[7 - i];
                    resp_xtn.opcode = 8'hFF;
                    resp_xtn.wdata = new[1];
                    resp_xtn.wdata[0] = {24'b0, status};
                    resp_ap.write(resp_xtn);
                end
            end

            // Phase 3: Wait for pcs_n to go high (frame end)
            while (m_vif.mon_cb.pcs_n !== 1'b1)
                @(m_vif.mon_cb);
        end
    endtask

    task capture_bits(ref bit q[$]);
        case (m_vif.mon_cb.lane_mode)
            2'b00: q.push_back(m_vif.mon_cb.pdi[0]);
            2'b01: for (int i = 3; i >= 0; i--) q.push_back(m_vif.mon_cb.pdi[i]);
            2'b10: for (int i = 7; i >= 0; i--) q.push_back(m_vif.mon_cb.pdi[i]);
            2'b11: for (int i = 15; i >= 0; i--) q.push_back(m_vif.mon_cb.pdi[i]);
        endcase
    endtask

    task capture_resp_bits(ref bit q[$]);
        case (m_vif.mon_cb.lane_mode)
            2'b00: q.push_back(m_vif.mon_cb.pdo[0]);
            2'b01: for (int i = 3; i >= 0; i--) q.push_back(m_vif.mon_cb.pdo[i]);
            2'b10: for (int i = 7; i >= 0; i--) q.push_back(m_vif.mon_cb.pdo[i]);
            2'b11: for (int i = 15; i >= 0; i--) q.push_back(m_vif.mon_cb.pdo[i]);
        endcase
    endtask

    function int get_header_length(bit [7:0] opcode);
        case (opcode)
            8'h10: return 48;
            8'h11: return 16;
            8'h20: return 72;
            8'h21: return 40;
            8'h22: return 48;
            8'h23: return 48;
            default: return 8;
        endcase
    endfunction

    function void parse_request(spi_xtn xtn, ref bit q[$]);
        int idx;
        idx = 8;
        case (xtn.opcode)
            8'h10: begin
                xtn.reg_addr = 8'b0;
                for (int i = 0; i < 8; i++) xtn.reg_addr[i] = q[idx + 7 - i];
                idx += 8;
                xtn.wdata = new[1];
                xtn.wdata[0] = 32'b0;
                for (int i = 0; i < 32; i++) xtn.wdata[0][i] = q[idx + 31 - i];
            end
            8'h11: begin
                xtn.reg_addr = 8'b0;
                for (int i = 0; i < 8; i++) xtn.reg_addr[i] = q[idx + 7 - i];
            end
            8'h20: begin
                xtn.addr = 32'b0;
                for (int i = 0; i < 32; i++) xtn.addr[i] = q[idx + 31 - i];
                idx += 32;
                xtn.wdata = new[1];
                xtn.wdata[0] = 32'b0;
                for (int i = 0; i < 32; i++) xtn.wdata[0][i] = q[idx + 31 - i];
            end
            8'h21: begin
                xtn.addr = 32'b0;
                for (int i = 0; i < 32; i++) xtn.addr[i] = q[idx + 31 - i];
            end
            8'h22, 8'h23: begin
                xtn.burst_len = 5'b0;
                for (int i = 0; i < 5; i++) xtn.burst_len[i] = q[idx + 4 - i];
                idx += 8;
                xtn.addr = 32'b0;
                for (int i = 0; i < 32; i++) xtn.addr[i] = q[idx + 31 - i];
                idx += 32;
                if (xtn.opcode == 8'h22 && xtn.burst_len > 0) begin
                    xtn.wdata = new[xtn.burst_len];
                    foreach (xtn.wdata[j]) begin
                        xtn.wdata[j] = 32'b0;
                        for (int i = 0; i < 32; i++)
                            xtn.wdata[j][i] = q[idx + 31 - i];
                        idx += 32;
                    end
                end
            end
        endcase
    endfunction

endclass
