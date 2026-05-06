// APLC-Lite Base Virtual Sequence
class aplc_base_vseq extends uvm_sequence;

    `uvm_object_utils(aplc_base_vseq)
    `uvm_declare_p_sequencer(aplc_vsequencer)

    function new(string name = "aplc_base_vseq");
        super.new(name);
    endfunction

    // Helper: create and send a WR_CSR command
    task send_wr_csr(logic [7:0] addr, logic [31:0] data, logic [1:0] lane = 2'b11, output logic [7:0] status);
        spi_xtn xtn;
        xtn = spi_xtn::type_id::create("xtn");
        start_item(xtn, -1, p_sequencer.spi_seqr);
        xtn.opcode    = 8'h10; // WR_CSR
        xtn.reg_addr  = addr;
        xtn.wdata     = data;
        xtn.lane_mode = lane;
        xtn.burst_len = 5'd0;
        finish_item(xtn);
        status = xtn.status;
    endtask

    // Helper: create and send a RD_CSR command
    task send_rd_csr(logic [7:0] addr, logic [1:0] lane = 2'b11, output logic [7:0] status, output logic [31:0] rdata);
        spi_xtn xtn;
        xtn = spi_xtn::type_id::create("xtn");
        start_item(xtn, -1, p_sequencer.spi_seqr);
        xtn.opcode    = 8'h11; // RD_CSR
        xtn.reg_addr  = addr;
        xtn.lane_mode = lane;
        xtn.burst_len = 5'd0;
        finish_item(xtn);
        status = xtn.status;
        rdata  = xtn.rdata;
    endtask

    // Helper: create and send a AHB_WR32 command
    task send_ahb_wr32(logic [31:0] addr, logic [31:0] data, logic [1:0] lane = 2'b11, output logic [7:0] status);
        spi_xtn xtn;
        xtn = spi_xtn::type_id::create("xtn");
        start_item(xtn, -1, p_sequencer.spi_seqr);
        xtn.opcode    = 8'h20; // AHB_WR32
        xtn.addr      = addr;
        xtn.wdata     = data;
        xtn.lane_mode = lane;
        xtn.burst_len = 5'd0;
        finish_item(xtn);
        status = xtn.status;
    endtask

    // Helper: create and send a AHB_RD32 command
    task send_ahb_rd32(logic [31:0] addr, logic [1:0] lane = 2'b11, output logic [7:0] status, output logic [31:0] rdata);
        spi_xtn xtn;
        xtn = spi_xtn::type_id::create("xtn");
        start_item(xtn, -1, p_sequencer.spi_seqr);
        xtn.opcode    = 8'h21; // AHB_RD32
        xtn.addr      = addr;
        xtn.lane_mode = lane;
        xtn.burst_len = 5'd0;
        finish_item(xtn);
        status = xtn.status;
        rdata  = xtn.rdata;
    endtask

endclass
