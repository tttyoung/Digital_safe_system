module output_test_driver (
    // FPGA Clock and Control (Must be connected to physical pins)
    input clk_50mhz,        // 50MHz Clock (for internal timing)
    input rst,              // Reset Button
    
    // Test Inputs (Used to manually select FSM state and chances)
    input [3:0] dip_state,    // DIP Switch 4-bit input to select FSM State
    input [3:0] dip_chance,   // DIP Switch 4-bit input to select Chance Count (0-3)
    input btn_dummy,          // Dummy Button (e.g., to generate a simple clock)

    // Outputs (To be connected to physical pins)
    output [11:0] rgb_out,     // Full Color LED
    output [2:0] chance_led,   // 3 Array LEDs
    output servo_pwm,          // Servo Motor PWM
    output piezo_pwm,          // Piezo Buzzer PWM
    output [6:0] seg_cathode,  // 7-Seg Cathode Pattern (a-g)
    output [7:0] seg_anode,    // 7-Seg Anode Enable (8 cells)
    output [7:0] lcd_data,     // Text LCD Data Bus
    output lcd_en, lcd_rs, lcd_rw // LCD Control Signals
);

// --- 1. Signal Generation and Mapping ---

// FSM State and Data (Manually Mapped)
// **핵심: DIP 스위치 입력을 FSM 상태로 직접 매핑**
wire [3:0] state = dip_state; 
wire [3:0] chance_count = dip_chance; 

// Test Data Assignments (고정 값으로 설정)
reg [15:0] input_data_fixed; // 7-Seg Input Data (e.g., 난수)
reg [5:0] timer_min_fixed;   // 12분
reg [5:0] timer_sec_fixed;   // 12초

// Clock Generation (Internal timing signals needed by modules)
reg clk_1khz = 1'b0;
reg clk_mux = 1'b0;
reg [15:0] count_1k;
reg [15:0] count_mux;

// --- Clock Divider Simulation (Generates 1kHz and MUX clocks from 50MHz) ---
// Note: This needs to be precisely calculated for the 50MHz FPGA clock (clk_50mhz)
always @(posedge clk_50mhz or posedge rst) begin
    if (rst) begin
        count_1k <= 16'd0;
        clk_1khz <= 1'b0;
        count_mux <= 16'd0;
        clk_mux <= 1'b0;
    end else begin
        // 1kHz Divider (50,000 counts)
        if (count_1k == 16'd24999) begin // 50M / 2 / 25,000 = 1kHz (for clk_1khz)
            clk_1khz <= ~clk_1khz;
            count_1k <= 16'd0;
        end else begin
            count_1k <= count_1k + 1'b1;
        end
        
        // MUX Clock Divider (e.g., 500Hz, 50,000 counts)
        if (count_mux == 16'd49999) begin // 50M / 2 / 50,000 = 500Hz (for clk_mux)
            clk_mux <= ~clk_mux;
            count_mux <= 16'd0;
        end else begin
            count_mux <= count_mux + 1'b1;
        end
    end
end

// --- Fixed Test Data Assignment ---
// 타이머: 12분 12초 (Binary 6'd12)
always @(posedge clk_50mhz) begin
    timer_min_fixed <= 6'd12;
    timer_sec_fixed <= 6'd12;
    
    // Input Data (7-Seg): 1234 (BCD)
    input_data_fixed <= 16'h1234; 
end

// --- 2. Module Instantiation (Use original module inputs) ---

// 2-1. Feedback (RGB LED & Piezo)
feedback_controller U_FEEDBACK (
    .clk_1khz(clk_1khz),
    .rst(rst),
    .state(state),
    .rgb_out(rgb_out),
    .piezo_pwm(piezo_pwm)
);

// 2-2. Servo Motor Controller (Requires dedicated 1MHz clock if simplified)
// We need a 1MHz clock. Since we don't have a specific 1MHz divider here, 
// we assume the servo controller is modified to use clk_50mhz directly or we use a simple wire.
wire clk_1mhz_dummy = clk_50mhz; // DUMMY: Replace with actual divided clock
servo_controller U_SERVO (
    .clk(clk_1mhz_dummy), 
    .rst(rst),
    .state(state),
    .servo(servo_pwm)
);

// 2-3. 8-Cell 7-Segment Timer Display & Chance LED
timer_display_mux U_TIMER_DISPLAY (
    .clk_mux(clk_mux),
    .rst(rst),
    .state(state),
    .chance_count(chance_count),
    .input_data(input_data_fixed),
    .timer_min(timer_min_fixed),
    .timer_sec(timer_sec_fixed),
    .seg_cathode(seg_cathode),
    .seg_anode(seg_anode),
    .chance_led(chance_led)
);

// 2-4. Text LCD Driver
lcd_driver U_LCD (
    .clk(clk_50mhz), 
    .rst(rst),
    .state(state),
    .lcd_data(lcd_data),
    .lcd_en(lcd_en),
    .lcd_rs(lcd_rs),
    .lcd_rw(lcd_rw)
);

endmodule