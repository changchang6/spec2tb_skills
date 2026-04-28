package aplc_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import aplc_env_pkg::*;
    import aplc_seq_pkg::*;

    class aplc_base_test extends uvm_test;
        `uvm_component_utils(aplc_base_test)

        aplc_env       m_env;
        aplc_env_config m_env_cfg;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            m_env_cfg = aplc_env_config::type_id::create("m_env_cfg");

            // Set simulation timeout to prevent infinite hang
            uvm_root::get().set_timeout(100us, 0);

            if (!uvm_config_db #(virtual aplc_spi_if)::get(this, "", "spi_vif", m_env_cfg.m_spi_cfg.m_vif))
                `uvm_fatal("BUILD_ERR", "Unable to get spi_vif from config_db")
            if (!uvm_config_db #(virtual aplc_ahb_if)::get(this, "", "ahb_vif", m_env_cfg.m_ahb_cfg.m_vif))
                `uvm_fatal("BUILD_ERR", "Unable to get ahb_vif from config_db")
            if (!uvm_config_db #(virtual aplc_csr_if)::get(this, "", "csr_vif", m_env_cfg.m_csr_cfg.m_vif))
                `uvm_fatal("BUILD_ERR", "Unable to get csr_vif from config_db")

            uvm_config_db #(aplc_env_config)::set(this, "m_env", "aplc_env_config", m_env_cfg);
            m_env = aplc_env::type_id::create("m_env", this);
        endfunction

        virtual task run_phase(uvm_phase phase);
        endtask
    endclass

    class aplc_wr_csr_test extends aplc_base_test;
        `uvm_component_utils(aplc_wr_csr_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            aplc_wr_csr_seq seq;
            seq = aplc_wr_csr_seq::type_id::create("seq");
            seq.reg_addr  = 8'h04;
            seq.wdata     = 32'hDEADBEEF;
            seq.lane_mode = 2'b00;
            seq.starting_phase = phase;
            seq.start(m_env.m_spi_agent.m_sequencer);
        endtask
    endclass

    class aplc_rd_csr_test extends aplc_base_test;
        `uvm_component_utils(aplc_rd_csr_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            aplc_rd_csr_seq seq;
            seq = aplc_rd_csr_seq::type_id::create("seq");
            seq.reg_addr  = 8'h00;
            seq.lane_mode = 2'b00;
            seq.starting_phase = phase;
            seq.start(m_env.m_spi_agent.m_sequencer);
        endtask
    endclass

    class aplc_ahb_wr32_test extends aplc_base_test;
        `uvm_component_utils(aplc_ahb_wr32_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            aplc_ahb_wr32_seq seq;
            seq = aplc_ahb_wr32_seq::type_id::create("seq");
            seq.addr      = 32'h1000_0000;
            seq.wdata     = 32'hCAFE0001;
            seq.lane_mode = 2'b00;
            seq.starting_phase = phase;
            seq.start(m_env.m_spi_agent.m_sequencer);
        endtask
    endclass

    class aplc_ahb_rd32_test extends aplc_base_test;
        `uvm_component_utils(aplc_ahb_rd32_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            aplc_ahb_rd32_seq seq;
            seq = aplc_ahb_rd32_seq::type_id::create("seq");
            seq.addr      = 32'h1000_0000;
            seq.lane_mode = 2'b00;
            seq.starting_phase = phase;
            seq.start(m_env.m_spi_agent.m_sequencer);
        endtask
    endclass

    class aplc_ahb_wr_burst_test extends aplc_base_test;
        `uvm_component_utils(aplc_ahb_wr_burst_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            aplc_ahb_wr_burst_seq seq;
            seq = aplc_ahb_wr_burst_seq::type_id::create("seq");
            seq.addr      = 32'h2000_0000;
            seq.burst_len = 5'd4;
            seq.lane_mode = 2'b00;
            seq.starting_phase = phase;
            seq.start(m_env.m_spi_agent.m_sequencer);
        endtask
    endclass

    class aplc_ahb_rd_burst_test extends aplc_base_test;
        `uvm_component_utils(aplc_ahb_rd_burst_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            aplc_ahb_rd_burst_seq seq;
            seq = aplc_ahb_rd_burst_seq::type_id::create("seq");
            seq.addr      = 32'h2000_0000;
            seq.burst_len = 5'd4;
            seq.lane_mode = 2'b00;
            seq.starting_phase = phase;
            seq.start(m_env.m_spi_agent.m_sequencer);
        endtask
    endclass

endpackage
