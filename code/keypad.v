module keypad(
    input wire clk,          
    input wire rst_n,        
    
    // 0~9번 핀: 숫자 0~9
    // 10번 핀: * (별)
    // 11번 핀: # (샵)
    input wire [11:0] btn_in, //눌린숫자만 0   ex) 0번만 누르면 -> 111111111110
    
    output reg [3:0] key_value, // 눌린 숫자 (0~15)
    output reg key_valid        // 눌림 신호 (1 pulse)
);

    // 버튼 상태 저장을 위한 레지스터
    reg [11:0] btn_prev;
    
    // 12개 버튼 중 하나라도 눌렸는지 확인
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            btn_prev <= 12'hFFF; // 모두 안 눌린 상태(1)로 초기화 (초기값: 111111111111)
            key_valid <= 0;
            key_value <= 0;
        end else begin
            btn_prev <= btn_in; // 이전 상태 업데이트(현재 클럭 끝나면)
            if (btn_prev != btn_in) begin              
                key_valid <= 1; // 눌림신호 켜짐
                // 어떤 버튼인지 찾기 (우선순위: 0번부터 확인)
                if      (btn_prev[0] && !btn_in[0])  key_value <= 4'd0; // 0번 버튼
                else if (btn_prev[1] && !btn_in[1])  key_value <= 4'd1; // 1번 버튼
                else if (btn_prev[2] && !btn_in[2])  key_value <= 4'd2; // 2번 버튼
                else if (btn_prev[3] && !btn_in[3])  key_value <= 4'd3; // 3번 버튼
                else if (btn_prev[4] && !btn_in[4])  key_value <= 4'd4; // 4번 버튼
                else if (btn_prev[5] && !btn_in[5])  key_value <= 4'd5; // 5번 버튼
                else if (btn_prev[6] && !btn_in[6])  key_value <= 4'd6; // 6번 버튼
                else if (btn_prev[7] && !btn_in[7])  key_value <= 4'd7; // 7번 버튼
                else if (btn_prev[8] && !btn_in[8])  key_value <= 4'd8; // 8번 버튼
                else if (btn_prev[9] && !btn_in[9])  key_value <= 4'd9; // 9번 버튼
                else if (btn_prev[10] && !btn_in[10]) key_value <= 4'd14; // * (10번 핀)
                else if (btn_prev[11] && !btn_in[11]) key_value <= 4'd15; // # (11번 핀)
                else begin
                    // 눌린 게 아니라 떼진 경우(0->1) 등은 무시
                    key_valid <= 0; 
                end

            end else begin
                key_valid <= 0; // 아무 변화 없음
            end
        end
    end

endmodule