// APLC-Lite SPI Monitor
// Observes the external test IO interface and creates transactions
// Two analysis ports: req_ap for request transactions, resp_ap for response transactions
class spi_monitor extends uvm_monitor;

    `uvm_component_utils(spi_monitor)

    uvm_analysis_port #(spi_xtn) req_ap;
    uvm_analysis_port #(spi_xtn) resp_ap;
    virtual spi_if vif;
    spi_config m_config;

    function new(string name = "spi_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        req_ap  = new("req_ap", this);
        resp_ap = new("resp_ap", this);
        if (!uvm_config_db #(spi_config)::get(this, "", "cfg", m_config))
            `uvm_fatal(get_type_name(), "spi_config not found")
        vif = m_config.m_vif;
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(vif.mon_cb);
            if (vif.mon_cb.pcs_n === 1'b0) begin
                capture_frame();
            end
        end
    endtask

    task capture_frame();
        spi_xtn xtn;
        logic [79:0] rx_shift;
        int unsigned rx_count;
        int unsigned bpc;
        logic [7:0]  opcode_latched;
        int unsigned expected_bits;
        bit frame_valid;
        bit req_sent;
        bit resp_captured;
        int timeout_cnt;

        xtn = spi_xtn::type_id::create("xtn");
        xtn.lane_mode = vif.mon_cb.lane_mode;
        bpc = get_bpc(xtn.lane_mode);

        rx_shift = 80'b0;
        rx_count = 0;
        expected_bits = 0;
        opcode_latched = 8'h00;
        frame_valid = 0;
        req_sent = 0;
        resp_captured = 0;

        // Capture entire transaction (request + turnaround + response) while pcs_n is low
        while (vif.mon_cb.pcs_n === 1'b0) begin
            // Request phase: shift in pdi data
            if (!frame_valid) begin
                case (bpc)
                    16: rx_shift = {rx_shift[63:0], vif.mon_cb.pdi};
                     8: rx_shift = {rx_shift[71:0], vif.mon_cb.pdi[15:8]};
                     4: rx_shift = {rx_shift[75:0], vif.mon_cb.pdi[15:12]};
                     1: rx_shift = {rx_shift[78:0], vif.mon_cb.pdi[0]};
                endcase
                rx_count += bpc;

                if (rx_count >= 8 && opcode_latched == 8'h00) begin
                    opcode_latched = rx_shift[79:72];
                    xtn.opcode = opcode_latched;
                    expected_bits = get_expected_bits(opcode_latched);
                end

                if (expected_bits > 0 && rx_count >= expected_bits) begin
                    frame_valid = 1;
                    parse_frame(xtn, rx_shift, opcode_latched);
                end
            end

            // Send request as soon as frame is decoded
            if (frame_valid && !req_sent) begin
                xtn.is_csr   = xtn.opcode inside {8'h10, 8'h11};
                xtn.is_ahb   = xtn.opcode inside {8'h20, 8'h21, 8'h22, 8'h23};
                xtn.is_read  = xtn.opcode inside {8'h11, 8'h21, 8'h23};
                xtn.is_burst = xtn.opcode inside {8'h22, 8'h23};
                xtn.en        = vif.mon_cb.en;
                xtn.test_mode = vif.mon_cb.test_mode;
                req_ap.write(xtn);
                req_sent = 1;
            end

            // Response phase: capture pdo data when pdo_oe is asserted
            if (req_sent && !resp_captured && vif.mon_cb.pdo_oe === 1'b1) begin
                capture_response_inline(xtn, bpc);
                resp_captured = 1;
            end

            @(vif.mon_cb);
        end

        // If frame was valid but response not yet captured (pdo_oe may have been too brief),
        // try to capture now. Also handle the case where response comes after pcs_n edge.
        if (frame_valid && req_sent) begin
            if (!resp_captured) begin
                // Wait briefly for response
                timeout_cnt = 0;
                while (vif.mon_cb.pdo_oe !== 1'b1 && timeout_cnt < 100) begin
                    @(vif.mon_cb);
                    timeout_cnt++;
                end
                if (vif.mon_cb.pdo_oe === 1'b1) begin
                    capture_response_inline(xtn, bpc);
                    resp_captured = 1;
                end
            end

            `uvm_info(get_type_name(), $sformatf("Captured: opcode=0x%02h status=0x%02h rdata=0x%08h",
                xtn.opcode, xtn.status, xtn.rdata), UVM_HIGH)

            // Send response on resp_ap
            resp_ap.write(xtn);
        end

    endtask

    task capture_response_inline(spi_xtn xtn, int unsigned bpc);
        logic [559:0] resp_shift;
        int unsigned bits_captured;
        int unsigned resp_bits;
        logic [15:0] pdo_chunk;

        case (xtn.opcode)
            8'h11:         resp_bits = 40; // RD_CSR
            8'h21:         resp_bits = 40; // AHB_RD32
            8'h23:         resp_bits = 8 + 32 * xtn.burst_len; // AHB_RD_BURST
            default:       resp_bits = 8;
        endcase

        resp_shift = 560'b0;
        bits_captured = 0;
        while (bits_captured < resp_bits && vif.mon_cb.pdo_oe === 1'b1) begin
            pdo_chunk = vif.mon_cb.pdo;
            case (bpc)
                16: resp_shift = {resp_shift[543:0], pdo_chunk};
                 8: resp_shift = {resp_shift[551:0], pdo_chunk[15:8]};
                 4: resp_shift = {resp_shift[555:0], pdo_chunk[15:12]};
                 1: resp_shift = {resp_shift[558:0], pdo_chunk[0]};
            endcase
            bits_captured += bpc;
            @(vif.mon_cb);
        end

        // Left-justify captured data to MSB for correct fixed-position parsing
        if (bits_captured > 0 && bits_captured < 560)
            resp_shift = resp_shift << (560 - bits_captured);

        xtn.status = resp_shift[559:552];
        if (resp_bits > 8) begin
            xtn.rdata = resp_shift[551:520];
        end
    endtask

    function void parse_frame(spi_xtn xtn, logic [79:0] rx_shift, logic [7:0] opcode);
        case (opcode)
            8'h10: begin // WR_CSR
                xtn.reg_addr = rx_shift[71:64];
                xtn.wdata = new[1];
                xtn.wdata[0] = rx_shift[63:32];
            end
            8'h11: begin // RD_CSR
                xtn.reg_addr = rx_shift[71:64];
            end
            8'h20: begin // AHB_WR32
                xtn.addr  = rx_shift[71:40];
                xtn.wdata = new[1];
                xtn.wdata[0] = rx_shift[39:8];
            end
            8'h21: begin // AHB_RD32
                xtn.addr = rx_shift[71:40];
            end
            8'h22, 8'h23: begin // AHB_WR_BURST, AHB_RD_BURST
                xtn.burst_len = rx_shift[71:67];
                xtn.addr      = rx_shift[63:32];
            end
        endcase
    endfunction

    function int get_bpc(logic [1:0] lane_mode);
        case (lane_mode)
            2'b00: return 1;
            2'b01: return 4;
            2'b10: return 8;
            2'b11: return 16;
        endcase
        return 16;
    endfunction

    function int get_expected_bits(logic [7:0] opcode);
        case (opcode)
            8'h10: return 48;
            8'h11: return 16;
            8'h20: return 72;
            8'h21: return 40;
            8'h22: return 48;
            8'h23: return 48;
            default: return 80;
        endcase
    endfunction

endclass
