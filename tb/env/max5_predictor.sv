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
