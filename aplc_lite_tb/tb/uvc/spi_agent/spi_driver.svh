// APLC-Lite SPI Driver
// Drives the external test IO interface (pcs_n, pdi, lane_mode, en, test_mode)
// according to the half-duplex protocol defined in LRS
// Key: pcs_n must stay LOW for the entire transaction (request + turnaround + response)
class spi_driver extends uvm_driver #(spi_xtn);

    `uvm_component_utils(spi_driver)

    virtual spi_if vif;
    spi_config m_config;

    // Opcode constants
    localparam logic [7:0] OP_WR_CSR       = 8'h10;
    localparam logic [7:0] OP_RD_CSR       = 8'h11;
    localparam logic [7:0] OP_AHB_WR32     = 8'h20;
    localparam logic [7:0] OP_AHB_RD32     = 8'h21;
    localparam logic [7:0] OP_AHB_WR_BURST = 8'h22;
    localparam logic [7:0] OP_AHB_RD_BURST = 8'h23;

    function new(string name = "spi_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(spi_config)::get(this, "", "cfg", m_config))
            `uvm_fatal(get_type_name(), "spi_config not found")
        vif = m_config.m_vif;
    endfunction

    task run_phase(uvm_phase phase);
        init_signals();
        forever begin
            seq_item_port.try_next_item(req);
            if (req != null) begin
                drive_transaction(req);
                seq_item_port.item_done();
            end else begin
                @(vif.drv_cb);
            end
        end
    endtask

    task init_signals();
        vif.drv_cb.pcs_n     <= 1'b1;
        vif.drv_cb.pdi       <= 16'b0;
        vif.drv_cb.en        <= 1'b1;
        vif.drv_cb.test_mode <= 1'b1;
        vif.drv_cb.lane_mode <= 2'b00; // match DUT reset default (1-bit)
    endtask

    task drive_transaction(spi_xtn xtn);
        logic [79:0] frame;
        int unsigned frame_bits;
        int unsigned bpc;

        vif.drv_cb.lane_mode <= xtn.lane_mode;
        bpc = get_bpc(xtn.lane_mode);

        build_frame(xtn, frame, frame_bits);
        // Keep pcs_n low for entire transaction (request + response)
        drive_request(frame, frame_bits, bpc);
        capture_response(xtn, bpc);
        // Release pcs_n only after the full transaction is complete
        vif.drv_cb.pcs_n <= 1'b1;
        vif.drv_cb.pdi   <= 16'b0;
        @(vif.drv_cb);
    endtask

    function int get_bpc(logic [1:0] lane_mode);
        case (lane_mode)
            2'b00: return 1;
            2'b01: return 4;
            2'b10: return 8;
            2'b11: return 16;
        endcase
        return 16;
    endfunction

    task build_frame(spi_xtn xtn, output logic [79:0] frame, output int unsigned frame_bits);
        frame = 80'b0;
        case (xtn.opcode)
            OP_WR_CSR: begin
                frame[79:72] = xtn.opcode;
                frame[71:64] = xtn.reg_addr;
                frame[63:32] = (xtn.wdata.size() > 0) ? xtn.wdata[0] : 32'b0;
                frame_bits = 48;
            end
            OP_RD_CSR: begin
                frame[79:72] = xtn.opcode;
                frame[71:64] = xtn.reg_addr;
                frame_bits = 16;
            end
            OP_AHB_WR32: begin
                frame[79:72] = xtn.opcode;
                frame[71:40] = xtn.addr;
                frame[39:8]  = (xtn.wdata.size() > 0) ? xtn.wdata[0] : 32'b0;
                frame_bits = 72;
            end
            OP_AHB_RD32: begin
                frame[79:72] = xtn.opcode;
                frame[71:40] = xtn.addr;
                frame_bits = 40;
            end
            OP_AHB_WR_BURST: begin
                frame[79:72] = xtn.opcode;
                frame[71:67] = xtn.burst_len;
                frame[66:64] = 3'b000;
                frame[63:32] = xtn.addr;
                frame_bits = 48;
            end
            OP_AHB_RD_BURST: begin
                frame[79:72] = xtn.opcode;
                frame[71:67] = xtn.burst_len;
                frame[66:64] = 3'b000;
                frame[63:32] = xtn.addr;
                frame_bits = 48;
            end
            default: begin
                frame[79:72] = xtn.opcode;
                frame_bits = 8;
            end
        endcase
    endtask

    task drive_request(logic [79:0] frame, int unsigned frame_bits, int unsigned bpc);
        int unsigned bits_sent;
        logic [15:0] pdi_chunk;

        bits_sent = 0;

        // Send frame data MSB-first, starting with pcs_n assertion
        while (bits_sent < frame_bits) begin
            pdi_chunk = 16'b0;
            case (bpc)
                16: pdi_chunk = frame[79:64];
                 8: pdi_chunk = {frame[79:72], 8'b0};
                 4: pdi_chunk = {frame[79:76], 12'b0};
                 1: pdi_chunk = {15'b0, frame[79]};
            endcase
            vif.drv_cb.pcs_n <= 1'b0;
            vif.drv_cb.pdi   <= pdi_chunk;

            frame = frame << bpc;
            bits_sent += bpc;

            @(vif.drv_cb);
        end

        // Clear pdi after request, but keep pcs_n low (response is coming)
        vif.drv_cb.pdi <= 16'b0;
    endtask

    task capture_response(spi_xtn xtn, int unsigned bpc);
        int timeout_cnt;
        logic [7:0]  resp_status;
        logic [31:0] resp_rdata;
        logic [15:0] pdo_chunk;
        int unsigned bits_captured;
        int unsigned resp_bits;
        logic [559:0] resp_shift;

        // Determine expected response length
        case (xtn.opcode)
            OP_RD_CSR:       resp_bits = 40;
            OP_AHB_RD32:     resp_bits = 40;
            OP_AHB_RD_BURST: resp_bits = 8 + 32 * xtn.burst_len;
            default:         resp_bits = 8;
        endcase

        // Wait for DUT to drive response (pdo_oe goes high)
        // This includes the 1-cycle turnaround
        timeout_cnt = 0;
        while (vif.drv_cb.pdo_oe !== 1'b1 && timeout_cnt < 10000) begin
            @(vif.drv_cb);
            timeout_cnt++;
        end
        if (timeout_cnt >= 10000) begin
            `uvm_error(get_type_name(), "Timeout waiting for DUT response (pdo_oe)")
            return;
        end

        // Capture response bits from pdo
        resp_shift = 560'b0;
        bits_captured = 0;
        while (bits_captured < resp_bits && vif.drv_cb.pdo_oe === 1'b1) begin
            pdo_chunk = vif.drv_cb.pdo;
            case (bpc)
                16: resp_shift = {resp_shift[543:0], pdo_chunk};
                 8: resp_shift = {resp_shift[551:0], pdo_chunk[15:8]};
                 4: resp_shift = {resp_shift[555:0], pdo_chunk[15:12]};
                 1: resp_shift = {resp_shift[558:0], pdo_chunk[0]};
            endcase
            bits_captured += bpc;
            @(vif.drv_cb);
        end

        // Left-justify captured data to MSB for correct fixed-position parsing
        if (bits_captured > 0 && bits_captured < 560)
            resp_shift = resp_shift << (560 - bits_captured);

        // Parse response - status is always first 8 bits
        resp_status = resp_shift[559:552];
        xtn.status = resp_status;

        if (resp_bits > 8) begin
            resp_rdata = resp_shift[551:520];
            xtn.rdata = resp_rdata;
        end

        `uvm_info(get_type_name(), $sformatf("Captured response: opcode=0x%02h status=0x%02h rdata=0x%08h", xtn.opcode, xtn.status, xtn.rdata), UVM_HIGH)
    endtask

endclass
