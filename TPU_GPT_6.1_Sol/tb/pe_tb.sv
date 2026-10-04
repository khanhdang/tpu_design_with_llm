`timescale 1ns/1ps
module pe_case #(
    parameter integer DW=8, AW=32,
    parameter [31:0] SEED=32'h50450001
) (output reg finished=0, output integer tests=0, errors=0);
    reg clk=0,rst_n=0,clr=0,en=0;
    reg signed [DW-1:0] a_in=0,b_in=0;
    wire signed [DW-1:0] a_out,b_out;
    wire signed [AW-1:0] acc;
    reg signed [DW-1:0] ref_a=0,ref_b=0;
    reg signed [AW-1:0] ref_acc=0;
    longint signed product;
    reg [31:0] rng=SEED;
    integer i,x,y,flags;
    localparam integer MINVAL=-(1 << (DW-1)), MAXVAL=(1 << (DW-1))-1;
    pe #(.DATA_WIDTH(DW),.ACC_WIDTH(AW)) dut(.*);
    always #5 clk=~clk;
    function automatic [31:0] random_word;
        begin rng=1664525*rng+1013904223; random_word=rng; end
    endfunction
    task automatic cycle(input bit reset_n,clear,enable,input integer av,bv);
        begin
            @(negedge clk);
            rst_n=reset_n; clr=clear; en=enable; a_in=av; b_in=bv;
            product=$signed(a_in); product=product*$signed(b_in);
            if(!reset_n || clear) begin ref_a=0; ref_b=0; ref_acc=0; end
            else if(enable) begin
                ref_a=a_in; ref_b=b_in; ref_acc=$signed(ref_acc)+product;
            end
            @(posedge clk); #1;
            tests=tests+3;
            if(a_out !== ref_a) begin
                errors=errors+1;
                $display("FAIL PE A DW=%0d AW=%0d seed=%h check=%0d expected=%0d got=%0d",DW,AW,SEED,tests,ref_a,a_out);
            end
            if(b_out !== ref_b) begin
                errors=errors+1;
                $display("FAIL PE B DW=%0d AW=%0d seed=%h check=%0d expected=%0d got=%0d",DW,AW,SEED,tests,ref_b,b_out);
            end
            if(acc !== ref_acc) begin
                errors=errors+1;
                $display("FAIL PE ACC DW=%0d AW=%0d seed=%h check=%0d rst=%b clr=%b en=%b a=%0d b=%0d expected=%0d got=%0d",
                    DW,AW,SEED,tests,rst_n,clr,en,a_in,b_in,ref_acc,acc);
            end
        end
    endtask
    initial begin
        cycle(0,1,1,3,-4);
        cycle(1,0,1,3,-4);
        cycle(1,0,1,-2,5);
        cycle(1,0,1,7,-1);
        cycle(1,0,0,MINVAL,MAXVAL);
        cycle(1,1,0,MINVAL,MAXVAL);
        cycle(1,0,1,MINVAL,MAXVAL);
        cycle(1,1,1,MAXVAL,MAXVAL);
        repeat(5) cycle(1,0,1,MINVAL,MINVAL);
        cycle(0,0,1,MINVAL,MAXVAL);
        cycle(1,0,0,4,-7);
        for(i=0;i<500;i=i+1) begin
            x=random_word(); y=random_word(); flags=random_word();
            cycle((i%101)!=0,(flags & 15)==0,(flags & 3)!=0,x,y);
        end
        $display("PE coverage DW=%0d AW=%0d seed=%h checks=%0d",DW,AW,SEED,tests);
        finished=1;
    end
endmodule

module pe_tb;
    wire [2:0] finished;
    wire integer t0,t1,t2,e0,e1,e2;
    integer tests,errors;
    pe_case c0(finished[0],t0,e0);
    pe_case #(.AW(16),.SEED(32'h50450002)) c1(finished[1],t1,e1);
    pe_case #(.DW(5),.AW(16),.SEED(32'h50450003)) c2(finished[2],t2,e2);
    task automatic report(input bit timeout_hit);
        begin
            tests=t0+t1+t2; errors=e0+e1+e2+timeout_hit;
            if(timeout_hit) $display("FAIL PE watchdog expired");
            if(errors==0 && tests>0) $display("PE TEST RESULT: PASS");
            else $display("PE TEST RESULT: FAIL");
            $display("Tests: %0d\nErrors: %0d",tests,errors); $finish;
        end
    endtask
    initial begin wait(&finished); report(0); end
    initial begin repeat(2000) @(posedge c0.clk); report(1); end
endmodule
