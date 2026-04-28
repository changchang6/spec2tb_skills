package aplc_seq_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import aplc_spi_pkg::*;

    class aplc_base_seq extends uvm_sequence #(aplc_spi_txn);
        `uvm_object_utils(aplc_base_seq)
        `uvm_declare_p_sequencer(aplc_spi_sequencer)

        function new(string name = "aplc_base_seq");
            super.new(name);
        endfunction

        virtual task pre_start();
            super.pre_start();
            if (starting_phase != null)
                starting_phase.raise_objection(this);
        endtask

        virtual task post_start();
            super.post_start();
            if (starting_phase != null)
                starting_phase.drop_objection(this);
        endtask
    endclass

    class aplc_wr_csr_seq extends aplc_base_seq;
        `uvm_object_utils(aplc_wr_csr_seq)

        rand bit [7:0]  reg_addr;
        rand bit [31:0] wdata;
        rand bit [1:0]  lane_mode;

        constraint c_addr { reg_addr < 64; }

        function new(string name = "aplc_wr_csr_seq");
            super.new(name);
        endfunction

        virtual task body();
            aplc_spi_txn txn;
            txn = aplc_spi_txn::type_id::create("txn");
            txn.opcode    = 8'h10;
            txn.reg_addr  = reg_addr;
            txn.wdata     = new[1];
            txn.wdata[0]  = wdata;
            txn.lane_mode = lane_mode;
            txn.is_read   = 0;
            txn.is_burst  = 0;
            txn.has_rdata = 0;
            txn.burst_len = 1;
            start_item(txn);
            finish_item(txn);
        endtask
    endclass

    class aplc_rd_csr_seq extends aplc_base_seq;
        `uvm_object_utils(aplc_rd_csr_seq)

        rand bit [7:0]  reg_addr;
        rand bit [1:0]  lane_mode;

        constraint c_addr { reg_addr < 64; }

        function new(string name = "aplc_rd_csr_seq");
            super.new(name);
        endfunction

        virtual task body();
            aplc_spi_txn txn;
            txn = aplc_spi_txn::type_id::create("txn");
            txn.opcode    = 8'h11;
            txn.reg_addr  = reg_addr;
            txn.lane_mode = lane_mode;
            txn.is_read   = 1;
            txn.is_burst  = 0;
            txn.has_rdata = 1;
            txn.burst_len = 1;
            txn.wdata     = new[0];
            start_item(txn);
            finish_item(txn);
        endtask
    endclass

    class aplc_ahb_wr32_seq extends aplc_base_seq;
        `uvm_object_utils(aplc_ahb_wr32_seq)

        rand bit [31:0] addr;
        rand bit [31:0] wdata;
        rand bit [1:0]  lane_mode;

        constraint c_align { addr[1:0] == 2'b00; }

        function new(string name = "aplc_ahb_wr32_seq");
            super.new(name);
        endfunction

        virtual task body();
            aplc_spi_txn txn;
            txn = aplc_spi_txn::type_id::create("txn");
            txn.opcode    = 8'h20;
            txn.addr      = addr;
            txn.lane_mode = lane_mode;
            txn.wdata     = new[1];
            txn.wdata[0]  = wdata;
            txn.is_read   = 0;
            txn.is_burst  = 0;
            txn.has_rdata = 0;
            txn.burst_len = 1;
            start_item(txn);
            finish_item(txn);
        endtask
    endclass

    class aplc_ahb_rd32_seq extends aplc_base_seq;
        `uvm_object_utils(aplc_ahb_rd32_seq)

        rand bit [31:0] addr;
        rand bit [1:0]  lane_mode;

        constraint c_align { addr[1:0] == 2'b00; }

        function new(string name = "aplc_ahb_rd32_seq");
            super.new(name);
        endfunction

        virtual task body();
            aplc_spi_txn txn;
            txn = aplc_spi_txn::type_id::create("txn");
            txn.opcode    = 8'h21;
            txn.addr      = addr;
            txn.lane_mode = lane_mode;
            txn.is_read   = 1;
            txn.is_burst  = 0;
            txn.has_rdata = 1;
            txn.burst_len = 1;
            txn.wdata     = new[0];
            start_item(txn);
            finish_item(txn);
        endtask
    endclass

    class aplc_ahb_wr_burst_seq extends aplc_base_seq;
        `uvm_object_utils(aplc_ahb_wr_burst_seq)

        rand bit [31:0] addr;
        rand bit [4:0]  burst_len;
        rand bit [1:0]  lane_mode;

        constraint c_align { addr[1:0] == 2'b00; }
        constraint c_burst { burst_len inside {1, 4, 8, 16}; }

        function new(string name = "aplc_ahb_wr_burst_seq");
            super.new(name);
        endfunction

        virtual task body();
            aplc_spi_txn txn;
            txn = aplc_spi_txn::type_id::create("txn");
            txn.opcode    = 8'h22;
            txn.addr      = addr;
            txn.burst_len = burst_len;
            txn.lane_mode = lane_mode;
            txn.is_read   = 0;
            txn.is_burst  = 1;
            txn.has_rdata = 0;
            txn.wdata     = new[0];
            start_item(txn);
            finish_item(txn);
        endtask
    endclass

    class aplc_ahb_rd_burst_seq extends aplc_base_seq;
        `uvm_object_utils(aplc_ahb_rd_burst_seq)

        rand bit [31:0] addr;
        rand bit [4:0]  burst_len;
        rand bit [1:0]  lane_mode;

        constraint c_align { addr[1:0] == 2'b00; }
        constraint c_burst { burst_len inside {1, 4, 8, 16}; }

        function new(string name = "aplc_ahb_rd_burst_seq");
            super.new(name);
        endfunction

        virtual task body();
            aplc_spi_txn txn;
            txn = aplc_spi_txn::type_id::create("txn");
            txn.opcode    = 8'h23;
            txn.addr      = addr;
            txn.burst_len = burst_len;
            txn.lane_mode = lane_mode;
            txn.is_read   = 1;
            txn.is_burst  = 1;
            txn.has_rdata = 1;
            txn.wdata     = new[0];
            start_item(txn);
            finish_item(txn);
        endtask
    endclass

endpackage
