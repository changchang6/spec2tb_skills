// APLC SPI Monitor - Captures request and response frames
class aplc_spi_monitor extends uvm_monitor;

    `uvm_component_utils(aplc_spi_monitor)

    virtual aplc_spi_if m_vif;
    static string msg_id = "APLC_SPI_MON";

    // Analysis ports: request and response
    uvm_analysis_port #(aplc_spi_transaction) m_req_ap;
    uvm_analysis_port #(aplc_spi_transaction) m_resp_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual aplc_spi_if)::get(this, "", "vif", m_vif)) begin
            `uvm_fatal(get_type_name(), "Virtual interface not found in config_db")
        end
        m_req_ap  = new("m_req_ap", this);
        m_resp_ap = new("m_resp_ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        fork
            capture_frames();
        join_none
    endtask

    task capture_frames();
        forever begin
            @(m_vif.mon_cb);
            if (m_vif.mon_cb.rst_n_i !== 1'b1) continue;

            // Detect frame start: pcs_n falling edge
            if (m_vif.mon_cb.pcs_n_i === 1'b0) begin
                capture_one_frame();
            end
        end
    endtask

    task capture_one_frame();
        logic [559:0] rx_frame;
        int           rx_count;
        int           bpc;
        logic [1:0]   captured_lane_mode;
        bit           frame_abort;
        bit           opcode_latched;
        logic [7:0]   opcode_val;
        int           expected_bits;

        rx_frame       = '0;
        rx_count       = 0;
        frame_abort    = 0;
        opcode_latched = 0;
        expected_bits  = 0;
        captured_lane_mode = m_vif.mon_cb.lane_mode_i;
        bpc = get_bpc(captured_lane_mode);

        // Capture request phase
        while (m_vif.mon_cb.pcs_n_i === 1'b0) begin
            logic [15:0] pdi_sample;
            logic [15:0] bits_to_add;
            int i;

            pdi_sample = m_vif.mon_cb.pdi_i;

            // Mask and shift in bpc bits from MSB
            bits_to_add = pdi_sample & ((1 << bpc) - 1);
            for (i = 0; i < bpc; i++) begin
                rx_frame = {rx_frame[558:0], bits_to_add[bpc-1-i]};
            end
            rx_count += bpc;

            // Latch opcode after first 8 bits
            if (!opcode_latched && rx_count >= 8) begin
                opcode_val      = rx_frame[559:552];
                opcode_latched  = 1;
                expected_bits   = get_header_len(opcode_val);
            end

            @(m_vif.mon_cb);
        end

        // pcs_n went high - check for frame abort
        if (opcode_latched && rx_count < expected_bits) begin
            frame_abort = 1;
        end

        // Parse and send request transaction
        begin
            aplc_spi_transaction req_xtn;
            req_xtn = aplc_spi_transaction::type_id::create("req_xtn");
            req_xtn.m_lane_mode = captured_lane_mode;
            req_xtn.m_en        = m_vif.mon_cb.en_i;
            req_xtn.m_test_mode = m_vif.mon_cb.test_mode_i;
            req_xtn.m_frame_abort = frame_abort;

            if (opcode_latched) begin
                req_xtn.m_opcode = opcode_val;
                parse_request(rx_frame, rx_count, req_xtn);
            end

            `uvm_info(msg_id, $sformatf("Captured request: %s", req_xtn.convert2string()), UVM_HIGH)

            // Clone for each port (monitor isolation)
            begin
                aplc_spi_transaction req_clone;
                $cast(req_clone, req_xtn.clone());
                m_req_ap.write(req_clone);
            end
        end

        // Now capture response phase
        if (!frame_abort) begin
            capture_response(captured_lane_mode);
        end
    endtask

    task capture_response(logic [1:0] lane_mode);
        logic [559:0] resp_frame;
        int           resp_count;
        int           bpc;
        int           resp_bits;
        logic [7:0]   req_opcode;

        bpc = get_bpc(lane_mode);

        // Wait for pdo_oe to go high (response start)
        while (m_vif.mon_cb.pdo_oe_o !== 1'b1) begin
            @(m_vif.mon_cb);
            if (!m_vif.mon_cb.rst_n_i) return;
        end

        // Capture response bits
        resp_frame = '0;
        resp_count = 0;
        // We don't know the response length upfront without knowing the request opcode
        // Capture until pdo_oe goes low
        while (m_vif.mon_cb.pdo_oe_o === 1'b1) begin
            logic [15:0] pdo_sample;
            logic [15:0] bits_to_add;
            int i;

            pdo_sample = m_vif.mon_cb.pdo_o;
            bits_to_add = pdo_sample & ((1 << bpc) - 1);

            for (i = 0; i < bpc; i++) begin
                resp_frame = {resp_frame[558:0], bits_to_add[bpc-1-i]};
            end
            resp_count += bpc;

            @(m_vif.mon_cb);
            if (!m_vif.mon_cb.rst_n_i) return;
        end

        // Parse response
        begin
            aplc_spi_transaction resp_xtn;
            resp_xtn = aplc_spi_transaction::type_id::create("resp_xtn");
            resp_xtn.m_lane_mode = lane_mode;

            // Reconstruct response from captured bits
            // Response format: [status(8)] or [status(8) | rdata(32)*N]
            resp_xtn.m_status = resp_frame[resp_count-1 -: 8];

            if (resp_count > 8) begin
                int num_words = (resp_count - 8) / 32;
                resp_xtn.m_rdata = new[num_words];
                for (int i = 0; i < num_words; i++) begin
                    resp_xtn.m_rdata[i] = resp_frame[(resp_count - 8 - 32*i - 1) -: 32];
                end
                resp_xtn.m_has_rdata = 1;
            end else begin
                resp_xtn.m_has_rdata = 0;
            end

            `uvm_info(msg_id, $sformatf("Captured response: status=0x%02h has_rdata=%0b", resp_xtn.m_status, resp_xtn.m_has_rdata), UVM_HIGH)
            m_resp_ap.write(resp_xtn);
        end
    endtask

    function void parse_request(logic [559:0] frame, int bit_count, ref aplc_spi_transaction xtn);
        logic [7:0] opcode;
        opcode = frame[559:552];

        case (opcode)
            8'h10: begin // WR_CSR
                xtn.m_is_write = 1;
                if (bit_count >= 16) xtn.m_reg_addr = frame[551:544];
                if (bit_count >= 48) begin
                    xtn.m_wdata = new[1];
                    xtn.m_wdata[0] = frame[543:512];
                end
            end
            8'h11: begin // RD_CSR
                xtn.m_is_write = 0;
                if (bit_count >= 16) xtn.m_reg_addr = frame[551:544];
            end
            8'h20: begin // AHB_WR32
                xtn.m_is_write = 1;
                if (bit_count >= 40) xtn.m_ahb_addr = frame[551:520];
                if (bit_count >= 72) begin
                    xtn.m_wdata = new[1];
                    xtn.m_wdata[0] = frame[519:488];
                end
            end
            8'h21: begin // AHB_RD32
                xtn.m_is_write = 0;
                if (bit_count >= 40) xtn.m_ahb_addr = frame[551:520];
            end
            8'h22: begin // AHB_WR_BURST
                xtn.m_is_write = 1;
                if (bit_count >= 16) xtn.m_burst_len = frame[551:547];
                if (bit_count >= 48) xtn.m_ahb_addr = frame[535:504];
                // Payload wdata follows header
                if (bit_count > 48) begin
                    int n_beats = (bit_count - 48) / 32;
                    xtn.m_wdata = new[n_beats];
                    for (int i = 0; i < n_beats; i++) begin
                        xtn.m_wdata[i] = frame[(503-32*i) -: 32];
                    end
                end
            end
            8'h23: begin // AHB_RD_BURST
                xtn.m_is_write = 0;
                if (bit_count >= 16) xtn.m_burst_len = frame[551:547];
                if (bit_count >= 48) xtn.m_ahb_addr = frame[535:504];
            end
            default: begin
                // Bad opcode
            end
        endcase
    endfunction

    function int get_header_len(logic [7:0] opcode);
        case (opcode)
            8'h10: return 48;  // WR_CSR
            8'h11: return 16;  // RD_CSR
            8'h20: return 72;  // AHB_WR32
            8'h21: return 40;  // AHB_RD32
            8'h22: return 48;  // AHB_WR_BURST (header only)
            8'h23: return 48;  // AHB_RD_BURST
            default: return 8;
        endcase
    endfunction

    function int get_bpc(logic [1:0] lane_mode);
        case (lane_mode)
            2'b00: return 1;
            2'b01: return 4;
            2'b10: return 8;
            2'b11: return 16;
        endcase
    endfunction

endclass
