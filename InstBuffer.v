module InstBuffer #(
    parameter DEPTH = 4
    )(
    input   wire            clk,
    input   wire            rst,
    input   wire    [127:0] inst_group,
    input   wire    [3:0]   inst_group_valid,
    input   wire    [27:0]  inst_group_pc,
    output  wire    [127:0] inst_4W,
    output  wire    [3:0]   inst_4W_valid,
    output  wire    [27:0]  inst_4W_pc,
    //握手信号
    input  wire             pre_valid,
    input  wire             next_ready,
    output wire             out_valid,
    output wire             out_ready
    );
    //计算指针位宽
    localparam PTR_WIDTH = $clog2(DEPTH);
    // 存储阵列
    reg [127:0] inst_4W_arr      [0:DEPTH-1];
    reg [3:0]   inst_4W_valid_arr[0:DEPTH-1];
    reg [27:0]  inst_4W_pc_arr   [0:DEPTH-1];
    // 读写指针
    reg [PTR_WIDTH-1:0] w_ptr;
    reg [PTR_WIDTH-1:0] r_ptr;
    // 计数器，记录buffer中的元素数量
    reg [PTR_WIDTH:0] count;
    wire              full  = (count == DEPTH);
    wire              empty = (count == 0);
    // 读写操作条件
    wire do_write = pre_valid  && !full;
    wire do_read  = next_ready && !empty;
    always @(posedge clk) begin
        if (rst) begin
            // 复位逻辑
            w_ptr  <= 0;
            r_ptr  <= 0;
            count  <= 0;
        end else begin
            // 写操作逻辑
            if (do_write) begin
                inst_4W_arr[w_ptr]       <= inst_group;
                inst_4W_valid_arr[w_ptr] <= inst_group_valid;
                inst_4W_pc_arr[w_ptr]    <= inst_group_pc;
                w_ptr   <= w_ptr + 1;
            end
            // 读操作逻辑
            if (do_read) begin
                r_ptr  <= r_ptr + 1;
            end
        end
    end
    assign inst_4W       = inst_4W_arr[r_ptr]      ;
    assign inst_4W_valid = inst_4W_valid_arr[r_ptr];
    assign inst_4W_pc    = inst_4W_pc_arr[r_ptr];
    // 计数器更新逻辑
    always @(posedge clk) begin
        if (rst) begin
            count <= 0;
        end else begin
            // 根据有效的读写操作来更新计数器
            case ({do_write, do_read})
                2'b10:  // 只写
                    count <= count + 1;
                2'b01:  // 只读
                    count <= count - 1;
                2'b11:  // 同时读写
                    count <= count; // 元素数量不变
                default://无操作
                    count <= count; // 元素数量不变
            endcase
        end
    end
    assign  out_valid = !empty;
    assign  out_ready = !full;
endmodule