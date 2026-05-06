class spi_driver extends uvm_driver #(spi_xtn);

    `uvm_component_utils(spi_driver)

    virtual spi_if m_vif;
    spi_config     m_cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(spi_config)::get(this, "", "cfg", m_cfg))
            `uvm_fatal(get_type_name(), "Cannot get spi_config")
        m_vif = m_cfg.m_vif;
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            spi_xtn req;
            seq_item_port.try_next_item(req);
            if (req == null) begin
                @(m_vif.drv_cb);
                continue;
            end
            drive_frame(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_frame(spi_xtn req);
        bit frame_q[$];
        int bpc;
        int idx;

        // Build frame bit queue (MSB-first)
        pack_frame(req, frame_q);

        // Drive control signals
        m_vif.drv_cb.en        <= req.en;
        m_vif.drv_cb.test_mode <= req.test_mode;
        m_vif.drv_cb.lane_mode <= req.lane_mode;
        m_vif.drv_cb.pcs_n    <= 1'b0;

        bpc = req.get_bpc();

        // Wait one cycle after pcs_n assertion
        @(m_vif.drv_cb);

        // Drive frame data
        idx = 0;
        while (idx < frame_q.size()) begin
            case (bpc)
                1: begin
                    m_vif.drv_cb.pdi <= {15'b0, frame_q[idx]};
                    idx++;
                end
                4: begin
                    m_vif.drv_cb.pdi <= {12'b0, frame_q[idx+3], frame_q[idx+2],
                                         frame_q[idx+1], frame_q[idx]};
                    idx += 4;
                end
                8: begin
                    m_vif.drv_cb.pdi <= {8'b0, frame_q[idx+7], frame_q[idx+6],
                                         frame_q[idx+5], frame_q[idx+4],
                                         frame_q[idx+3], frame_q[idx+2],
                                         frame_q[idx+1], frame_q[idx]};
                    idx += 8;
                end
                16: begin
                    m_vif.drv_cb.pdi <= {frame_q[idx+15], frame_q[idx+14],
                                         frame_q[idx+13], frame_q[idx+12],
                                         frame_q[idx+11], frame_q[idx+10],
                                         frame_q[idx+9],  frame_q[idx+8],
                                         frame_q[idx+7],  frame_q[idx+6],
                                         frame_q[idx+5],  frame_q[idx+4],
                                         frame_q[idx+3],  frame_q[idx+2],
                                         frame_q[idx+1],  frame_q[idx]};
                    idx += 16;
                end
            endcase
            @(m_vif.drv_cb);
        end

        // Release pcs_n
        m_vif.drv_cb.pcs_n <= 1'b1;
        m_vif.drv_cb.pdi   <= '0;
    endtask

    task pack_frame(spi_xtn req, ref bit q[$]);
        // Opcode (8 bits, MSB-first)
        for (int i = 7; i >= 0; i--) q.push_back(req.opcode[i]);

        case (req.opcode)
            8'h10: begin // WR_CSR
                for (int i = 7; i >= 0; i--) q.push_back(req.reg_addr[i]);
                for (int i = 31; i >= 0; i--) q.push_back(req.wdata[0][i]);
            end
            8'h11: begin // RD_CSR
                for (int i = 7; i >= 0; i--) q.push_back(req.reg_addr[i]);
            end
            8'h20: begin // AHB_WR32
                for (int i = 31; i >= 0; i--) q.push_back(req.addr[i]);
                for (int i = 31; i >= 0; i--) q.push_back(req.wdata[0][i]);
            end
            8'h21: begin // AHB_RD32
                for (int i = 31; i >= 0; i--) q.push_back(req.addr[i]);
            end
            8'h22: begin // AHB_WR_BURST
                for (int i = 4; i >= 0; i--) q.push_back(req.burst_len[i]);
                repeat (3) q.push_back(1'b0); // rsvd
                for (int i = 31; i >= 0; i--) q.push_back(req.addr[i]);
                foreach (req.wdata[j])
                    for (int i = 31; i >= 0; i--) q.push_back(req.wdata[j][i]);
            end
            8'h23: begin // AHB_RD_BURST
                for (int i = 4; i >= 0; i--) q.push_back(req.burst_len[i]);
                repeat (3) q.push_back(1'b0); // rsvd
                for (int i = 31; i >= 0; i--) q.push_back(req.addr[i]);
            end
            default: begin
                // Unknown opcode - just send the opcode byte
            end
        endcase
    endtask

endclass
