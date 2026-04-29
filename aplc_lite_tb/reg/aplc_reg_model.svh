// APLC Register Model
// Simple shadow register model (not uvm_reg) shared between CSR driver and scoreboard

class aplc_reg_model extends uvm_object;

    `uvm_object_utils(aplc_reg_model)

    logic [31:0] m_regs [logic [7:0]];

    function new(string name = "aplc_reg_model");
        super.new(name);
        init();
    endfunction

    function void init();
        m_regs[8'h00] = 32'h0001_0000; // VERSION (RO)
        m_regs[8'h04] = 32'h0000_0000; // CTRL (RW)
        m_regs[8'h08] = 32'h0000_0000; // STATUS (RO)
        m_regs[8'h0C] = 32'h0000_0000; // LAST_ERR (RO)
        m_regs[8'h10] = 32'h0000_0000; // BURST_CNT (WC)
    endfunction

    function void write(logic [7:0] addr, logic [31:0] data);
        case (addr)
            8'h04: m_regs[addr] = data;  // CTRL: RW
            8'h10: m_regs[addr] = '0;    // BURST_CNT: WC (write clears)
            // RO registers: ignore write
        endcase
    endfunction

    function logic [31:0] read(logic [7:0] addr);
        if (m_regs.exists(addr))
            return m_regs[addr];
        else
            return '0;
    endfunction

endclass
