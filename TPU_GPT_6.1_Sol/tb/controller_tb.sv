`timescale 1ns/1ps
module controller_case #(
    parameter integer N=4,
    parameter [31:0] SEED=32'h43545201
) (output reg finished=0,output integer tests=0,errors=0);
    localparam integer EDGES=3*N-2, SW=(EDGES>1)?$clog2(EDGES):1;
    reg clk=0,rst_n=0,start=0;
    wire accept,clear,compute,capture,busy,done;
    wire [SW-1:0] step;
    // Reference is an elapsed-edge schedule, independent of the DUT state.
    integer elapsed=-1,compute_edges=0,transactions=0,i,s,cycle_id=0;
    reg expected_done=0,initialized=0;
    reg [31:0] rng=SEED;
    controller #(.ARRAY_SIZE(N)) dut(.*);
    always #5 clk=~clk;
    function automatic [31:0] random_word;
        begin
            rng=rng^(rng<<13); rng=rng^(rng>>17); rng=rng^(rng<<5);
            random_word=rng;
        end
    endfunction
    task automatic check_bit(input string label,input logic got,want);
        begin
            tests=tests+1;
            if(got !== want) begin
                errors=errors+1;
                $display("FAIL CONTROLLER N=%0d seed=%h cycle=%0d elapsed=%0d %s expected=%b got=%b",N,SEED,cycle_id,elapsed,label,want,got);
            end
        end
    endtask
    task automatic check_outputs;
        reg [SW-1:0] expected_step;
        begin
            check_bit("accept",accept,elapsed<0 && start);
            check_bit("clear",clear,elapsed==0);
            check_bit("compute",compute,elapsed>=1 && elapsed<=EDGES);
            check_bit("capture",capture,elapsed==EDGES+1);
            check_bit("busy",busy,elapsed>=0);
            check_bit("done",done,expected_done);
            check_bit("exclusive phases",(clear & compute)|(clear & capture)|(compute & capture),0);
            if(elapsed>=1 && elapsed<=EDGES) begin
                expected_step=elapsed-1; tests=tests+1;
                if(step !== expected_step) begin
                    errors=errors+1;
                    $display("FAIL CONTROLLER N=%0d cycle=%0d step expected=%0d got=%0d",N,cycle_id,expected_step,step);
                end
            end
        end
    endtask
    task automatic cycle(input bit reset_n,request);
        begin
            @(negedge clk); rst_n=reset_n; start=request; #1;
            if(initialized) check_outputs();
            @(posedge clk);
            cycle_id=cycle_id+1; expected_done=0;
            if(!reset_n) begin elapsed=-1; compute_edges=0; end
            else if(elapsed<0) begin
                if(request) begin elapsed=0; compute_edges=0; end
            end else begin
                if(elapsed>=1 && elapsed<=EDGES) compute_edges=compute_edges+1;
                if(elapsed==EDGES+1) begin
                    elapsed=-1; expected_done=1; transactions=transactions+1;
                    tests=tests+1;
                    if(compute_edges !== EDGES) begin
                        errors=errors+1;
                        $display("FAIL CONTROLLER N=%0d compute-edge count expected=%0d got=%0d",N,EDGES,compute_edges);
                    end
                end else elapsed=elapsed+1;
            end
            #1; initialized=1; check_outputs();
        end
    endtask
    initial begin
        cycle(0,1); cycle(1,0);
        // Busy requests on every phase must not alter the transaction schedule.
        cycle(1,1);
        for(s=0;s<EDGES+2;s=s+1) cycle(1,1);
        // Accept on the first idle edge, with the preceding done pulse still high.
        cycle(1,1);
        for(s=0;s<EDGES+2;s=s+1) cycle(1,0);
        cycle(1,0); cycle(1,0);
        // Reset aborts independently in CLEAR, RUN, and CAPTURE.
        cycle(1,1); cycle(0,1); cycle(1,0);
        cycle(1,1); cycle(1,0); cycle(0,1); cycle(1,0);
        cycle(1,1);
        for(s=0;s<EDGES+1;s=s+1) cycle(1,0);
        cycle(0,1); cycle(1,0);
        // Sustained start exercises automatic back-to-back transactions.
        repeat(3*(EDGES+3)) cycle(1,1);
        while(elapsed>=0) cycle(1,0);
        cycle(1,0);
        for(i=0;i<500;i=i+1) begin
            rng=random_word(); cycle(i%113!=0,rng[9:8]!=0);
        end
        while(elapsed>=0) cycle(1,0);
        repeat(3) cycle(1,0);
        $display("CONTROLLER coverage N=%0d compute_edges_per_transaction=%0d seed=%h completions=%0d checks=%0d",N,EDGES,SEED,transactions,tests);
        finished=1;
    end
endmodule

module controller_tb;
    wire [2:0] finished;
    wire integer t0,t1,t2,e0,e1,e2;
    integer tests,errors;
    controller_case c0(finished[0],t0,e0);
    controller_case #(.N(1),.SEED(32'h43545202)) c1(finished[1],t1,e1);
    controller_case #(.N(2),.SEED(32'h43545203)) c2(finished[2],t2,e2);
    task automatic report(input bit timeout_hit);
        begin
            tests=t0+t1+t2; errors=e0+e1+e2+timeout_hit;
            if(timeout_hit) $display("FAIL CONTROLLER watchdog expired");
            if(errors==0 && tests>0) $display("CONTROLLER TEST RESULT: PASS");
            else $display("CONTROLLER TEST RESULT: FAIL");
            $display("Tests: %0d\nErrors: %0d",tests,errors); $finish;
        end
    endtask
    initial begin wait(&finished); report(0); end
    initial begin repeat(3000) @(posedge c0.clk); report(1); end
endmodule
