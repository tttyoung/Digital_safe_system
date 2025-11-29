module lcd_driver(
    input clk,
    input rst,
    input [3:0] state, // 상태값
    input data_update_pulse, // 데이터 갱신 요청 펄스
    input [15:0] correct_code, // 난수
    input [15:0] user_input, // 사용자 입력
    
    output reg [7:0] lcd_data, // 데이터/커맨드 버스
    output reg lcd_en, // enable 펄스
    output reg lcd_rs, // register select ( 0: 커맨드, 1: 데이터 )
    output reg lcd_rw // read/write (0: 쓰기 모드)
);

// FSM 상태 정의
localparam IDLE = 4'b0001;
localparam MAKE_NUM = 4'B0010;
localparam INPUT_CAL = 4'b0011;
localparam INPUT_DIAL = 4'B0101;
localparam UNLOCK = 4'b0111;
localparam FAIL = 4'b1000;
localparam DEACTIVATE = 4'b1001;
localparam EMERGENCY = 4'b1010;
localparam ADMIN = 4'b1011;

// lcd 드라이버 내부 FSM 상태 정의
localparam [3:0]
    INIT_DELAY = 4'b0000,
    INIT_SEQ = 4'b0001,
    WAIT_UPDATE = 4'b0010,
    WRITE_CMD = 4'b0011,
    WRITE_DATA = 4'b0100;
    
// 타이밍, 메세지 제어
reg [3:0] lcd_fsm_state, lcd_fsm_next;
reg [3:0] msg_index;
reg [3:0] state_prev;
wire state_changed = (state != state_prev);

// 4bit BCD 숫자를 아스키 코드 문자로 변환 함수
function [7:0] bcd_to_ascii;
    input [3:0] bcd_in;
    begin
        bcd_to_ascii = bcd_in + 8'h30;
    end
endfunction

// 1행 메세지 출력 결정
function [7:0] line1_data;
    input [3:0] state;
    input [3:0] index;
    begin
        case(state)
            IDLE: line1_data = (index<9) ? "press #" : 8'h20;
            INPUT_CAL: line1_data = (index<10) ? "ENTER CODE" : 8'h20;
            INPUT_DIAL: line1_data = (index<11) ? "ADJUST DIAL": 8'h20;
            UNLOCK: line1_data = (index<14) ? "ACCESS GRANTED": 8'h20;
            FAIL: line1_data = (index<11) ? "ACCESS DENIED" : 8'h20;
            DEACTIVATE: line1_data = (index<10) ? "GAME OVER!!": 8'h20;
            EMERGENCY: line1_data = (index<11) ? "EMERGENCY" : 8'h20;
            ADMIN: line1_data = (index<12) ? "ADMIN MODE" : 8'h20;
            default: line1_data = 8'h20;
        endcase
    end
endfunction

// 2행 메세지 : 난수, 사용자 입력 데이터 출력
function [7:0] line2_data;
    input[3:0] index;
    input[15:0] target_code;
    input[15:0] user_code;
    begin
        case(index)
            4'd0: line2_data = 8'h52;
            4'd1: line2_data = 8'h3A;
            4'd2: line2_data = bcd_to_ascii(target_code[15:12]);
            4'd3: line2_data = bcd_to_ascii(target_code[11:8]);
            4'd4: line2_data = bcd_to_ascii(target_code[7:4]);
            4'd5: line2_data = bcd_to_ascii(target_code[3:0]);
            4'd7: line2_data = 8'h49;
            4'd8: line2_data = 8'h3A;
            4'd9: line2_data = bcd_to_ascii(target_code[15:12]);
            4'd10: line2_data = bcd_to_ascii(target_code[11:8]);
            4'd11: line2_data = bcd_to_ascii(target_code[7:4]);
            4'd12: line2_data = bcd_to_ascii(target_code[3:0]);
            default: line2_data = 8'h20;
        endcase
    end
endfunction

// LCD 드라이버 FSM
always @(posedge clk or posedge rst) begin
    if(rst) begin
        lcd_fsm_state <= INIT_DELAY;
        state_prev <= 4'd0;
        msg_index <= 4'd0;
        enable_pulse_counter <= 3'd0;
    end else begin
        lcd_fsm_state <= lcd_fsm_next;
        state_prev <= state;
        
        if(lcd_en) begin
            if(enable_pusle_counter == 3'd7) begin
                lcd_en <= 1'b0; // end pulse
                enable_pulse_counter <= 3'd0;
            end else begin  
                enable_pulse_counter <= enable_pulse_counter + 1;
            end
        end
    end
end

// LCD Command/data 생성 로직
always @(*) begin
    // 기본값
    lcd_fsm_next = lcd_fsm_state;
    lcd_rs = 1'b0;
    lcd_rw = 1'b0;
    lcd_en = 1'b0;
    lcd_data = 8'h20;
    
    case(lcd_fsm_state)
        INIT_DELAY : begin
            lcd_fsm_next = INIT_SEQ;
        end
        INIT_SEQ : begin
            if(msg_index == 4'd4) lcd_fsm_next = WAIT_UPDATE;
            else begin msg_index = msg_index + 1; lcd_data = 8'h38; lcd_en = 1'b1; end
        end
        
        WIRTE_CMD : begin
            if(msg_index == 4'd0) begin lcd_data = 8'h01; lcd_en = 1'b1; msg_index = msg_index + 1; end
            else if(msg_index == 4'd1) begin lcd_data = 8'h80; lcd_en = 1'b1; msg_index = msg_index + 1; end
            else if(msg_index == 4'd2) lcd_fsm_next = WRITE_DATA;
       end
       WRITE_DATA : begin
            if(msg_index < 4'd18) begin
                lcd_rs = 1'b1;
                lcd_en = 1'b1;
                lcd_data = line1_data(state, msg_index - 4'd2);
                msg_index = msg_index+1;
            end
            else if(msg_index == 4'd18) begin
                lcd_rs = 1'b0;
                lcd_data = 8'hC0;
                lcd_en = 1'b1;
                msg_index = msg_index + 1;
            end
            else if(msg_index < 4'd35) begin
                lcd_rs = 1'b1;
                lcd_en = 1'b1;
                lcd_data = line2_data(msg_index - 4'd17, correct_code, user_input);
                msg_index = msg_index + 1;
            end
            else begin lcd_fsm_next = WAIT_UPDATE; end 
        default : begin lcd_fsm_next = INIT_DELAY; end  
    endcase
end

endmodule
            
