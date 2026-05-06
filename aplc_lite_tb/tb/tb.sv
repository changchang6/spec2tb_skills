// APLC-Lite Top Testbench
module aplc_tb_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // -------------------- Parameters --------------------
    parameter CLK_PERIOD = 10; // 100 MHz

    // -------------------- Signals --------------------
    logic        clk;
    logic        rst_n;

    // -------------------- Interfaces --------------------
    spi_intf  spi_if_inst(.clk_i(clk), .rst_n_i(rst_n));
    csr_intf  csr_if_inst(.clk_i(clk), .rst_n_i(rst_n));

    // AHB VIP interface
    `define YUU_AHB_MAX_MASTER_NUM 1
    `define YUU_AHB_MAX_SLAVE_NUM  1
    `define YUU_AHB_MAX_ADDR_WIDTH 32
    `define YUU_AHB_MAX_DATA_WIDTH 32
    `define YUU_AHB_SLAVE_SETUP_TIME 0
    `define YUU_AHB_SLAVE_HOLD_TIME  0

    yuu_ahb_interface ahb_if_inst();

    // -------------------- Clock Generation --------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // -------------------- Reset Generation --------------------
    initial begin
        rst_n = 0;
        #200ns;
        rst_n = 1;
    end

    // -------------------- AHB VIP clock/reset --------------------
    assign ahb_if_inst.hclk     = clk;
    assign ahb_if_inst.hreset_n = rst_n;

    // -------------------- DUT Instance --------------------
    APLC_LITE dut (
        .clk_i           (clk),
        .rst_n_i         (rst_n),
        .en_i            (spi_if_inst.en),
        .test_mode_i     (spi_if_inst.test_mode),
        .pcs_n_i         (spi_if_inst.pcs_n),
        .pdi_i           (spi_if_inst.pdi),
        .pdo_o           (spi_if_inst.pdo),
        .pdo_oe_o        (spi_if_inst.pdo_oe),
        .lane_mode_i     (spi_if_inst.lane_mode),
        .rxfifo_empty_o  (spi_if_inst.rxfifo_empty),
        .rxfifo_full_o   (spi_if_inst.rxfifo_full),
        .txfifo_empty_o  (spi_if_inst.txfifo_empty),
        .txfifo_full_o   (spi_if_inst.txfifo_full),
        .csr_rd_en_o     (csr_if_inst.csr_rd_en),
        .csr_wr_en_o     (csr_if_inst.csr_wr_en),
        .csr_addr_o      (csr_if_inst.csr_addr),
        .csr_wdata_o     (csr_if_inst.csr_wdata),
        .csr_rdata_i     (csr_if_inst.csr_rdata),
        .haddr_o         (ahb_if_inst.slave_if[0].haddr[31:0]),
        .hwrite_o        (ahb_if_inst.slave_if[0].hwrite),
        .htrans_o        (ahb_if_inst.slave_if[0].htrans),
        .hsize_o         (ahb_if_inst.slave_if[0].hsize),
        .hburst_o        (ahb_if_inst.slave_if[0].hburst),
        .hwdata_o        (ahb_if_inst.slave_if[0].hwdata[31:0]),
        .hrdata_i        (ahb_if_inst.slave_if[0].hrdata[31:0]),
        .hready_i        (ahb_if_inst.slave_if[0].hready_o),
        .hresp_i         (ahb_if_inst.slave_if[0].hresp[0])
    );

    // AHB slave select (always selected for test)
    assign ahb_if_inst.slave_if[0].hsel = 1'b1;
    assign ahb_if_inst.slave_if[0].hready_i = 1'b1;

    // -------------------- Debug: Track response data path --------------------
    logic [559:0] dbg_resp_shift;
    int           dbg_resp_bits;
    always @(posedge clk) begin
        if (rst_n && dut.u_taskallo.u_sctrl.state == 3'd3) begin // WAIT_RESP
            $display("[FRONT_WAIT] %0t: rdata_reg=0x%08h resp_valid=%b resp_rdata=0x%08h resp_has_rdata=%b",
                $time, dut.u_taskallo.u_sctrl.rdata_reg,
                dut.u_taskallo.resp_valid_i, dut.u_taskallo.resp_rdata_i,
                dut.u_taskallo.resp_has_rdata_i);
        end
        if (rst_n && dut.u_taskallo.u_sctrl.state == 3'd4) begin // TA
            $display("[FRONT_TA] %0t: rdata_reg=0x%08h has_rdata=%b tx_start=%b",
                $time, dut.u_taskallo.u_sctrl.rdata_reg,
                dut.u_taskallo.u_sctrl.has_rdata_reg,
                dut.u_taskallo.tx_start);
        end
        if (rst_n && dut.pdo_oe_o === 1'b1) begin
            $display("[DUT_TX] %0t: saxis_shift=0x%010h saxis_cnt=%0d front_state=%0d rdata_reg=0x%08h has_rdata=%b lane=%b",
                $time, dut.u_taskallo.u_saxis.tx_shift_q,
                dut.u_taskallo.u_saxis.tx_count_q,
                dut.u_taskallo.u_sctrl.state,
                dut.u_taskallo.u_sctrl.rdata_reg,
                dut.u_taskallo.u_sctrl.has_rdata_reg,
                dut.lane_mode_i);
        end
        if (rst_n && dut.pdo_oe_o === 1'b0 && dbg_resp_bits > 0) begin
            $display("[DUT_RESP] %0t: Response done, bits=%0d", $time, dbg_resp_bits);
            dbg_resp_shift = 560'b0;
            dbg_resp_bits = 0;
        end
        if (rst_n && dut.pdo_oe_o === 1'b1) begin
            case (dut.lane_mode_i)
                2'b11: begin
                    dbg_resp_shift = {dbg_resp_shift[543:0], dut.pdo_o};
                    dbg_resp_bits += 16;
                end
                2'b00: begin
                    dbg_resp_shift = {dbg_resp_shift[558:0], dut.pdo_o[0]};
                    dbg_resp_bits += 1;
                end
            endcase
        end
        if (!rst_n) begin
            dbg_resp_shift = 560'b0;
            dbg_resp_bits = 0;
        end
    end

    // -------------------- Debug: Monitor CSR bus --------------------
    always @(posedge clk) begin
        if (rst_n && (csr_if_inst.csr_rd_en || csr_if_inst.csr_wr_en)) begin
            $strobe("[CSR_DBG] %0t: %s addr=0x%02h wdata=0x%08h rdata=0x%08h",
                $time,
                csr_if_inst.csr_wr_en ? "WR" : "RD",
                csr_if_inst.csr_addr,
                csr_if_inst.csr_wdata,
                csr_if_inst.csr_rdata);
        end
    end

    // -------------------- Waveform Dump --------------------
    `ifdef DUMP_FSDB
    initial begin
        $fsdbDumpfile("aplc_tb.fsdb");
        $fsdbDumpvars(0, aplc_tb_top);
    end
    `endif

    // -------------------- Timeout --------------------
    initial begin
        #100ms;
        $display("[FATAL] Simulation timeout at %0t", $time);
        $finish;
    end

    // -------------------- UVM Setup --------------------
    initial begin
        // Set interface handles in config_db
        uvm_config_db #(virtual spi_intf)::set(null, "*", "spi_vif", spi_if_inst);
        uvm_config_db #(virtual spi_intf.drv_mp)::set(null, "uvm_test_top.m_env.m_spi_agent.m_driver", "vif", spi_if_inst.drv_mp);
        uvm_config_db #(virtual spi_intf.mon_mp)::set(null, "uvm_test_top.m_env.m_spi_agent.m_monitor", "vif", spi_if_inst.mon_mp);
        uvm_config_db #(virtual csr_intf)::set(null, "*", "csr_vif", csr_if_inst);
        uvm_config_db #(virtual csr_intf.drv_mp)::set(null, "uvm_test_top.m_env.m_csr_agent.m_driver", "vif", csr_if_inst.drv_mp);
        uvm_config_db #(virtual csr_intf.mon_mp)::set(null, "uvm_test_top.m_env.m_csr_agent.m_monitor", "vif", csr_if_inst.mon_mp);

        // AHB VIP interface
        uvm_config_db #(virtual yuu_ahb_interface)::set(null, "*", "yuu_ahb_interface", ahb_if_inst);

        run_test();
    end

endmodule
