module servo_controller(
    input clk,
    input rst,
    input [3:0] state,
    
    output reg servo // Servo motor를 구동하기 위한 pwm 신호 출력
);

localparam UNLOCK = 4'b0111; // 금고 잠금 해제 state

localparam PWM_PERIOD = 1000000; // PWM을 주기 (20ms)를 위한 전체 카운트 값

localparam DUTY_0_DEG = 50000; // 1.0ms pulse 폭 (잠김)
localparam DUTY_180_DEG = 100000; // 2.0ms pulse 폭 (열림)

reg [19:0] pwm_counter;
reg [19:0] duty_cycle;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        pwm_counter <= 20'd0;
        duty_cycle <= DUTY_0_DEG;
    end
    else begin
        if (pwm_counter == PWM_PERIOD-1) begin // 999,999에서 카운터 리셋
            pwm_counter <= 20'd0;
            
            // 열림 state의 경우
            if(state == UNLOCK) begin
                duty_cycle <= DUTY_180_DEG; // 열림
            end 
            // 그 외의 state의 경우
            else begin
                duty_cycle <= DUTY_0_DEG; // 잠김
            end
        
        end else begin
            pwm_counter <= pwm_counter + 1;
        end
        
        // PWM Generation
        // 펄스 폭 이내일 때 high 출력
        if(pwm_counter < duty_cycle) begin
            servo <= 1'b1;
        end
        // 펄스 폭 초과하면 low 출력
        else begin 
            servo <= 1'b0;
        end
    end
end

endmodule