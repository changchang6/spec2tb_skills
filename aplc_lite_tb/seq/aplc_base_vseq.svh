class aplc_base_vseq extends uvm_sequence;

    `uvm_object_utils(aplc_base_vseq)
    `uvm_declare_p_sequencer(spi_sequencer)

    function new(string name = "aplc_base_vseq");
        super.new(name);
    endfunction

    task pre_start();
        uvm_phase phase;
        phase = get_starting_phase();
        if (phase != null)
            phase.raise_objection(this);
    endtask

    task post_start();
        uvm_phase phase;
        phase = get_starting_phase();
        if (phase != null)
            phase.drop_objection(this);
    endtask

    // Helper: create and send a WR_CSR request
    task send_wr_csr(bit [7:0] addr, bit [31:0] data, bit [1:0] lane = 2'b11);
        spi_xtn req;
        req = spi_xtn::type_id::create("req");
        req.opcode    = 8'h10;
        req.reg_addr  = addr;
        req.wdata     = new[1];
        req.wdata[0]  = data;
        req.lane_mode = lane;
        req.en        = 1'b1;
        req.test_mode = 1'b1;
        req.burst_len = 0;
        `uvm_send(req)
    endtask

    // Helper: create and send a RD_CSR request
    task send_rd_csr(bit [7:0] addr, bit [1:0] lane = 2'b11);
        spi_xtn req;
        req = spi_xtn::type_id::create("req");
        req.opcode    = 8'h11;
        req.reg_addr  = addr;
        req.lane_mode = lane;
        req.en        = 1'b1;
        req.test_mode = 1'b1;
        req.burst_len = 0;
        req.wdata     = new[0];
        `uvm_send(req)
    endtask

    // Helper: create and send AHB_WR32
    task send_ahb_wr32(bit [31:0] addr, bit [31:0] data, bit [1:0] lane = 2'b11);
        spi_xtn req;
        req = spi_xtn::type_id::create("req");
        req.opcode    = 8'h20;
        req.addr      = addr;
        req.wdata     = new[1];
        req.wdata[0]  = data;
        req.lane_mode = lane;
        req.en        = 1'b1;
        req.test_mode = 1'b1;
        req.burst_len = 0;
        `uvm_send(req)
    endtask

    // Helper: create and send AHB_RD32
    task send_ahb_rd32(bit [31:0] addr, bit [1:0] lane = 2'b11);
        spi_xtn req;
        req = spi_xtn::type_id::create("req");
        req.opcode    = 8'h21;
        req.addr      = addr;
        req.lane_mode = lane;
        req.en        = 1'b1;
        req.test_mode = 1'b1;
        req.burst_len = 0;
        req.wdata     = new[0];
        `uvm_send(req)
    endtask

    // Helper: send a request with specific en/test_mode for error testing
    task send_req_with_config(bit [7:0] opcode, bit [7:0] reg_addr, bit [31:0] addr,
                              bit en, bit test_mode, bit [1:0] lane = 2'b11);
        spi_xtn req;
        req = spi_xtn::type_id::create("req");
        req.opcode    = opcode;
        req.reg_addr  = reg_addr;
        req.addr      = addr;
        req.lane_mode = lane;
        req.en        = en;
        req.test_mode = test_mode;
        req.burst_len = 0;
        req.wdata     = new[1];
        req.wdata[0]  = 32'hDEAD_BEEF;
        `uvm_send(req)
    endtask

endclass
