// APLC-Lite Base Sequence
`ifndef APLC_BASE_SEQ_SVH
`define APLC_BASE_SEQ_SVH

class aplc_base_seq extends uvm_sequence #(aplc_spi_txn);
    `uvm_object_utils(aplc_base_seq)
    `uvm_declare_p_sequencer(aplc_spi_sequencer)

    function new(string name = "aplc_base_seq");
        super.new(name);
    endfunction

    task pre_start();
        if (starting_phase != null) begin
            starting_phase.raise_objection(this);
            starting_phase.get_objection().set_propagate_mode(0);
        end
    endtask

    task post_start();
        if (starting_phase != null) begin
            starting_phase.drop_objection(this);
        end
    endtask

    task send_txn(aplc_spi_txn txn);
        start_item(txn);
        finish_item(txn);
    endtask

    task send_wr_csr(bit [5:0] addr, bit [31:0] data, bit [1:0] lane = 2'b00);
        aplc_spi_txn txn;
        txn = aplc_spi_txn::type_id::create("txn");
        txn.m_opcode    = 8'h10;
        txn.m_reg_addr  = {2'b00, addr};
        txn.m_wdata     = new[1];
        txn.m_wdata[0]  = data;
        txn.m_lane_mode = lane;
        txn.m_is_read   = 0;
        txn.m_is_burst  = 0;
        send_txn(txn);
    endtask

    task send_rd_csr(bit [5:0] addr, bit [1:0] lane = 2'b00);
        aplc_spi_txn txn;
        txn = aplc_spi_txn::type_id::create("txn");
        txn.m_opcode    = 8'h11;
        txn.m_reg_addr  = {2'b00, addr};
        txn.m_lane_mode = lane;
        txn.m_is_read   = 1;
        txn.m_is_burst  = 0;
        send_txn(txn);
    endtask

    task send_ahb_wr32(bit [31:0] addr, bit [31:0] data, bit [1:0] lane = 2'b00);
        aplc_spi_txn txn;
        txn = aplc_spi_txn::type_id::create("txn");
        txn.m_opcode    = 8'h20;
        txn.m_addr      = addr;
        txn.m_wdata     = new[1];
        txn.m_wdata[0]  = data;
        txn.m_lane_mode = lane;
        txn.m_is_read   = 0;
        txn.m_is_burst  = 0;
        send_txn(txn);
    endtask

    task send_ahb_rd32(bit [31:0] addr, bit [1:0] lane = 2'b00);
        aplc_spi_txn txn;
        txn = aplc_spi_txn::type_id::create("txn");
        txn.m_opcode    = 8'h21;
        txn.m_addr      = addr;
        txn.m_lane_mode = lane;
        txn.m_is_read   = 1;
        txn.m_is_burst  = 0;
        send_txn(txn);
    endtask

    task send_ahb_wr_burst(bit [31:0] addr, int burst_len, bit [1:0] lane = 2'b00);
        aplc_spi_txn txn;
        txn = aplc_spi_txn::type_id::create("txn");
        txn.m_opcode    = 8'h22;
        txn.m_addr      = addr;
        txn.m_burst_len = burst_len[4:0];
        txn.m_lane_mode = lane;
        txn.m_is_read   = 0;
        txn.m_is_burst  = 1;
        txn.m_wdata     = new[burst_len];
        foreach (txn.m_wdata[i]) txn.m_wdata[i] = $urandom;
        send_txn(txn);
    endtask

    task send_ahb_rd_burst(bit [31:0] addr, int burst_len, bit [1:0] lane = 2'b00);
        aplc_spi_txn txn;
        txn = aplc_spi_txn::type_id::create("txn");
        txn.m_opcode    = 8'h23;
        txn.m_addr      = addr;
        txn.m_burst_len = burst_len[4:0];
        txn.m_lane_mode = lane;
        txn.m_is_read   = 1;
        txn.m_is_burst  = 1;
        send_txn(txn);
    endtask
endclass

`endif
