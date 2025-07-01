module Decode (
    input   wire            clk,
    input   wire            rst,
    input   wire    [127:0] inst_4W_in,
    input   wire    [3:0]   inst_4W_valid_in,
    //握手信号
    input  wire             pre_valid,
    input  wire             next_ready,
    output wire             out_valid,
    output wire             out_ready
);
    reg     valid;
    wire    ready_go;//根据实现定义未完成
    assign  out_ready= !valid||(ready_go&&next_ready);
    assign  out_valid= valid&&ready_go;

    always @(posedge clk ) begin
        if(rst)begin
            valid <=1'b0;
        end else if (out_ready) begin
            valid <= pre_valid;
        end
    end
    reg [127:0] inst_4W;
    reg [3:0]   inst_4W_valid;
    always @(posedge clk ) begin
        if (out_ready&&pre_valid) begin
            inst_4W <= inst_4W_in;
            inst_4W_valid <= inst_4W_valid_in;
        end
    end
    //拆分出四条指令和对应的有效信号
    wire    [31:0]  inst_0,inst_1,inst_2,inst_3;
    wire            inst_valid_0,inst_valid_1,inst_valid_2,inst_valid_3;
    assign inst_0 = inst_4W[127:96];
    assign inst_1 = inst_4W[ 95:64];
    assign inst_2 = inst_4W[ 63:32];
    assign inst_3 = inst_4W[ 31:0 ];
    assign inst_valid_0 = inst_4W_valid[3];
    assign inst_valid_1 = inst_4W_valid[2];
    assign inst_valid_2 = inst_4W_valid[1];
    assign inst_valid_3 = inst_4W_valid[0];

endmodule
module SingleInstDecode (
    input   [31:0]  inst
);
    
endmodule
