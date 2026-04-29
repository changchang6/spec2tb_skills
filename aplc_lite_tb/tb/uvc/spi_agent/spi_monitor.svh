// SPI Monitor for APLC_LITE
// Passively observes SPI bus, reconstructs command + response transactions

class spi_monitor extends uvm_monitor;

    `uvm_component_utils(spi_monitor)

    virtual spi_intf.MON_MP m_vif;
    spi_config m_cfg;
    uvm_analysis_port#(spi_xtn) m_ap;

    function new(string name = "spi_monitor", uvm_component parent = null);
        super.new(name, parent);
        m_ap = new("m_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        if (!uvm_config_db#(spi_config)::get(this, "", "spi_config", m_cfg)) begin
            `uvm_fatal(get_type_name(), "Cannot get spi_config from config_db")
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        m_vif = m_cfg.m_vif;
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(m_vif.mon_cb);
            if (!m_vif.mon_cb.pcs_n) begin
                observe_frame();
            end
        end
    endtask

    task observe_frame();
        logic [79:0] tx_shift;
        logic [79:0] rx_shift;
        int          tx_bit_count;
        int          rx_bit_count;
        int          lane_width;
        int          cycle_count;
        logic [7:0]  opcode;
        spi_xtn      txn;

        tx_shift = '0;
        rx_shift = '0;
        cycle_count = 0;
        lane_width = (1 << m_vif.mon_cb.lane_mode);

        while (!m_vif.mon_cb.pcs_n) begin
            logic [15:0] pdi_data;
            pdi_data = m_vif.mon_cb.pdi;

            case (lane_width)
                1:  tx_shift = {tx_shift[78:0], pdi_data[0]};
                4:  tx_shift = {tx_shift[75:0], pdi_data[3:0]};
                8:  tx_shift = {tx_shift[71:0], pdi_data[7:0]};
                16: tx_shift = {tx_shift[63:0], pdi_data[15:0]};
            endcase
            cycle_count++;
            @(m_vif.mon_cb);
        end

        tx_bit_count = cycle_count * lane_width;
        opcode = tx_shift[79:72];

        case (opcode)
            8'h10: tx_bit_count = 48;   // WR_CSR
            8'h11: tx_bit_count = 16;   // RD_CSR
            8'h20: tx_bit_count = 72;   // AHB_WR32
            8'h21: tx_bit_count = 40;   // AHB_RD32
            8'h22: tx_bit_count = 48;   // AHB_WR_BURST header
            8'h23: tx_bit_count = 48;   // AHB_RD_BURST header
            default: tx_bit_count = cycle_count * lane_width;
        endcase

        if (cycle_count * lane_width > tx_bit_count) begin
            tx_shift = tx_shift << (cycle_count * lane_width - tx_bit_count);
        end

        txn = spi_xtn::type_id::create("txn");
        txn.m_opcode    = opcode;
        txn.m_lane_mode = m_vif.mon_cb.lane_mode;

        case (opcode)
            8'h10: begin // WR_CSR
                txn.m_reg_addr = tx_shift[71:64];
                txn.m_wdata    = tx_shift[63:32];
            end
            8'h11: begin // RD_CSR
                txn.m_reg_addr = tx_shift[71:64];
            end
            8'h20: begin // AHB_WR32
                txn.m_addr  = tx_shift[63:32];
                txn.m_wdata = tx_shift[31:0];
            end
            8'h21: begin // AHB_RD32
                txn.m_addr = tx_shift[63:32];
            end
            8'h22, 8'h23: begin // AHB_WR_BURST / AHB_RD_BURST
                txn.m_burst_len = tx_shift[74:70];
                txn.m_addr      = tx_shift[63:32];
            end
        endcase

        rx_bit_count = txn.get_rx_bit_count();

        if (rx_bit_count > 0) begin
            int rx_cycles;

            cycle_count = 0;
            while (!m_vif.mon_cb.pdo_oe && cycle_count < 5000) begin
                @(m_vif.mon_cb);
                cycle_count++;
            end

            rx_cycles = 0;
            while (m_vif.mon_cb.pdo_oe && rx_cycles * lane_width < rx_bit_count + lane_width) begin
                logic [15:0] pdo_data;
                pdo_data = m_vif.mon_cb.pdo;

                case (lane_width)
                    1:  rx_shift = {rx_shift[78:0], pdo_data[0]};
                    4:  rx_shift = {rx_shift[75:0], pdo_data[3:0]};
                    8:  rx_shift = {rx_shift[71:0], pdo_data[7:0]};
                    16: rx_shift = {rx_shift[63:0], pdo_data[15:0]};
                endcase
                rx_cycles++;
                @(m_vif.mon_cb);
            end

            if (rx_cycles * lane_width > rx_bit_count) begin
                rx_shift = rx_shift << (rx_cycles * lane_width - rx_bit_count);
            end

            txn.m_resp_status = rx_shift[79:72];
            if (rx_bit_count > 8) begin
                txn.m_resp_rdata  = rx_shift[71:40];
                txn.m_resp_has_rdata = 1'b1;
            end
        end

        `uvm_info(get_type_name(), $sformatf("Observed: %s", txn.convert2string()), UVM_HIGH)
        m_ap.write(txn);
    endtask

endclass
