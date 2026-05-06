// APLC-Lite Register Model
// Models the external CSR File registers accessible via WR_CSR/RD_CSR commands

class aplc_version_reg extends uvm_reg;
    `uvm_object_utils(aplc_version_reg)

    uvm_reg_field version;

    function new(string name = "aplc_version_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        version = uvm_reg_field::type_id::create("version");
        version.configure(this, 32, 0, "RO", 0, 32'h0000_0220, 1, 0, 1);
    endfunction
endclass

class aplc_ctrl_reg extends uvm_reg;
    `uvm_object_utils(aplc_ctrl_reg)

    uvm_reg_field en;
    uvm_reg_field lane_mode;
    uvm_reg_field test_mode;
    uvm_reg_field rsvd;

    function new(string name = "aplc_ctrl_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        en        = uvm_reg_field::type_id::create("en");
        lane_mode = uvm_reg_field::type_id::create("lane_mode");
        test_mode = uvm_reg_field::type_id::create("test_mode");
        rsvd      = uvm_reg_field::type_id::create("rsvd");

        en.configure(this,        1, 0,  "RW", 0, 1'b0, 1, 0, 1);
        lane_mode.configure(this, 2, 4,  "RW", 0, 2'b0, 1, 0, 1);
        test_mode.configure(this, 1, 8,  "RW", 0, 1'b0, 1, 0, 1);
        rsvd.configure(this,     28, 9,  "RW", 0, 28'b0, 1, 0, 1);
    endfunction
endclass

class aplc_status_reg extends uvm_reg;
    `uvm_object_utils(aplc_status_reg)

    uvm_reg_field busy;
    uvm_reg_field resp_valid;
    uvm_reg_field cmd_err;
    uvm_reg_field bus_err;
    uvm_reg_field frame_err;
    uvm_reg_field in_test_mode;
    uvm_reg_field out_en;
    uvm_reg_field burst_err;

    function new(string name = "aplc_status_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        busy         = uvm_reg_field::type_id::create("busy");
        resp_valid   = uvm_reg_field::type_id::create("resp_valid");
        cmd_err      = uvm_reg_field::type_id::create("cmd_err");
        bus_err      = uvm_reg_field::type_id::create("bus_err");
        frame_err    = uvm_reg_field::type_id::create("frame_err");
        in_test_mode = uvm_reg_field::type_id::create("in_test_mode");
        out_en       = uvm_reg_field::type_id::create("out_en");
        burst_err    = uvm_reg_field::type_id::create("burst_err");

        busy.configure(this,         1, 0, "RO", 0, 1'b0, 1, 0, 1);
        resp_valid.configure(this,   1, 1, "RO", 0, 1'b0, 1, 0, 1);
        cmd_err.configure(this,      1, 2, "RO", 0, 1'b0, 1, 0, 1);
        bus_err.configure(this,      1, 3, "RO", 0, 1'b0, 1, 0, 1);
        frame_err.configure(this,    1, 4, "RO", 0, 1'b0, 1, 0, 1);
        in_test_mode.configure(this, 1, 5, "RO", 0, 1'b0, 1, 0, 1);
        out_en.configure(this,       1, 6, "RO", 0, 1'b0, 1, 0, 1);
        burst_err.configure(this,    1, 7, "RO", 0, 1'b0, 1, 0, 1);
    endfunction
endclass

class aplc_last_err_reg extends uvm_reg;
    `uvm_object_utils(aplc_last_err_reg)

    uvm_reg_field err_code;

    function new(string name = "aplc_last_err_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        err_code = uvm_reg_field::type_id::create("err_code");
        err_code.configure(this, 8, 0, "RO", 0, 8'h00, 1, 0, 1);
    endfunction
endclass

class aplc_burst_cnt_reg extends uvm_reg;
    `uvm_object_utils(aplc_burst_cnt_reg)

    uvm_reg_field cnt;

    function new(string name = "aplc_burst_cnt_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        cnt = uvm_reg_field::type_id::create("cnt");
        cnt.configure(this, 32, 0, "WC", 0, 32'h0, 1, 0, 1);
    endfunction
endclass

class aplc_reg_block extends uvm_reg_block;
    `uvm_object_utils(aplc_reg_block)

    rand aplc_version_reg  VERSION;
    rand aplc_ctrl_reg     CTRL;
    rand aplc_status_reg   STATUS;
    rand aplc_last_err_reg LAST_ERR;
    rand aplc_burst_cnt_reg BURST_CNT;

    function new(string name = "aplc_reg_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        VERSION   = aplc_version_reg::type_id::create("VERSION");
        CTRL      = aplc_ctrl_reg::type_id::create("CTRL");
        STATUS    = aplc_status_reg::type_id::create("STATUS");
        LAST_ERR  = aplc_last_err_reg::type_id::create("LAST_ERR");
        BURST_CNT = aplc_burst_cnt_reg::type_id::create("BURST_CNT");

        VERSION.configure(this,  null, "");
        CTRL.configure(this,     null, "");
        STATUS.configure(this,   null, "");
        LAST_ERR.configure(this, null, "");
        BURST_CNT.configure(this, null, "");

        VERSION.build();
        CTRL.build();
        STATUS.build();
        LAST_ERR.build();
        BURST_CNT.build();

        // Map registers to addresses
        default_map = create_map("default_map", 0, 4, UVM_LITTLE_ENDIAN);
        default_map.add_reg(VERSION,   8'h00, "RO");
        default_map.add_reg(CTRL,      8'h04, "RW");
        default_map.add_reg(STATUS,    8'h08, "RO");
        default_map.add_reg(LAST_ERR,  8'h0C, "RO");
        default_map.add_reg(BURST_CNT, 8'h10, "RW");

        lock_model();
    endfunction
endclass
