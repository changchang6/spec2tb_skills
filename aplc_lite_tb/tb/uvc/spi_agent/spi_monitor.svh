// APLC-Lite SPI Monitor
// Observes the external test IO interface and creates transactions
class spi_monitor extends uvm_monitor;

    `uvm_component_utils(spi_monitor)

    uvm_analysis_port #(spi_xtn) ap;
    virtual spi_intf.mon_mp vif;
    spi_config m_config;

    function new(string name = "spi_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(spi_config)::get(this, "", "spi_config", m_config))
            `uvm_fatal(get_type_name(), "spi_config not found")
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (!uvm_config_db #(virtual spi_intf.mon_mp)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "vif not found")
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
        int timeout_cnt;

        xtn = spi_xtn::type_id::create("xtn");
        xtn.lane_mode = vif.mon_cb.lane_mode;
        bpc = get_bpc(xtn.lane_mode);

        rx_shift = 80'b0;
        rx_count = 0;
        expected_bits = 0;
        opcode_latched = 8'h00;
        frame_valid = 0;

        // Capture request phase
        while (vif.mon_cb.pcs_n === 1'b0) begin
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

            if (expected_bits > 0 && rx_count >= expected_bits && !frame_valid) begin
                frame_valid = 1;
                parse_frame(xtn, rx_shift, opcode_latched);
            end

            @(vif.mon_cb);
        end

        if (frame_valid) begin
            // Wait for response phase (pdo_oe goes high after turnaround)
            timeout_cnt = 0;
            while (vif.mon_cb.pdo_oe !== 1'b1 && timeout_cnt < 10000) begin
                @(vif.mon_cb);
                timeout_cnt++;
            end

            if (vif.mon_cb.pdo_oe === 1'b1) begin
                capture_response(xtn, bpc);
            end

            `uvm_info(get_type_name(), $sformatf("Captured: opcode=0x%02h status=0x%02h rdata=0x%08h",
                xtn.opcode, xtn.status, xtn.rdata), UVM_HIGH)
        end

        ap.write(xtn);
    endtask

    task capture_response(spi_xtn xtn, int unsigned bpc);
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

        xtn.status = resp_shift[559:552];
        if (resp_bits > 8) begin
            xtn.rdata = resp_shift[551:520];
        end
    endtask

    function void parse_frame(spi_xtn xtn, logic [79:0] rx_shift, logic [7:0] opcode);
        case (opcode)
            8'h10: begin // WR_CSR
                xtn.reg_addr = rx_shift[71:64];
                xtn.wdata    = rx_shift[63:32];
            end
            8'h11: begin // RD_CSR
                xtn.reg_addr = rx_shift[71:64];
            end
            8'h20: begin // AHB_WR32
                xtn.addr  = rx_shift[71:40];
                xtn.wdata = rx_shift[39:8];
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
