module mac #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32
) (
    input  logic clk,
    input  logic rst_n,
    input  logic clr,
    input  logic en,
    input  logic signed [DATA_WIDTH-1:0] a,
    input  logic signed [DATA_WIDTH-1:0] b,
    output logic signed [ACC_WIDTH-1:0] acc
);
    localparam int PRODUCT_WIDTH = 2 * DATA_WIDTH;
    localparam int EXT_WIDTH = ACC_WIDTH - PRODUCT_WIDTH;

    logic signed [PRODUCT_WIDTH-1:0] product;
    logic signed [ACC_WIDTH-1:0] product_ext;

    assign product = a * b;

    generate
        if (EXT_WIDTH == 0) begin : gen_no_extend
            assign product_ext = product;
        end else begin : gen_sign_extend
            assign product_ext = {{EXT_WIDTH{product[PRODUCT_WIDTH-1]}}, product};
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            acc <= '0;
        end else if (clr) begin
            acc <= '0;
        end else if (en) begin
            acc <= acc + product_ext;
        end
    end
endmodule
