module feedback_controller(
    input clk_1khz,
    input rst,
    input [3:0] state,
    
    output reg [11:0] rgb_out,
    output reg piezo_pwm
);

// STATE를 명시하기 위한 상수
localparam SUCCESS = 4'b0111; // UNLOCK STATE
localparam FAIL = 4'b1000; // FAIL STATE
localparam EMERGENCY = 4'b1010; // EMERGENCY STATE
localparam DEACTIVATE = 4'b1001; // LOCKOUT STATE

// FULL COLOR LED 로직
reg blink_1hz; // 점멸을 위함

// 1hz blink 생성
reg [9:0] blink_counter;
always @(posedge clk_1khz or posedge rst) begin
    if(rst) begin
        blink_counter <= 10'd0;
        blink_1hz <= 1'b0;
    end else begin
        if(blink_counter == 10'd500) begin // 매 0.5초마다 toggle
            blink_1hz <= ~blink_1hz;
            blink_counter <= 10'd0;
        end else begin
            blink_counter <= blink_counter + 1;
        end
    end
end

// FULL COLOR LED 출력 로직
always @(*) begin
    case(state)
        SUCCESS: rgb_out = {4'h0, 4'hF, 4'h0}; // GREEN
        FAIL: rgb_out = {4'hF, 4'h0, 4'h0}; // RED
        EMERGENCY: rgb_out = blink_1hz ? {4'hF, 4'hF, 4'h0} : 12'h000; // ORANGE(BLINK)
        DEACTIVATE: rgb_out = blink_1hz ? {4'hF, 4'h0, 4'h0} : 12'h000; // RED(BLINK)
        default : rgb_out = 12'h000;
    endcase
end

// piezo PWM 로직 
reg [9:0] pwm_counter; // pwm 카운트 
reg piezo_signal; // 출력을 위한 임시 변수

always @(posedge clk_1khz or posedge rst) begin
    if(rst) begin 
        pwm_counter <= 10'd0;
        piezo_signal <= 1'b0;
    end else begin
        if(state == SUCCESS) begin // 성공시 piezo 출력
            piezo_signal <= ~piezo_signal; // high tone (~2khz)
        end 
        else if (state == FAIL || state == DEACTIVE) begin // 실패,비활성화 시 piezo 출력
            if(pwm_counter == 10'd3) begin
                piezo_signal <= ~piezo_signal; // low tone (~250hz) 
                pwm_counter <= 10'd0;  
            end
            else begin
                pwm_counter <= pwm_counter + 1;
            end
        end 
        else begin  // default
            pwm_signal <= 1'b0; // mute
        end
    end
end

assign piezo_pwm = piezo_signal; // 최종 출력

endmodule