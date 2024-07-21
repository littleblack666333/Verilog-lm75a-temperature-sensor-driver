// driver for LM75A temperature sensor
// using the I2C communication protocol, the temperature accuracy is 0.5℃
// the raw temperature data has been converted to 8421 BCD code

module lm75a_driver(
    clk,
    rst_n,
    valid,
    sign,
    fractional,
    ones,
    tens,
    hundreds,
    scl,
    sda
);

    input clk;  // system clock
    input rst_n;  // reset signal, active low
    output valid;  // temperature data validation signal
    output sign;  // sign of temperature, 0: passive, 1: negative
    output [3:0] fractional;  // *0.1, 8421 BCD code
    output [3:0] ones;  // *1, 8421 BCD code
    output [3:0] tens;  // *10, 8421 BCD code
    output [3:0] hundreds;  // *100, 8421 BCD code
    output scl;  // scl port of i2c protocol
    inout sda;  // sda port of i2c protocol

    wire clk;
    wire rst_n;
    reg valid;
    reg sign;
    reg [3:0] fractional;
    reg [3:0] ones;
    reg [3:0] tens;
    reg [3:0] hundreds;
    reg scl;
    wire sda;

    // self-defined parameters
    parameter DEVICE_ADDR = 8'b1001_000_1;  // address of lm75a device, A2 A1 AO are self-defined bits
    parameter READ_TIME = 32'd50_000_000;  // time of one read period, for 50MHz clk freq, it is 1s(1Hz)
    parameter STEP_TIME = 9'd500;  // for 50MHz clk freq, step time is 10us(100KHz), one step for one scl period

    // state index
    localparam IDLE = 4'd0;
    localparam START = 4'd1;
    localparam TRANS_ADDR = 4'd2;
    localparam READ_MSB = 4'd3;
    localparam READ_LSB = 4'd4;
    localparam FINISH = 4'd5;

    reg sda_dir;  // data direction on sda, 1: master -> device, 0: master <- device
    wire sda_input;  // sda data input
    reg sda_output;  // sda data output
    reg [31:0] cnt_read;  // counter of read period
    reg read_flag;  // trigger signal of a read period
    reg [8:0] cnt_step;  // counter of step, period of cnt_step is one step time
    reg en_cnt_step;  // enable signal of cnt_step, only if 1 cnt_step will work
    reg [3:0] cnt_bit;  // counter of bit in step, using cnt_bit == 4'd8 as end symbol
    reg en_cnt_bit;  // enable signal of cnt_bit, only if 1 cnt_bit will work
    reg [3:0] state;  // state mark
    reg [15:0] buff;  // buffer of data directly read from sda_input
    reg [7:0] data;  // 8-bit binary temperature data (sign bit not included)
    reg [7:0] data_temp;  // temporary register used to decode temperature data
    integer i;  // iteration variable used to decode temperature data

    // instance of inout sda
    assign sda_input = sda;
    assign sda = sda_dir ? sda_output : 1'bz;

    // def of cnt_read and read_flag
    always @(negedge rst_n or posedge clk) begin
        if (~rst_n) begin
            cnt_read <= 32'b0;
            read_flag <= 1'b0;
        end
        else if (cnt_read == READ_TIME - 1'b1) begin
            cnt_read <= 32'b0;
            read_flag <= 1'b1;
        end
        else begin
            cnt_read <= cnt_read + 1'b1;
            read_flag <= 1'b0;
        end
    end

    // def of cnt_step
    always @(negedge rst_n or posedge clk) begin
        if (~rst_n) begin
            cnt_step <= 9'b0;
        end
        else if (en_cnt_step) begin
            if (cnt_step == STEP_TIME - 1'b1) begin
                cnt_step <= 9'b0;
            end
            else begin
                cnt_step <= cnt_step + 1'b1;
            end
        end
        else begin  // !en_cnt_step
            cnt_step <= 9'b0;
        end
    end
    
    // def of scl
    always @(negedge rst_n or posedge clk) begin
        if (~rst_n) begin
            scl <= 1'b1;
        end
        else if (en_cnt_step)  begin
            if (cnt_step == STEP_TIME[8:1] - 1'b1) begin
                scl <= 1'b1;
            end
            else if (cnt_step == STEP_TIME - 1'b1) begin
                scl <= 1'b0;
            end
            else begin
                scl <= scl;
            end
        end
        else begin  // !en_cnt_step
            scl <= 1'b1;
        end
    end

    // def of cnt_bit
    always @(negedge rst_n or posedge clk) begin
        if (~rst_n) begin
            cnt_bit <= 4'b0;
        end
        else if (en_cnt_bit) begin
            if (cnt_step == STEP_TIME - 1'b1) begin
                if (cnt_bit == 4'd8) begin
                    cnt_bit <= 4'b0;
                end
                else begin
                    cnt_bit <= cnt_bit + 1'b1;
                end
            end
        end
        else begin  // !en_cnt_bit
            cnt_bit <= 4'b0;
        end
    end

    // i2c main module
    always @(negedge rst_n or posedge clk) begin
        if (~rst_n) begin
            valid <= 1'b0;
            sda_dir <= 1'b1;
            sda_output <= 1'b1;
            en_cnt_step <= 1'b0;
            en_cnt_bit <= 1'b0;
            state <= IDLE;
            buff <= 16'b0;
            data <= 8'b0;
            sign <= 1'b0;
        end
        else begin
            case (state)
                IDLE: begin  // IDLE state, reset related flags
                    valid <= 1'b0;
                    sda_dir <= 1'b1;
                    sda_output <= 1'b1;
                    en_cnt_step <= 1'b0;
                    en_cnt_bit <= 1'b0;

                    if (read_flag) begin  // wait for trigger signal
                        en_cnt_step <= 1'b1;
                        state <= START;
                    end
                end

                START: begin  // transfer start signal
                    if (cnt_step == STEP_TIME[8:1] - 1'b1) begin
                        sda_dir <= 1'b1;
                        sda_output <= 1'b0;
                    end
                    else if (cnt_step == STEP_TIME - 1'b1) begin
                        en_cnt_bit <= 1'b1;
                        state <= TRANS_ADDR;
                    end
                end

                TRANS_ADDR: begin  // transfer device address and receive device acknowledge
                    if (cnt_step == STEP_TIME - 1'b1) begin  // check device acknowledge
                        if (cnt_bit == 4'd8) begin
                            if (sda_input == 1'b0) begin  // device acknowledge
                                state <= READ_MSB;
                            end
                            else begin  // device not acknowledge
                                state <= IDLE;
                            end
                        end
                    end

                    if (cnt_bit < 4'd8) begin  // transfer device address
                        if (cnt_step == STEP_TIME[8:2] - 1'b1) begin
                            sda_dir <= 1'b1;
                            sda_output <= DEVICE_ADDR[4'd7 - cnt_bit];
                        end
                    end
                    else begin  // receive device acknowledge
                        if (cnt_step == STEP_TIME[8:2] - 1'b1) begin
                            sda_dir <= 1'b0;
                        end
                    end
                end

                READ_MSB: begin  // read MSB of temperature data, and transfer master acknowledge
                    if (cnt_step == STEP_TIME - 1'b1) begin
                        if (cnt_bit == 4'd8) begin
                            sda_dir <= 1'b0;
                            state <= READ_LSB;
                        end
                    end

                    if (cnt_bit < 4'd8) begin  // receive temperature data
                        if (cnt_step == STEP_TIME[8:1] + STEP_TIME[8:2] - 1'b1) begin
                            buff <= {buff[14:0], sda_input};
                        end
                    end
                    else begin  // master acknowledge
                        if (cnt_step == STEP_TIME[8:2] - 1'b1) begin
                            sda_dir <= 1'b1;
                            sda_output <= 1'b0;
                        end
                    end
                end

                READ_LSB: begin  // read LSB of temperature data, but master not acknowledge at the end
                    if (cnt_step == STEP_TIME - 1'b1) begin
                        if (cnt_bit == 4'd8) begin
                            state <= FINISH;
                        end
                    end

                    if (cnt_bit < 4'd8) begin  // receive temperature data
                        if (cnt_step == STEP_TIME[8:1] + STEP_TIME[8:2] - 1'b1) begin
                            buff <= {buff[14:0], sda_input};
                        end
                    end
                    else begin  // master not acknowledge
                        if (cnt_step == STEP_TIME[8:2] - 1'b1) begin
                            sda_dir <= 1'b1;
                            sda_output <= 1'b1;
                        end
                    end
                end

                FINISH: begin  // transfer end signal and refresh temperature data
                    if (cnt_step == STEP_TIME[8:2] - 1'b1) begin  // transfer end signal
                        sda_dir <= 1'b1;
                        sda_output <= 1'b0;
                    end
                    else if (cnt_step == STEP_TIME[8:1] + STEP_TIME[8:2] - 1'b1) begin
                        sda_dir <= 1'b1;
                        sda_output <= 1'b1;
                    end
                    else if (cnt_step == STEP_TIME - 2'd2) begin  // extract data from buffer
                        if (buff[15] == 1'b0) begin  // passive data
                            data <= buff[14:7];
                        end
                        else begin  // negative data
                            data <= ~buff[14:7] + 1'b1;
                        end
                        sign <= buff[15];
                    end
                    else if (cnt_step == STEP_TIME - 1'b1) begin  // reset flags
                        valid <= 1'b1;
                        en_cnt_step <= 1'b0;
                        state <= IDLE;
                    end
                end

                default: begin
                    valid <= 1'b0;
                    sda_dir <= 1'b1;
                    sda_output <= 1'b1;
                    en_cnt_step <= 1'b0;
                    en_cnt_bit <= 1'b0;
                    state <= IDLE;
                    buff <= 16'b0;
                    data <= 8'b0;
                    sign <= 1'b0;
                end
            endcase
        end
    end

    // data decoding
    always @(data[0]) begin  // fractional part
        case (data[0])
            1'b1: fractional = 4'd5;
            default: fractional = 4'd0;
        endcase
    end

    always @(data[7:1]) begin  // integer part
        ones = 4'd0;
        tens = 4'd0;
        hundreds = 4'd0;
        data_temp = {1'b0, data[7:1]};
        for (i = 0; i < 8; i = i + 1) begin
            if (ones >= 4'd5) begin
                ones = ones + 4'd3;
            end
            if (tens >= 4'd5) begin
                tens = tens + 4'd3;
            end
            if (hundreds >= 4'd5) begin
                hundreds = hundreds + 4'd3;
            end
            hundreds = {hundreds[2:0], tens[3]};
            tens = {tens[2:0], ones[3]};
            ones = {ones[2:0], data_temp[7 - i]};
        end
    end

endmodule
