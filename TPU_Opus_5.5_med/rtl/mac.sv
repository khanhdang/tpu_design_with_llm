// Signed multiply-accumulate unit.
// Synchronous active-low reset; priority: reset > clr > en > hold.
// Accumulates the a/b inputs sampled at the current rising edge (no input registers).
module mac #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32
) (
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         clr,
    input  logic                         en,
    input  logic signed [DATA_WIDTH-1:0] a,
    input  logic signed [DATA_WIDTH-1:0] b,
    output logic signed [ACC_WIDTH-1:0]  acc
);

    logic signed [2*DATA_WIDTH-1:0] product;
    logic signed [ACC_WIDTH-1:0]    product_ext;

    assign product     = a * b;
    // Explicit sign extension of the full-width signed product to ACC_WIDTH.
    assign product_ext = {{(ACC_WIDTH - 2*DATA_WIDTH + 1){product[2*DATA_WIDTH-1]}},
                          product[2*DATA_WIDTH-2:0]};

    always_ff @(posedge clk) begin
        if (!rst_n)
            acc <= '0;
        else if (clr)
            acc <= '0;
        else if (en)
            acc <= acc + product_ext;  // wraps modulo 2**ACC_WIDTH
    end

endmodule
