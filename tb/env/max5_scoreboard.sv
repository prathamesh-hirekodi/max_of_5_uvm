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
