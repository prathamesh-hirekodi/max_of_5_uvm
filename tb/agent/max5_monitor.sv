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
