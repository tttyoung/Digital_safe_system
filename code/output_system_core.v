module output_system_core(
    // 입력 ( FSM/컨트롤 로직으로 부터 받음)
    input clk, 
    input rst,
    input [3:0] state, // 현재 FSM 상태
    input [3:0] chance_count, // 남은 기회 카운트
    input [15:0] input_data, // 8-7세그먼트를 위한 인풋
    input [5:0] timer_min, // 출력할 minutes
    input [5:0] timer_sec, // 출력할 sec
    input clk_1khz, // PWM/Timing을 위한 1KHZ clock
    input clk_mux, // 8-7세그먼트를 위함 ~500Hz Clock 
    
    // 출력
    output [11:0] rgb_out, // FULL COLOR LED
    output [2:0] chance_led, // 남은 기회 led
    output wire servo_pwm, // servo motor pwm
    output piezo, // piezo
    output[6:0] set_cathode, // 7세그먼트 문자 출력을 위함
    output[7:0] seg_anode, // 8-7세그먼트 어떤 자리 출력할지 결정
    output[7:0] lcd_data, // text lcd
    output lcd_en, lcd_rs, lcd_rw // lcd 컴트롤에 필요한 신호
);

// wire 선언 (모듈 간의 신호를 연결하거나 데이터를 임시로 저장하는데 사용)
wire [6:0] timer_seg_cathode_w; // 모듈에서 생성된 7세그먼트 패턴 데이터를 임시로 전달받음
wire [7:0] timer_seg_anode_w; // 모듈에서 생성된 7세그먼트 8개의 셀 자리 신호를 임시로 받음.

// 모듈 객체 생성
// 1. feedback(FULL COLOR LED & Piezo)
feedback_controller U_FEEDBACK(
    .clk_1khz(clk_1khz),
    .rst(rst),
    .state(state),
    .rgb_out(rgb_out),
    .piezo_pwm(piezo_pwm)
);

// 2. 서보모터 컨트롤러
servo_controller U_SERVO (
    .clk(clk),
    .rst(rst),
    .state(state),
    .servo(servo_pwm)
);

// 3. 8cell 7세그먼트 display & chance led
timer_display_mux U_TIMER_DISPLAY(
    .clk_mux(clk_mux),
    .rst(rst),
    .state(state),
    .chance_count(chance_count),
    .input_data(input_data),
    .timer_min(timer_min),
    .timer_sec(timer_sec),
    .seg_cathode(seg_cathode), 
    .seg_anode(seg_anode),  
    .chance_led(chance_led)
);

// 4. 텍스트 LCD
lcd_driver U_LCD (
    .clk(clk),
    .rst(rst),
    .state(state),
    .lcd_data(lcd_data),
    .lcd_en(lcd_en),
    .lcd_rs(lcd_rs),
    .lcd_rw(lcd_rw)
);

endmodule
