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
