`timescale 1ns/1ps
module tpu_case #(
    parameter integer N=4,DW=8,AW=32,
    parameter [31:0] SEED=32'h54505501
) (output reg finished=0,output integer tests=0,errors=0);
    localparam integer EDGES=3*N-2;
    localparam integer MINVAL=-(1 << (DW-1)),MAXVAL=(1 << (DW-1))-1;
    reg clk=0,rst_n=0,start=0;
    reg [N*N*DW-1:0] a_matrix=0,b_matrix=0,stim_a=0,stim_b=0;
    wire [N*N*AW-1:0] c_matrix;
    wire busy,done;
    reg [N*N*AW-1:0] published=0,pending=0;
    reg expected_done=0,initialized=0;
    integer elapsed=-1,cycle_id=0,accepted=0,completed=0,kind,s,i;
    reg [31:0] rng=SEED;
    tpu_top #(.ARRAY_SIZE(N),.DATA_WIDTH(DW),.ACC_WIDTH(AW)) dut(.*);
    always #5 clk=~clk;
    function automatic [31:0] random_word;
        begin
            rng=rng^(rng<<13); rng=rng^(rng>>17); rng=rng^(rng<<5);
            random_word=rng;
        end
    endfunction
    task automatic prepare(input integer mode);
        integer r,q,av,bv;
        begin
            for(r=0;r<N;r=r+1) for(q=0;q<N;q=q+1) begin
                case(mode)
                    0: begin av=0; bv=0; end
                    1: begin av=(r==q); bv=random_word(); end
                    2: begin av=random_word(); bv=(r==q); end
                    3: begin av=1+(r+q)%MAXVAL; bv=1+(2*r+q)%MAXVAL; end
                    4: begin av=-1-(r+q)%MAXVAL; bv=1+(2*r+q)%MAXVAL; end
                    5: begin av=(r%2 ? -2 : 3); bv=(q%2 ? 4 : -1); end
                    6: begin av=MINVAL; bv=MINVAL; end
                    7: begin av=((r+q)%2 ? MINVAL : MAXVAL); bv=(q%2 ? MAXVAL : MINVAL); end
                    default: begin av=random_word(); bv=random_word(); end
                endcase
                stim_a[(r*N+q)*DW +: DW]=av;
                stim_b[(r*N+q)*DW +: DW]=bv;
            end
        end
    endtask
    // Snapshot the TB's accepted inputs and compute a software matrix product.
    // No reference value or timing decision reads any DUT output.
    task automatic calculate_pending;
        integer r,q,k;
        longint signed av,bv,sum;
        begin
            for(r=0;r<N;r=r+1) for(q=0;q<N;q=q+1) begin
                sum=0;
                for(k=0;k<N;k=k+1) begin
                    av=$signed(a_matrix[(r*N+k)*DW +: DW]);
                    bv=$signed(b_matrix[(k*N+q)*DW +: DW]);
                    sum=sum+av*bv;
                end
                pending[(r*N+q)*AW +: AW]=sum;
            end
        end
    endtask
    task automatic check_outputs;
        integer r,q;
        reg expected_busy;
        begin
            expected_busy=(elapsed>=0); tests=tests+2;
            if(busy !== expected_busy) begin
                errors=errors+1;
                $display("FAIL TPU N=%0d seed=%h cycle=%0d elapsed=%0d busy expected=%b got=%b",N,SEED,cycle_id,elapsed,expected_busy,busy);
            end
            if(done !== expected_done) begin
                errors=errors+1;
                $display("FAIL TPU N=%0d seed=%h cycle=%0d elapsed=%0d done expected=%b got=%b",N,SEED,cycle_id,elapsed,expected_done,done);
            end
            for(r=0;r<N;r=r+1) for(q=0;q<N;q=q+1) begin
                tests=tests+1;
                if(c_matrix[(r*N+q)*AW +: AW] !== published[(r*N+q)*AW +: AW]) begin
                    errors=errors+1;
                    $display("FAIL TPU N=%0d DW=%0d AW=%0d seed=%h transaction=%0d cycle=%0d elapsed=%0d C[%0d][%0d] expected=%0d got=%0d",
                        N,DW,AW,SEED,accepted,cycle_id,elapsed,r,q,
                        $signed(published[(r*N+q)*AW +: AW]),$signed(c_matrix[(r*N+q)*AW +: AW]));
                end
            end
        end
    endtask
    task automatic cycle(input bit reset_n,request,scramble);
        integer element;
        begin
            @(negedge clk); rst_n=reset_n; start=request;
            a_matrix=stim_a; b_matrix=stim_b;
            if(scramble) for(element=0;element<N*N;element=element+1) begin
                a_matrix[element*DW +: DW]=random_word();
                b_matrix[element*DW +: DW]=random_word();
            end
            #1; if(initialized) check_outputs();
            @(posedge clk); cycle_id=cycle_id+1; expected_done=0;
            if(!reset_n) begin elapsed=-1; published=0; pending=0; end
            else if(elapsed<0) begin
                if(request) begin
                    calculate_pending(); elapsed=0; accepted=accepted+1;
                end
            end else if(elapsed==EDGES+1) begin
                published=pending; elapsed=-1; expected_done=1; completed=completed+1;
            end else elapsed=elapsed+1;
            #1; initialized=1; check_outputs();
        end
    endtask
    task automatic transaction(input integer mode,input bit busy_requests);
        integer edge_id;
        begin
            prepare(mode); cycle(1,1,0);
            // Change every external element after accept. Assert start on all
            // busy phases; neither input changes nor requests may disturb C.
            for(edge_id=0;edge_id<EDGES+2;edge_id=edge_id+1) cycle(1,busy_requests,1);
        end
    endtask
    initial begin
        cycle(0,1,1); repeat(2) cycle(1,0,1);
        // Immediate consecutive products: eight directed and sixty random pairs.
        for(kind=0;kind<68;kind=kind+1) transaction(kind,kind%2==1);
        repeat(4) cycle(1,0,1);
        // Abort CLEAR, then watch long enough to catch a spurious completion.
        prepare(6); cycle(1,1,0); cycle(0,1,1);
        repeat(EDGES+4) cycle(1,0,1); transaction(3,1);
        // Abort RUN, including a partially accumulated product when N>1.
        prepare(7); cycle(1,1,0); cycle(1,1,1);
        repeat(EDGES/2) cycle(1,1,1);
        cycle(0,1,1); repeat(EDGES+4) cycle(1,0,1); transaction(5,1);
        // Reset on the capture edge must suppress both publication and done.
        prepare(6); cycle(1,1,0);
        repeat(EDGES+1) cycle(1,1,1);
        cycle(0,1,1); repeat(EDGES+4) cycle(1,0,1); transaction(1,1);
        // Reproducible arbitrary requests, changing inputs, and occasional resets.
        for(i=0;i<250;i=i+1) begin
            rng=random_word(); cycle(i%71!=0,rng[17],1);
        end
        while(elapsed>=0) cycle(1,0,1);
        repeat(4) cycle(1,0,1);
        $display("TPU coverage N=%0d DW=%0d AW=%0d seed=%h directed_pairs=8 random_pairs=60 accepted=%0d completed=%0d checks=%0d",
            N,DW,AW,SEED,accepted,completed,tests);
        finished=1;
    end
endmodule

module tpu_top_tb;
    wire [3:0] finished;
    wire integer t0,t1,t2,t3,e0,e1,e2,e3;
    integer tests,errors;
    tpu_case c0(finished[0],t0,e0);
    tpu_case #(.N(1),.AW(16),.SEED(32'h54505502)) c1(finished[1],t1,e1);
    tpu_case #(.N(2),.DW(5),.AW(16),.SEED(32'h54505503)) c2(finished[2],t2,e2);
    tpu_case #(.AW(16),.SEED(32'h54505504)) c3(finished[3],t3,e3);
    initial begin
        $dumpfile("sim/tpu_top_tb.vcd");
        $dumpvars(0,tpu_top_tb);
    end
    task automatic report(input bit timeout_hit);
        begin
            tests=t0+t1+t2+t3; errors=e0+e1+e2+e3+timeout_hit;
            if(timeout_hit) $display("FAIL TPU watchdog expired");
            if(errors==0 && tests>0) $display("TPU_TOP TEST RESULT: PASS");
            else $display("TPU_TOP TEST RESULT: FAIL");
            $display("Tests: %0d\nErrors: %0d",tests,errors); $finish;
        end
    endtask
    initial begin wait(&finished); report(0); end
    initial begin repeat(10000) @(posedge c0.clk); report(1); end
endmodule
