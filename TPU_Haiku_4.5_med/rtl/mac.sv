module mac #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 32
) (
    input  logic clk,
    input  logic rst_n,
    input  logic clr,
    input  logic en,
    input  logic signed [DATA_WIDTH-1:0] a,
    input  logic signed [DATA_WIDTH-1:0] b,
    output logic signed [ACC_WIDTH-1:0] acc
);

    logic signed [2*DATA_WIDTH-1:0] product;
    logic signed [ACC_WIDTH-1:0] extended_product;

    assign product = a * b;
    assign extended_product = $signed(product);

    always @(posedge clk) begin
        if (!rst_n) begin
            acc <= '0;
        end else if (clr) begin
            acc <= '0;
        end else if (en) begin
            acc <= acc + extended_product;
        end
    end

endmodule
