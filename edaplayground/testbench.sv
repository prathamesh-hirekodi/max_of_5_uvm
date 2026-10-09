// EDA Playground testbench for max_of_5 (generated from tb/)
// Settings: UVM/OVM = UVM 1.2, Simulator = Aldec Riviera-PRO or Siemens Questa
`timescale 1ns/1ps
`include "uvm_macros.svh"

// ===== top/max5_if.sv =====
// Interface between the UVM testbench and the max_of_5 DUT
interface max5_if #(parameter W = 8) (input logic clk);
    logic         rst_n;
    logic         in_valid;
    logic [W-1:0] streaming_in;
    logic         out_valid;
    logic [W-1:0] data_out;
    logic [W-1:0] max_of_5;
endinterface

// ===== max5_pkg.sv =====
// Package: pulls in every UVM component in dependency order
package max5_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    localparam int W    = 8;            // data width
    localparam int MAXV = (1 << W) - 1;
    localparam int WIN  = 5;            // window size

    typedef enum {DATA, IDLE, RESET} kind_e;

    // agent
// ===== agent/max5_item.sv =====
    // Transaction: one cycle of stimulus (DATA / IDLE / RESET).
    // The monitor and predictor also use it to carry DUT outputs.
    class max5_item extends uvm_sequence_item;
        rand kind_e      kind;
        rand bit [W-1:0] data;

        // filled in by the monitor / predictor
        int              cycle;
        bit [W-1:0]      data_out;
        bit [W-1:0]      max_out;

        `uvm_object_utils_begin(max5_item)
            `uvm_field_enum(kind_e, kind, UVM_ALL_ON)
            `uvm_field_int(data, UVM_ALL_ON)
            `uvm_field_int(data_out, UVM_ALL_ON | UVM_NOCOMPARE)
            `uvm_field_int(max_out, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_object_utils_end

        function new(string name = "max5_item");
            super.new(name);
        endfunction
    endclass
// ===== agent/max5_sequencer.sv =====
    // Sequencer: nothing to customize, so a typedef is enough
    typedef uvm_sequencer #(max5_item) max5_sequencer;
// ===== agent/max5_driver.sv =====
    // Driver: drives on the falling edge so inputs are stable at the rising edge.
    // A RESET item holds rst_n low for 2 cycles.
    class max5_driver extends uvm_driver #(max5_item);
        `uvm_component_utils(max5_driver)

        virtual max5_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual max5_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "virtual interface not set")
        endfunction

        task run_phase(uvm_phase phase);
            vif.rst_n        <= 0;
            vif.in_valid     <= 0;
            vif.streaming_in <= 0;
            forever begin
                seq_item_port.get_next_item(req);
                drive_item(req);
                seq_item_port.item_done();
            end
        endtask

        task drive_item(max5_item it);
            @(negedge vif.clk);
            if (it.kind == RESET) begin
                vif.in_valid <= 0;
                vif.rst_n    <= 0;
                repeat (2) @(negedge vif.clk);
                vif.rst_n    <= 1;
            end else begin
                vif.rst_n        <= 1;
                vif.in_valid     <= (it.kind == DATA);
                vif.streaming_in <= it.data;
            end
        endtask
    endclass
// ===== agent/max5_monitor.sv =====
    // Monitor: samples just after each rising edge. At that point the inputs
    // are the ones accepted on this edge and the outputs are the DUT's result
    // for them (1-cycle latency).
    //   in_ap  : accepted inputs and reset events  -> predictor
    //   out_ap : DUT outputs                       -> scoreboard
    class max5_monitor extends uvm_monitor;
        `uvm_component_utils(max5_monitor)

        virtual max5_if vif;
        uvm_analysis_port #(max5_item) in_ap;
        uvm_analysis_port #(max5_item) out_ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            in_ap  = new("in_ap",  this);
            out_ap = new("out_ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual max5_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "virtual interface not set")
        endfunction

        task run_phase(uvm_phase phase);
            max5_item t;
            int cycle = 0;
            forever begin
                @(posedge vif.clk);
                #1;
                cycle++;
                if (vif.rst_n !== 1) begin
                    t = max5_item::type_id::create("rst");
                    t.kind  = RESET;
                    t.cycle = cycle;
                    in_ap.write(t);
                    continue;
                end
                // inputs first, so the predictor's expectation is ready
                if (vif.in_valid === 1) begin
                    t = max5_item::type_id::create("in");
                    t.kind  = DATA;
                    t.data  = vif.streaming_in;
                    t.cycle = cycle;
                    in_ap.write(t);
                end
                if (vif.out_valid === 1) begin
                    t = max5_item::type_id::create("out");
                    t.kind     = DATA;
                    t.cycle    = cycle;
                    t.data_out = vif.data_out;
                    t.max_out  = vif.max_of_5;
                    out_ap.write(t);
                end
            end
        endtask
    endclass
// ===== agent/max5_agent.sv =====
    // Active agent: sequencer + driver + monitor
    class max5_agent extends uvm_agent;
        `uvm_component_utils(max5_agent)

        max5_sequencer seqr;
        max5_driver    drv;
        max5_monitor   mon;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            seqr = max5_sequencer::type_id::create("seqr", this);
            drv  = max5_driver::type_id::create("drv", this);
            mon  = max5_monitor::type_id::create("mon", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            drv.seq_item_port.connect(seqr.seq_item_export);
        endfunction
    endclass

    // sequences
// ===== seq/max5_basic_seq.sv =====
    // Basic sequence: reset, then the spec table, then idle cycles to drain.
    //   in : 3 10  4  7  2 12 13  1
    //   max: 3 10 10 10 10 12 13 13
    class max5_basic_seq extends uvm_sequence #(max5_item);
        `uvm_object_utils(max5_basic_seq)

        int vals[$] = {3, 10, 4, 7, 2, 12, 13, 1};

        function new(string name = "max5_basic_seq");
            super.new(name);
        endfunction

        task body();
            send(RESET, 0);
            foreach (vals[i]) send(DATA, vals[i]);
            repeat (3) send(IDLE, 0);       // let the last output reach the scoreboard
        endtask

        task send(kind_e kind, bit [W-1:0] data);
            req = max5_item::type_id::create("req");
            start_item(req);
            req.kind = kind;
            req.data = data;
            finish_item(req);
        endtask
    endclass

    // env
// ===== env/max5_predictor.sv =====
    // Predictor: reference model. Keeps the last WIN accepted inputs and
    // publishes the expected output for every accepted input.
    class max5_predictor extends uvm_subscriber #(max5_item);
        `uvm_component_utils(max5_predictor)

        uvm_analysis_port #(max5_item) ap;
        bit [W-1:0] window[$];      // newest first

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void write(max5_item t);
            max5_item e;
            if (t.kind == RESET) begin
                window.delete();
                return;
            end
            window.push_front(t.data);
            if (window.size() > WIN) void'(window.pop_back());

            e = max5_item::type_id::create("exp");
            e.kind     = DATA;
            e.cycle    = t.cycle;
            e.data_out = t.data;
            e.max_out  = 0;
            foreach (window[i]) if (window[i] > e.max_out) e.max_out = window[i];
            ap.write(e);
        endfunction
    endclass
// ===== env/max5_scoreboard.sv =====
    // Scoreboard: compares the predictor's expected outputs with the DUT
    // outputs seen by the monitor, in order and on the same cycle.
    `uvm_analysis_imp_decl(_exp)
    `uvm_analysis_imp_decl(_act)

    class max5_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(max5_scoreboard)

        uvm_analysis_imp_exp #(max5_item, max5_scoreboard) exp_imp;
        uvm_analysis_imp_act #(max5_item, max5_scoreboard) act_imp;

        max5_item expq[$];
        int       n_pass, n_fail;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            exp_imp = new("exp_imp", this);
            act_imp = new("act_imp", this);
        endfunction

        function void write_exp(max5_item t);
            expq.push_back(t);
        endfunction

        function void write_act(max5_item act);
            max5_item e;
            if (expq.size() == 0) begin
                n_fail++;
                `uvm_error("SB", $sformatf("cyc %0d: unexpected output data_out=%0d max_of_5=%0d",
                                           act.cycle, act.data_out, act.max_out))
                return;
            end
            e = expq.pop_front();
            if (e.cycle != act.cycle) begin
                n_fail++;
                `uvm_error("SB", $sformatf("latency: input @cyc %0d, output @cyc %0d", e.cycle, act.cycle))
            end else if (act.data_out == e.data_out && act.max_out == e.max_out) begin
                n_pass++;
                `uvm_info("SB", $sformatf("cyc %4d: PASS  data_out=%3d  max_of_5=%3d",
                                          act.cycle, act.data_out, act.max_out), UVM_MEDIUM)
            end else begin
                n_fail++;
                `uvm_error("SB", $sformatf("cyc %0d: MISMATCH data_out=%0d (exp %0d) max_of_5=%0d (exp %0d)",
                                           act.cycle, act.data_out, e.data_out, act.max_out, e.max_out))
            end
        endfunction

        function void check_phase(uvm_phase phase);
            foreach (expq[i]) begin
                n_fail++;
                `uvm_error("SB", $sformatf("missing output for input %0d @cyc %0d",
                                           expq[i].data_out, expq[i].cycle))
            end
            if (n_pass == 0) begin
                n_fail++;
                `uvm_error("SB", "no outputs were checked")
            end
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info("SB", $sformatf("SCOREBOARD: %0d passed, %0d failed", n_pass, n_fail), UVM_NONE)
            if (n_fail == 0) `uvm_info("SB", "*** TEST PASSED ***", UVM_NONE)
            else             `uvm_error("SB", "*** TEST FAILED ***")
        endfunction
    endclass
// ===== env/max5_env.sv =====
    // Env: agent + predictor + scoreboard
    //
    //   agent.mon.in_ap  --> pred --> sb.exp_imp
    //   agent.mon.out_ap ----------> sb.act_imp
    class max5_env extends uvm_env;
        `uvm_component_utils(max5_env)

        max5_agent      agent;
        max5_predictor  pred;
        max5_scoreboard sb;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent = max5_agent::type_id::create("agent", this);
            pred  = max5_predictor::type_id::create("pred", this);
            sb    = max5_scoreboard::type_id::create("sb", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            agent.mon.in_ap.connect(pred.analysis_export);
            pred.ap.connect(sb.exp_imp);
            agent.mon.out_ap.connect(sb.act_imp);
        endfunction
    endclass

    // tests
// ===== tests/max5_basic_test.sv =====
    // Basic test: runs max5_basic_seq (reset, then the spec table).
    //   in : 3 10  4  7  2 12 13  1
    //   max: 3 10 10 10 10 12 13 13
    class max5_basic_test extends uvm_test;
        `uvm_component_utils(max5_basic_test)

        max5_env env;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = max5_env::type_id::create("env", this);
        endfunction

        function void end_of_elaboration_phase(uvm_phase phase);
            uvm_root::get().print_topology();
        endfunction

        task run_phase(uvm_phase phase);
            max5_basic_seq seq = max5_basic_seq::type_id::create("seq");
            phase.raise_objection(this);
            seq.start(env.agent.seqr);
            phase.drop_objection(this);
        endtask
    endclass
endpackage

// ===== top/tb_top.sv =====
module tb_top;
    import uvm_pkg::*;
    import max5_pkg::*;

    // 100 MHz clock
    logic clk = 0;
    always #5 clk = ~clk;

    max5_if #(.W(max5_pkg::W)) vif (clk);

    // rst_n is driven by the driver (RESET items)
    max_of_5 #(.W(max5_pkg::W)) dut (
        .clk          (clk),
        .rst_n        (vif.rst_n),
        .in_valid     (vif.in_valid),
        .streaming_in (vif.streaming_in),
        .out_valid    (vif.out_valid),
        .data_out     (vif.data_out),
        .max_of_5     (vif.max_of_5)
    );

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);
    end

    initial begin
        uvm_config_db#(virtual max5_if)::set(null, "uvm_test_top*", "vif", vif);
        run_test("max5_basic_test");
    end
endmodule
