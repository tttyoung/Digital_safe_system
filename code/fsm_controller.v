module fsm_controller (
    input wire clk,             // 50MHz 클럭
    input wire rst,             // 시스템 리셋 신호
    input wire clk_1hz,         // 1초 단위 카운트용 클럭
    
    // 입력 장치로부터의 신호
    input wire btn_input_done,  // '#' 버튼 입력 펄스
    input wire [15:0] user_input_data, // 사용자가 키패드로 입력한 4자리 숫자
    input wire [15:0] correct_code_digital, // 난수 정답 (계산 완료된 값)
    input wire [7:0] dial_current_val, // 현재 다이얼 값 (0~255)
    
    input wire sw_admin_mode,   // 관리자 모드 스위치
    
    input wire [7:0] sram_data_in, // SRAM에서 읽어온 데이터
    
    output reg timer_run,        // 타이머 작동 시작 관련 출력
    output reg timer_reset,      // 타이머 시간 초기화
    output reg timer_mode_5min,  // 타이머 5분 모드 여부
    input wire timer_time_out,   // 타이머 초과 신호 (상태를 변경하기 위해 필요)
    
    // 시스템 상태 및 결과 출력
    output reg [3:0] current_state, // 현재 상태
    output reg [3:0] chance_count,  // 남은 기회 횟수
    
    // SRAM 제어 인터페이스
    output reg sram_we_n,       // 쓰기 제어 신호 (0일 때 쓰고, 1일 때 읽음)
    output reg [7:0] sram_addr, // 접근할 SRAM 주소
    output reg [7:0] sram_data_out, // SRAM에 기록할 데이터

    output reg op1,             // 복구된 연산자 1 (0:+, 1:*)
    output reg op2,             // 복구된 연산자 2
    output reg op3              // 복구된 연산자 3
);

    // 상태 정의 (총 12개 상태)
    localparam S_INIT           = 4'b0000; // 초기화
    localparam S_IDLE           = 4'b0001; // 대기 상태
    localparam S_MAKE_NUM       = 4'b0010; // 난수 생성 
    localparam S_INPUT_CAL      = 4'b0011; // 비밀번호 입력 중 (타이머 동작)
    localparam S_CHECK_1        = 4'b0100; // 비밀번호 검증
    localparam S_INPUT_DIAL     = 4'b0101; // 다이얼 값 조절
    localparam S_CHECK_2        = 4'b0110; // 다이얼 값 검증
    localparam S_UNLOCK         = 4'b0111; // 잠금 해제 성공
    localparam S_FAIL_ATTEMPT   = 4'b1000; // 단일 실패 (3초간 대기 패널티)
    localparam S_DEACTIVATE     = 4'b1001; // 3회 실패 시 비활성화 (1분간)
    localparam S_EMERGENCY      = 4'b1010; // 비상 모드 (5분간)
    localparam S_ADMIN          = 4'b1011; // 관리자 모드 (설정값 변경)

    // 비상 모드 진입 코드 정의
    localparam EMERGENCY_CODE   = 16'h0119; 

    // 2. 내부 레지스터 및 변수 선언
    reg [3:0] next_state;       // 다음 클럭에 넘어갈 상태를 저장
    reg [7:0] dial_target_val;  // 다이얼 정답 값 (SRAM에서 읽거나 관리자가 설정)
    reg [1:0] fail_delay_cnt;   // 실패 시 3초 딜레이를 세기 위한 카운터
    
    // 시퀀스 제어용 카운터
    reg [1:0] admin_step;       // 관리자 입력 단계 (0:Op1 -> 1:Op2 -> 2:Op3 -> 3:Dial)
    reg [1:0] init_step;        // 초기화 읽기 단계
    reg init_done;              // 초기화가 완료되었음을 알리는 플래그

    // 3. 비교기 및 감지 로직
    
    // 디지털 정답 비교기
    // 사용자가 입력한 값과 계산된 정답이 같은지 확인
    wire is_digital_correct = (user_input_data == correct_code_digital);
    
    // 다이얼 정답 비교기
    // 오차범위(+-5)를 허용하여 정답으로 인정
    wire is_dial_correct = (dial_current_val >= (dial_target_val - 8'd5)) && 
                           (dial_current_val <= (dial_target_val + 8'd5));
    
    // 1Hz 클럭 엣지 감지기
    // 3초 딜레이를 셀 때, 1Hz 클럭이 High인 동안 계속 카운트가 올라가는 것을 방지
    // 0에서 1로 변하는 그 순간만 딱 한 번 감지함
    reg clk_1hz_prev;
    always @(posedge clk) clk_1hz_prev <= clk_1hz;
    wire tick_1hz = clk_1hz && !clk_1hz_prev; // 상승 엣지에서만 1

    // 메인 순차 회로
    // 클럭에 맞춰 상태를 변경하고 데이터를 저장하는 로직
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 리셋 시 초기화
            current_state <= S_INIT;
            chance_count <= 4'd3;
            fail_delay_cnt <= 0;
            dial_target_val <= 8'd123; // 다이얼 기본값 (SRAM 읽기 전)
            op1 <= 0; op2 <= 0; op3 <= 0; // 연산자 초기화
            sram_we_n <= 1; sram_addr <= 0; sram_data_out <= 0;
            admin_step <= 0; init_step <= 0; init_done <= 0;
        end else begin
            // 다음 상태로 이동
            current_state <= next_state;

            // 초기화: 전원 켜지면 SRAM에서 설정값 불러오기
            if (current_state == S_INIT) begin
                sram_we_n <= 1; // 읽기 모드 
                
                // 순차적으로 주소를 변경하며 데이터 읽기
                case (init_step)
                    0: begin sram_addr <= 0; init_step <= 1; end
                    1: begin 
                        op1 <= sram_data_in[0]; // 0번지 데이터 -> 연산자 1로 복구
                        sram_addr <= 1; init_step <= 2; 
                    end
                    2: begin 
                        op2 <= sram_data_in[0]; // 1번지 데이터 -> 연산자 2로 복구
                        sram_addr <= 2; init_step <= 3; 
                    end
                    3: begin 
                        op3 <= sram_data_in[0]; // 2번지 데이터 -> 연산자 3으로 복구
                        sram_addr <= 3; init_step <= 0; init_done <= 1; 
                    end
                endcase
                
                // 다이얼 값은 IDLE로 넘어가기 직전에 저장
                if (init_done) dial_target_val <= sram_data_in;
            end

            // 관리자: 설정값을 입력받아 SRAM에 저장하기
            else if (current_state == S_ADMIN) begin
                sram_we_n <= 1; // 평소에는 읽기 모드
                
                // 확인 버튼(#)을 누르면 현재 입력된 값을 저장
                if (btn_input_done) begin
                    sram_we_n <= 0; // 쓰기 펄스 발생 (Active Low)
                    
                    case (admin_step)
                        0: begin // 1단계: 연산자 1 저장
                            sram_addr <= 0; 
                            sram_data_out <= {7'b0, user_input_data[0]}; // 입력값의 끝자리만 사용
                            op1 <= user_input_data[0]; // 내부 변수도 갱신
                            admin_step <= 1;
                        end
                        1: begin // 2단계: 연산자 2 저장
                            sram_addr <= 1; 
                            sram_data_out <= {7'b0, user_input_data[0]}; 
                            op2 <= user_input_data[0]; 
                            admin_step <= 2;
                        end
                        2: begin // 3단계: 연산자 3 저장
                            sram_addr <= 2; 
                            sram_data_out <= {7'b0, user_input_data[0]}; 
                            op3 <= user_input_data[0]; 
                            admin_step <= 3;
                        end
                        3: begin // 4단계: 현재 다이얼 값 저장
                            sram_addr <= 3; 
                            sram_data_out <= dial_current_val; // 현재 돌려놓은 다이얼 값 저장
                            dial_target_val <= dial_current_val; 
                            admin_step <= 0; // 처음으로 돌아감
                        end
                    endcase
                end
            end 
            
            // 남은 기회 관리
            // 대기 상태로 돌아오면 기회 3번으로 리셋
            if (current_state == S_IDLE) chance_count <= 4'd3;
            
            // 검증 단계(Check)에서 다음 상태가 실패(Fail)라면 기회 1회 차감
            if (current_state == S_CHECK_1 || current_state == S_CHECK_2) begin
                 if (next_state == S_FAIL_ATTEMPT && chance_count > 0) 
                     chance_count <= chance_count - 1;
            end
           
            // 3초 딜레이 카운터 (실패 시)
            if (current_state == S_FAIL_ATTEMPT) begin
                 // 1초마다 펄스가 튀면(tick_1hz) 카운터 증가
                 if (tick_1hz) fail_delay_cnt <= fail_delay_cnt + 1; 
            end else begin
                fail_delay_cnt <= 0; // 다른 상태에서는 0으로 초기화
            end
            
            // IDLE 상태로 가면 관리자 스텝 초기화
            if (current_state == S_IDLE) admin_step <= 0;
        end
    end

    // 5. 다음 상태 결정 로직
    // 설명: 현재 상태와 입력 조건에 따라 다음 상태를 결정
    always @(*) begin
        // 기본값 설정
        next_state = current_state;
        timer_run = 0; timer_reset = 0; timer_mode_5min = 0;

        case (current_state)
            // 초기화: 완료되면 IDLE로 이동
            S_INIT: if (init_done) next_state = S_IDLE;
            
            // 대기 상태
            S_IDLE: begin
                // 비상 스위치 제거됨. 관리자 스위치 확인
                if (sw_admin_mode) next_state = S_ADMIN;
                // '#' 버튼 누르면 게임 시작
                else if (btn_input_done) next_state = S_MAKE_NUM; 
            end
            
            // 관리자 모드: 스위치 내리면 종료
            S_ADMIN: if (!sw_admin_mode) next_state = S_IDLE;
            
            // 난수 생성: 1클럭만 머물고 이동 (Top에서 이 때 값을 캡처함)
            S_MAKE_NUM: begin next_state = S_INPUT_CAL; timer_reset = 1; end
            
            // 디지털 값 입력 중
            S_INPUT_CAL: begin 
                timer_run = 1; // 1분 타이머 작동
                if (timer_time_out) next_state = S_FAIL_ATTEMPT; // 시간 초과 -> 실패
                else if (btn_input_done) next_state = S_CHECK_1; // 입력 완료 -> 검증
            end
            
            // 디지털 값 검증 (비상 코드 119 확인 포함)
            S_CHECK_1: begin
                // [중요] 사용자가 '119'를 입력했는지 먼저 확인 (비상 모드 진입)
                if (user_input_data == EMERGENCY_CODE) begin
                    next_state = S_EMERGENCY;
                    timer_reset = 1; // 5분 타이머 준비
                end
                // 정답이면 다이얼 입력 단계로
                else if (is_digital_correct) begin 
                    next_state = S_INPUT_DIAL; 
                    timer_reset = 1; 
                end
                // 틀리면 실패 처리
                else begin
                    next_state = S_FAIL_ATTEMPT;
                end
            end
            
            // 다이얼 돌리는 중
            S_INPUT_DIAL: begin
                timer_run = 1; // 1분 타이머 작동
                if (timer_time_out) next_state = S_FAIL_ATTEMPT;
                else if (btn_input_done) next_state = S_CHECK_2; // 확인 버튼 -> 검증
            end
            
            // 다이얼 값 검증
            S_CHECK_2: begin
                if (is_dial_correct) next_state = S_UNLOCK; // 정답 -> 문 열림
                else next_state = S_FAIL_ATTEMPT; // 오답 -> 실패
            end
            
            // 문 열림: 버튼 누르면 잠금(IDLE)
            S_UNLOCK: if (btn_input_done) next_state = S_IDLE;
            
            // 실패 처리 (3초 대기)
            S_FAIL_ATTEMPT: begin
                // 기회가 0번이면 비활성화(벽돌) 상태로
                if (chance_count == 0) begin 
                    next_state = S_DEACTIVATE; 
                    timer_reset = 1; 
                end
                // 기회가 남았고, 3초가 지났으면 재시도
                else if (fail_delay_cnt >= 2'd3) begin 
                    next_state = S_INPUT_CAL; 
                    timer_reset = 1; 
                end
            end
            
            // 비활성화 (1분간 대기)
            S_DEACTIVATE: begin 
                timer_run = 1; 
                if (timer_time_out) next_state = S_IDLE; // 1분 지나면 복귀
            end
            
            // 비상 모드 (5분간 대기)
            S_EMERGENCY: begin 
                timer_run = 1; 
                timer_mode_5min = 1; // 5분 모드로 설정
                // 5분 지나야 복귀함
                if (timer_time_out) next_state = S_IDLE; 
            end
            
            default: next_state = S_INIT;
        endcase
    end
endmodule