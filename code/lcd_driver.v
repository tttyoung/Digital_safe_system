module lcd_driver (
    input clk,             // 50MHz 시스템 클럭
    input rst,
    input [3:0] state,     // FSM 현재 상태 (외부 입력)
    input data_update_pulse, // 데이터 갱신 요청 펄스
    input [15:0] correct_code, // 난수
    input [15:0] user_input, // 사용자 입력
    
    output reg [7:0] lcd_data, // D7-D0
    output reg lcd_en,         // Enable
    output reg lcd_rs,         // RS
    output reg lcd_rw          // RW
);
// --- 1. 상태 및 상수 정의 ---
localparam S_IDLE           = 4'b0001;
localparam S_MAKE_NUM       = 4'b0010;
localparam S_INPUT_CAL      = 4'b0011;
localparam S_INPUT_DIAL     = 4'b0101;
localparam S_UNLOCK         = 4'b0111;
localparam S_FAIL           = 4'b1000;
localparam S_DEACTIVATE     = 4'b1001;
localparam S_EMERGENCY      = 4'b1010;
localparam S_ADMIN          = 4'b1011;

// LCD 내부 FSM 상태
localparam [3:0]
    L_PWR_UP       = 4'd0,  // 전원 인가 후 대기 (>15ms)
    L_INIT_SEQ1    = 4'd1,  // Function Set 1
    L_INIT_SEQ2    = 4'd2,  // Function Set 2
    L_INIT_SEQ3    = 4'd3,  // Function Set 3
    L_FUNC_SET     = 4'd4,  // Function Set (8bit, 2line)
    L_DISP_OFF     = 4'd5,  // Display OFF
    L_CLR_DISP     = 4'd6,  // Clear Display
    L_ENTRY_MODE   = 4'd7,  // Entry Mode Set
    L_DISP_ON      = 4'd8,  // Display ON
    L_READY        = 4'd9,  // 준비 완료 (대기)
    L_WRITE_CMD    = 4'd10, // 커맨드 쓰기
    L_WRITE_DATA   = 4'd11; // 데이터 쓰기

reg [3:0] lcd_state;
reg [3:0] lcd_next_state;

// --- 2. 타이밍 카운터 ---
// 50MHz 기준: 1ms = 50,000클럭, 1us = 50클럭
reg [19:0] delay_cnt; 
reg [5:0] msg_index;
reg [3:0] state_prev; 
wire state_changed = (state != state_prev);

// --- 3. 데이터 변환 함수 ---
function [7:0] bcd_to_ascii;
    input [3:0] bcd_in;
    begin
        case(bcd_in)
            4'h0: bcd_to_ascii = 8'h30; // '0'
            4'h1: bcd_to_ascii = 8'h31; // '1'
            4'h2: bcd_to_ascii = 8'h32; // '2'
            4'h3: bcd_to_ascii = 8'h33; // '3'
            4'h4: bcd_to_ascii = 8'h34; // '4'
            4'h5: bcd_to_ascii = 8'h35; // '5'
            4'h6: bcd_to_ascii = 8'h36; // '6'
            4'h7: bcd_to_ascii = 8'h37; // '7'
            4'h8: bcd_to_ascii = 8'h38; // '8'
            4'h9: bcd_to_ascii = 8'h39; // '9'
            default: bcd_to_ascii = 8'h20; // 공백
        endcase
    end
endfunction

// Line 1 메시지
function [7:0] get_line1_data;
    input [3:0] current_state;
    input [3:0] index;
    begin
case (current_state)
            S_IDLE: begin // "Press #"
                case (index)
                    4'd0: get_line1_data = 8'h50; 4'd1: get_line1_data = 8'h72; 4'd2: get_line1_data = 8'h65; 4'd3: get_line1_data = 8'h73; 
                    4'd4: get_line1_data = 8'h73; 4'd5: get_line1_data = 8'h20; 4'd6: get_line1_data = 8'h23; 
                    default: get_line1_data = 8'h20;
                endcase
            end
            S_INPUT_CAL: begin // "ENTER CODE"
                case (index)
                    4'd0: get_line1_data = 8'h45; 4'd1: get_line1_data = 8'h4E; 4'd2: get_line1_data = 8'h54; 4'd3: get_line1_data = 8'h45; 
                    4'd4: get_line1_data = 8'h52; 4'd5: get_line1_data = 8'h20; 4'd6: get_line1_data = 8'h43; 4'd7: get_line1_data = 8'h4F;
                    4'd8: get_line1_data = 8'h44; 4'd9: get_line1_data = 8'h45;
                    default: get_line1_data = 8'h20;
                endcase
            end
            S_INPUT_DIAL: begin // "ADJUST DIAL"
                case (index)
                    4'd0: get_line1_data = 8'h41; 4'd1: get_line1_data = 8'h44; 4'd2: get_line1_data = 8'h4A; 4'd3: get_line1_data = 8'h55; 
                    4'd4: get_line1_data = 8'h53; 4'd5: get_line1_data = 8'h54; 4'd6: get_line1_data = 8'h20; 4'd7: get_line1_data = 8'h44;
                    4'd8: get_line1_data = 8'h49; 4'd9: get_line1_data = 8'h41; 4'd10: get_line1_data = 8'h4C;
                    default: get_line1_data = 8'h20;
                endcase
            end
            S_UNLOCK: begin // "ACCESS GRANTED"
                case (index)
                    4'd0: get_line1_data = 8'h41; 4'd1: get_line1_data = 8'h43; 4'd2: get_line1_data = 8'h43; 4'd3: get_line1_data = 8'h45;
                    4'd4: get_line1_data = 8'h53; 4'd5: get_line1_data = 8'h53; 4'd6: get_line1_data = 8'h20; 4'd7: get_line1_data = 8'h47;
                    4'd8: get_line1_data = 8'h52; 4'd9: get_line1_data = 8'h41; 4'd10: get_line1_data = 8'h4E; 4'd11: get_line1_data = 8'h54;
                    4'd12: get_line1_data = 8'h45; 4'd13: get_line1_data = 8'h44;
                    default: get_line1_data = 8'h20;
                endcase
            end
            S_FAIL: begin // "ACCESS DENIED"
                case (index)
                    4'd0: get_line1_data = 8'h41; 4'd1: get_line1_data = 8'h43; 4'd2: get_line1_data = 8'h43; 4'd3: get_line1_data = 8'h45;
                    4'd4: get_line1_data = 8'h53; 4'd5: get_line1_data = 8'h53; 4'd6: get_line1_data = 8'h20; 4'd7: get_line1_data = 8'h44;
                    4'd8: get_line1_data = 8'h45; 4'd9: get_line1_data = 8'h4E; 4'd10: get_line1_data = 8'h49; 4'd11: get_line1_data = 8'h45;
                    4'd12: get_line1_data = 8'h44;
                    default: get_line1_data = 8'h20;
                endcase
            end
            S_DEACTIVATE: begin // "GAME OVER!"
                case (index)
                    4'd0: get_line1_data = 8'h47; 4'd1: get_line1_data = 8'h41; 4'd2: get_line1_data = 8'h4D; 4'd3: get_line1_data = 8'h45;
                    4'd4: get_line1_data = 8'h20; 4'd5: get_line1_data = 8'h4F; 4'd6: get_line1_data = 8'h56; 4'd7: get_line1_data = 8'h45;
                    4'd8: get_line1_data = 8'h52; 4'd9: get_line1_data = 8'h21; 
                    default: get_line1_data = 8'h20;
                endcase
            end
            S_EMERGENCY: begin // "EMERGENCY MODE"
                case (index)
                    4'd0: get_line1_data = 8'h45; 4'd1: get_line1_data = 8'h4D; 4'd2: get_line1_data = 8'h45; 4'd3: get_line1_data = 8'h52; 
                    4'd4: get_line1_data = 8'h47; 4'd5: get_line1_data = 8'h45; 4'd6: get_line1_data = 8'h4E; 4'd7: get_line1_data = 8'h43;
                    4'd8: get_line1_data = 8'h59; 4'd9: get_line1_data = 8'h20; 4'd10: get_line1_data = 8'h4D; 4'd11: get_line1_data = 8'h4F;
                    4'd12: get_line1_data = 8'h44; 4'd13: get_line1_data = 8'h45;
                    default: get_line1_data = 8'h20;
                endcase
            end
            S_ADMIN: begin // "ADMIN MODE"
                case (index)
                    4'd0: get_line1_data = 8'h41; 4'd1: get_line1_data = 8'h44; 4'd2: get_line1_data = 8'h4D; 4'd3: get_line1_data = 8'h49; 
                    4'd4: get_line1_data = 8'h4E; 4'd5: get_line1_data = 8'h20; 4'd6: get_line1_data = 8'h4D; 4'd7: get_line1_data = 8'h4F;
                    4'd8: get_line1_data = 8'h44; 4'd9: get_line1_data = 8'h45;
                    default: get_line1_data = 8'h20;
                endcase
            end
            default: get_line1_data = 8'h20;
        endcase
    end
endfunction

// Line 2 메시지 (R:xxxx I:xxxx)
function [7:0] get_line2_data;
    input [3:0] current_state;
    input [3:0] index;
    input [15:0] target;
    input [15:0] user;
    begin
        if (current_state == S_INPUT_CAL) begin
            case (index)
                4'd0: get_line2_data = "R";
                4'd1: get_line2_data = ":";
                4'd2: get_line2_data = bcd_to_ascii(target[15:12]);
                4'd3: get_line2_data = bcd_to_ascii(target[11:8]);
                4'd4: get_line2_data = bcd_to_ascii(target[7:4]);
                4'd5: get_line2_data = bcd_to_ascii(target[3:0]);
                4'd6: get_line2_data = " ";
                4'd7: get_line2_data = "I";
                4'd8: get_line2_data = ":";
                4'd9: get_line2_data = bcd_to_ascii(user[15:12]);
                4'd10: get_line2_data = bcd_to_ascii(user[11:8]);
                4'd11: get_line2_data = bcd_to_ascii(user[7:4]);
                4'd12: get_line2_data = bcd_to_ascii(user[3:0]);
                default: get_line2_data = " ";
            endcase
        end
    end
endfunction

// --- 4. Main FSM (Sequential) ---
always @(posedge clk or posedge rst) begin
    if (rst) begin
        lcd_state <= L_PWR_UP;
        delay_cnt <= 20'd0;
        msg_index <= 4'd0;
        state_prev <= 4'd0;
        
        // 출력 초기화
        lcd_en <= 0;
        lcd_rs <= 0;
        lcd_rw <= 0;
        lcd_data <= 0;
    end else begin
        state_prev <= state; // 상태 변경 감지용

        case (lcd_state)
            // 1. 전원 인가 후 20ms 대기 (중요!)
            L_PWR_UP: begin
                if (delay_cnt < 20'd1_000_000) begin // 1,000,000 * 20ns = 20ms
                    delay_cnt <= delay_cnt + 1;
                end else begin
                    delay_cnt <= 0;
                    lcd_state <= L_INIT_SEQ1;
                end
            end

            // 2. 초기화 시퀀스 (Function Set 3번 반복 + 설정)
            L_INIT_SEQ1: begin // Function Set 1 (0x38)
                lcd_rs <= 0; lcd_data <= 8'h38;
                if (delay_cnt < 20'd100) lcd_en <= 1; // Pulse 2us
                else lcd_en <= 0;
                
                if (delay_cnt < 20'd250_000) delay_cnt <= delay_cnt + 1; // Wait 5ms
                else begin delay_cnt <= 0; lcd_state <= L_INIT_SEQ2; end
            end

            L_INIT_SEQ2: begin // Function Set 2 (0x38)
                lcd_rs <= 0; lcd_data <= 8'h38;
                if (delay_cnt < 20'd100) lcd_en <= 1;
                else lcd_en <= 0;

                if (delay_cnt < 20'd10_000) delay_cnt <= delay_cnt + 1; // Wait 200us
                else begin delay_cnt <= 0; lcd_state <= L_INIT_SEQ3; end
            end

            L_INIT_SEQ3: begin // Function Set 3 (0x38)
                lcd_rs <= 0; lcd_data <= 8'h38;
                if (delay_cnt < 20'd100) lcd_en <= 1;
                else lcd_en <= 0;

                if (delay_cnt < 20'd2_000) delay_cnt <= delay_cnt + 1; // Wait 40us
                else begin delay_cnt <= 0; lcd_state <= L_FUNC_SET; end
            end

            L_FUNC_SET: begin // Function Set (8bit, 2line, 5x8) -> 0x38
                lcd_rs <= 0; lcd_data <= 8'h38;
                if (delay_cnt < 20'd100) lcd_en <= 1;
                else lcd_en <= 0;

                if (delay_cnt < 20'd2_000) delay_cnt <= delay_cnt + 1; 
                else begin delay_cnt <= 0; lcd_state <= L_DISP_OFF; end
            end

            L_DISP_OFF: begin // Display OFF -> 0x08
                lcd_rs <= 0; lcd_data <= 8'h08;
                if (delay_cnt < 20'd100) lcd_en <= 1;
                else lcd_en <= 0;

                if (delay_cnt < 20'd2_000) delay_cnt <= delay_cnt + 1; 
                else begin delay_cnt <= 0; lcd_state <= L_CLR_DISP; end
            end

            L_CLR_DISP: begin // Clear Display -> 0x01
                lcd_rs <= 0; lcd_data <= 8'h01;
                if (delay_cnt < 20'd100) lcd_en <= 1;
                else lcd_en <= 0;

                if (delay_cnt < 20'd100_000) delay_cnt <= delay_cnt + 1; // Wait 2ms (Long!)
                else begin delay_cnt <= 0; lcd_state <= L_ENTRY_MODE; end
            end

            L_ENTRY_MODE: begin // Entry Mode (Inc, No shift) -> 0x06
                lcd_rs <= 0; lcd_data <= 8'h06;
                if (delay_cnt < 20'd100) lcd_en <= 1;
                else lcd_en <= 0;

                if (delay_cnt < 20'd2_000) delay_cnt <= delay_cnt + 1; 
                else begin delay_cnt <= 0; lcd_state <= L_DISP_ON; end
            end

            L_DISP_ON: begin // Display ON, Cursor OFF -> 0x0C
                lcd_rs <= 0; lcd_data <= 8'h0C;
                if (delay_cnt < 20'd100) lcd_en <= 1;
                else lcd_en <= 0;

                if (delay_cnt < 20'd2_000) delay_cnt <= delay_cnt + 1; 
                else begin delay_cnt <= 0; lcd_state <= L_READY; end
            end

            // 3. 준비 완료 및 업데이트 대기
            L_READY: begin
                msg_index <= 0;
                // 외부 상태 변경이나 데이터 업데이트 요청 시 쓰기 시작
                if (state_changed || data_update_pulse) begin
                    lcd_state <= L_WRITE_CMD; // Clear부터 시작
                end
            end

            // 4. 화면 갱신 (Clear -> Line1 -> Line2)
            L_WRITE_CMD: begin
                // 여기서는 간단하게 Clear(0x01) 후 바로 쓰기로 넘어감
                lcd_rs <= 0; lcd_data <= 8'h01;
                if (delay_cnt < 20'd100) lcd_en <= 1;
                else lcd_en <= 0;

                if (delay_cnt < 20'd100_000) delay_cnt <= delay_cnt + 1; // Clear는 2ms 대기
                else begin delay_cnt <= 0; lcd_state <= L_WRITE_DATA; end
            end

            L_WRITE_DATA: begin
                // 인덱스에 따라 커맨드(줄바꿈) 또는 데이터 전송
                if (msg_index == 6'd16) begin // 줄바꿈 (0xC0)
                    lcd_rs <= 0; lcd_data <= 8'hC0;
                end else begin // 데이터 쓰기
                    lcd_rs <= 1;
                    if (msg_index < 6'd16) lcd_data <= get_line1_data(state, msg_index);
                    else lcd_data <= get_line2_data(state, msg_index - 6'd17, correct_code, user_input);
                end

                // Enable Pulse (2us)
                if (delay_cnt < 20'd100) lcd_en <= 1;
                else lcd_en <= 0;

                // 문자 간 대기 (40us) 및 인덱스 증가
                if (delay_cnt < 20'd2_000) begin
                    delay_cnt <= delay_cnt + 1;
                end else begin
                    delay_cnt <= 0;
                    if (msg_index == 6'd32) lcd_state <= L_READY; // 모두 전송 완료
                    else msg_index <= msg_index + 1;
                end
            end
        endcase
    end
end

endmodule