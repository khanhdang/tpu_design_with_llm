`timescale 1ns/1ps
module array_case #(
    parameter integer N=4,DW=8,AW=32,
    parameter [31:0] SEED=32'h41525201
) (output reg finished=0,output integer tests=0,errors=0);
    localparam integer EDGES=3*N-2;
    localparam integer MINVAL=-(1 << (DW-1)),MAXVAL=(1 << (DW-1))-1;
    reg clk=0,rst_n=0,clr=0,en=0;
    reg [N*DW-1:0] a_left=0,b_top=0;
    wire [N*N*AW-1:0] c;
    reg signed [DW-1:0] a [0:N-1][0:N-1], b [0:N-1][0:N-1];
    reg signed [AW-1:0] expected [0:N-1][0:N-1];
    reg [31:0] rng=SEED;
    integer matrix_id=0,kind,t,i,j;
    systolic_array #(.ARRAY_SIZE(N),.DATA_WIDTH(DW),.ACC_WIDTH(AW)) dut(.*);
    always #5 clk=~clk;
    function automatic [31:0] random_word;
        begin
            rng=rng^(rng<<13); rng=rng^(rng>>17); rng=rng^(rng<<5);
            random_word=rng;
        end
    endfunction
    task automatic prepare(input integer mode);
        integer r,q;
        begin
            for(r=0;r<N;r=r+1) for(q=0;q<N;q=q+1) begin
                case(mode)
                    0: begin a[r][q]=0; b[r][q]=0; end
                    1: begin a[r][q]=(r==q); b[r][q]=random_word(); end
                    2: begin a[r][q]=random_word(); b[r][q]=(r==q); end
                    3: begin a[r][q]=1+(r+q)%MAXVAL; b[r][q]=1+(2*r+q)%MAXVAL; end
                    4: begin a[r][q]=-1-(r+q)%MAXVAL; b[r][q]=1+(2*r+q)%MAXVAL; end
                    5: begin a[r][q]=(r%2 ? -2 : 3); b[r][q]=(q%2 ? 4 : -1); end
                    6: begin a[r][q]=MINVAL; b[r][q]=MINVAL; end
                    7: begin a[r][q]=((r+q)%2 ? MINVAL : MAXVAL); b[r][q]=(q%2 ? MAXVAL : MINVAL); end
                    default: begin a[r][q]=random_word(); b[r][q]=random_word(); end
                endcase
            end
        end
    endtask
    // Independent partial matrix product: product k reaches (r,q) at k+r+q.
    task automatic reference(input integer last_step);
        integer r,q,k;
        longint signed sum,product;
        begin
            for(r=0;r<N;r=r+1) for(q=0;q<N;q=q+1) begin
                sum=0;
                for(k=0;k<N;k=k+1) if(k+r+q<=last_step) begin
                    product=$signed(a[r][k]); product=product*$signed(b[k][q]);
                    sum=sum+product;
                end
                expected[r][q]=sum;
            end
        end
    endtask
    task automatic check_results(input integer step_id);
        integer r,q;
        begin
            for(r=0;r<N;r=r+1) for(q=0;q<N;q=q+1) begin
                tests=tests+1;
                if(c[(r*N+q)*AW +: AW] !== expected[r][q]) begin
                    errors=errors+1;
                    $display("FAIL ARRAY N=%0d DW=%0d AW=%0d seed=%h matrix=%0d step=%0d C[%0d][%0d] expected=%0d got=%0d",
                        N,DW,AW,SEED,matrix_id,step_id,r,q,expected[r][q],$signed(c[(r*N+q)*AW +: AW]));
                end
            end
        end
    endtask
    task automatic clear_state(input bit reset_n,clear,enable);
        begin
            @(negedge clk);
            rst_n=reset_n; clr=clear; en=enable; a_left='1; b_top='1;
            @(posedge clk); #1;
            reference(-1); check_results(-1);
        end
    endtask
    task automatic compute_step(input integer step_id,input bit stall);
        integer lane;
        begin
            if(stall) begin
                @(negedge clk); en=0; a_left='1; b_top='1;
                @(posedge clk); #1; check_results(step_id-1);
            end
            @(negedge clk); rst_n=1; clr=0; en=1; a_left=0; b_top=0;
            for(lane=0;lane<N;lane=lane+1) begin
                if(step_id>=lane && step_id-lane<N) begin
                    a_left[lane*DW +: DW]=a[lane][step_id-lane];
                    b_top[lane*DW +: DW]=b[step_id-lane][lane];
                end
            end
            @(posedge clk); #1; reference(step_id); check_results(step_id);
        end
    endtask
    task automatic run_matrix(input bit stalls);
        integer s;
        begin
            clear_state(1,1,1);
            for(s=0;s<EDGES;s=s+1) compute_step(s,stalls && s%2==0);
            @(negedge clk); en=0; a_left='1; b_top='1;
            repeat(2) begin @(posedge clk); #1; check_results(EDGES-1); end
            matrix_id=matrix_id+1;
        end
    endtask
    initial begin
        prepare(0); clear_state(0,1,1);
        for(kind=0;kind<32;kind=kind+1) begin prepare(kind); run_matrix(kind%2==1); end
        // Abort nonzero data in flight, then advance zeros to expose stale hops.
        prepare(6); clear_state(1,1,0); compute_step(0,0);
        clear_state(1,1,1); prepare(0);
        for(t=0;t<EDGES;t=t+1) compute_step(t,0);
        prepare(7); run_matrix(1);
        clear_state(1,1,0); compute_step(0,0);
        clear_state(0,0,1); prepare(0);
        for(t=0;t<EDGES;t=t+1) compute_step(t,0);
        prepare(5); run_matrix(1);
        $display("ARRAY coverage N=%0d DW=%0d AW=%0d seed=%h matrices=%0d random_pairs=24 checks=%0d",N,DW,AW,SEED,matrix_id,tests);
        finished=1;
    end
endmodule

module systolic_array_tb;
    wire [3:0] finished;
    wire integer t0,t1,t2,t3,e0,e1,e2,e3;
    integer tests,errors;
    array_case c0(finished[0],t0,e0);
    array_case #(.N(1),.AW(16),.SEED(32'h41525202)) c1(finished[1],t1,e1);
    array_case #(.N(2),.DW(5),.AW(16),.SEED(32'h41525203)) c2(finished[2],t2,e2);
    array_case #(.AW(16),.SEED(32'h41525204)) c3(finished[3],t3,e3);
    task automatic report(input bit timeout_hit);
        begin
            tests=t0+t1+t2+t3; errors=e0+e1+e2+e3+timeout_hit;
            if(timeout_hit) $display("FAIL ARRAY watchdog expired");
            if(errors==0 && tests>0) $display("SYSTOLIC_ARRAY TEST RESULT: PASS");
            else $display("SYSTOLIC_ARRAY TEST RESULT: FAIL");
            $display("Tests: %0d\nErrors: %0d",tests,errors); $finish;
        end
    endtask
    initial begin wait(&finished); report(0); end
    initial begin repeat(5000) @(posedge c0.clk); report(1); end
endmodule
