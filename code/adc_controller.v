module adc_controller(
    input wire clk_500khz,   
    input wire rst_n,
    
    output wire adc_clk,     
    output reg adc_start,  // adc변환시작여부  
    output reg adc_ale,    // adc_addr에 실려있는 채널번호 래치해주는 신호
    output reg adc_oe,     // 변환 결과를 보낼지말지 
    output reg [2:0] adc_addr, // adc채널
    input wire adc_eoc,  //변환 다 되었는지    
    input wire [7:0] adc_data_in,  //변환결과 8비트 데이터
        
    // FSM 결과값
    output reg [7:0] dial_value // 최종 결과(dial의 현재 값)
);

    assign adc_clk = clk_500khz;

    // 2. 일 시키는 순서 (State Machine)
    reg [2:0] state;
    reg [7:0] wait_cnt; 

    localparam S_IDLE  = 0; // 준비단계
    localparam S_START = 1; // 명령시작
    localparam S_WAIT  = 2; // wait
    localparam S_READ  = 3; // 결과 읽기

    // FSM도 500kHz 박자에 맞춰서 동작
    always @(posedge clk_500khz or negedge rst_n) begin
        if(!rst_n) begin
            state <= S_IDLE;
            adc_start <= 0; adc_ale <= 0; adc_oe <= 0;
            adc_addr <= 0; dial_value <= 0;
            wait_cnt <= 0;
        end else begin
            case(state)
                S_IDLE: begin //모든 신호 초기화
                    adc_start <= 0; adc_ale <= 0; adc_oe <= 0;
                    state <= S_START;
                end
                
                S_START: begin
                    adc_addr <= 3'b000; // 0번 채널 (가변저항)
                    adc_ale <= 1;       // 주소 래치
                    adc_start <= 1;     // 시작 신호
                    state <= S_WAIT;
                    wait_cnt <= 0;
                end
                
                S_WAIT: begin
                    adc_ale <= 0;
                    adc_start <= 0;
                    
                    if(adc_eoc == 1 || wait_cnt > 60) begin 
                        state <= S_READ;
                    end else begin
                        wait_cnt <= wait_cnt + 1;
                    end
                end
                
                S_READ: begin
                    adc_oe <= 1; // 출력 활성화
                    dial_value <= adc_data_in; // 데이터 읽기
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule