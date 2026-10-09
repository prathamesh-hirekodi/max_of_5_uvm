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
