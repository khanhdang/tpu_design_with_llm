`timescale 1ns/1ps
module mac_case #(
    parameter integer DW=8, AW=32,
    parameter [31:0] SEED=32'h4d414301
) (output reg finished=0, output integer tests=0, errors=0);
    reg clk=0, rst_n=0, clr=0, en=0;
    reg signed [DW-1:0] a=0, b=0;
    wire signed [AW-1:0] acc;
    reg signed [AW-1:0] expected=0;
    longint signed product;
    reg [31:0] rng=SEED;
    integer i, x, y, flags;
    localparam integer MINVAL=-(1 << (DW-1)), MAXVAL=(1 << (DW-1))-1;
    mac #(.DATA_WIDTH(DW), .ACC_WIDTH(AW)) dut(.*);
    always #5 clk=~clk;

    function automatic [31:0] random_word;
        begin rng=1664525*rng+1013904223; random_word=rng; end
    endfunction

    task automatic cycle(input bit reset_n, clear, enable, input integer av, bv);
        begin
            @(negedge clk);
            rst_n=reset_n; clr=clear; en=enable; a=av; b=bv;
            // Reference arithmetic uses signed wide values, then wraps on assignment.
            product=$signed(a); product=product*$signed(b);
            if (!reset_n || clear) expected=0;
            else if (enable) expected=$signed(expected)+product;
            @(posedge clk); #1;
            tests=tests+1;
            if (acc !== expected) begin
                errors=errors+1;
                $display("FAIL MAC DW=%0d AW=%0d seed=%h check=%0d rst_n=%b clr=%b en=%b a=%0d b=%0d expected=%0d got=%0d",
                    DW,AW,SEED,tests,rst_n,clr,en,a,b,expected,acc);
            end
        end
    endtask

    initial begin
        cycle(0,1,1,3,4);
        cycle(1,0,1,0,MAXVAL);
        cycle(1,0,1,3,4);
        cycle(1,1,0,0,0);
        cycle(1,0,1,-3,4);
        cycle(1,1,1,MAXVAL,MAXVAL);
        cycle(1,0,1,MINVAL,MAXVAL);
        cycle(1,1,0,0,0);
        repeat (5) cycle(1,0,1,MINVAL,MINVAL);
        cycle(1,0,0,MAXVAL,MINVAL);
        cycle(1,0,1,MAXVAL,-1);
        cycle(0,0,1,MAXVAL,MAXVAL);
        for(i=0;i<500;i=i+1) begin
            x=random_word(); y=random_word(); flags=random_word();
            cycle((i%97)!=0, (flags & 15)==0, (flags & 3)!=0, x,y);
        end
        $display("MAC coverage DW=%0d AW=%0d seed=%h checks=%0d",DW,AW,SEED,tests);
        finished=1;
    end
endmodule

module mac_tb;
    wire [2:0] finished;
    wire integer t0,t1,t2,e0,e1,e2;
    integer tests,errors;
    mac_case c0(finished[0],t0,e0);
    mac_case #(.AW(16),.SEED(32'h4d414302)) c1(finished[1],t1,e1);
    mac_case #(.DW(4),.AW(12),.SEED(32'h4d414303)) c2(finished[2],t2,e2);
    task automatic report(input bit timeout_hit);
        begin
            tests=t0+t1+t2; errors=e0+e1+e2+timeout_hit;
            if(timeout_hit) $display("FAIL MAC watchdog expired");
            if(errors==0 && tests>0) $display("MAC TEST RESULT: PASS");
            else $display("MAC TEST RESULT: FAIL");
            $display("Tests: %0d\nErrors: %0d",tests,errors);
            $finish;
        end
    endtask
    initial begin wait (&finished); report(0); end
    initial begin repeat(2000) @(posedge c0.clk); report(1); end
endmodule
