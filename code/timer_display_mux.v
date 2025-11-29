module timer_display_mux(
    input clk_mux, 
    input rst,
    input [3:0] state, // 상태값 input
    input [3:0] chance_count, // 남은 기회 input
    input [15:0] input_data,  // 8 cell 7세그먼트를 위한 input
    input [5:0] timer_min,
    input [5:0] timer_sec,
    
    output reg [7:0] seg_cathode, // 패턴 데이터(실제 숫자 데이터) 관련 output
    output reg [7:0] seg_anode,   // 자리선택 관련 output 
    output reg [2:0] chance_led   // 남은 기회 led 출력
);

localparam INPUT_CAL = 4'b0011;
localparam DEACTIVATE = 4'b1001;
localparam EMERGENCY = 4'b1010;

// input으로 들어온 시간 데이터를 이진화 십진 코드(BCD)로 변환
wire [3:0] S0, S1, M0, M1;

// Time to BCD
assign S0 = timer_sec % 10;
assign S1 = timer_sec / 10;
assign M0 = timer_min % 10;
assign M1 = timer_min / 10;

// BCD를 7세그먼트 출력으로 변환하는 함수
// input: bcd
// output: 7세그먼트 출력
function [6:0] bcd_to_7seg;
    input [3:0] bcd;
    begin 
        case(bcd)
            4'd0: bcd_to_7seg = 7'b1111110;
            4'd1: bcd_to_7seg = 7'b0110000;
            4'd2: bcd_to_7seg = 7'b1101101;
            4'd3: bcd_to_7seg = 7'b1111001;
            4'd4: bcd_to_7seg = 7'b0110011;
            4'd5: bcd_to_7seg = 7'b1011011;
            4'd6: bcd_to_7seg = 7'b1011111;
            4'd7: bcd_to_7seg = 7'b1110000;
            4'd8: bcd_to_7seg = 7'b1111111;
            4'd9: bcd_to_7seg = 7'b1110011;
            default: bcd_to_7seg = 7'b1111111; // blank
        endcase
     end
endfunction

// 자릿수 표시를 위한 cell_mux
reg [2:0] current_cell_mux;
always @(posedge clk_mux or posedge rst) begin
    if(rst)
        current_cell_mux <= 3'd0;
    else 
        current_cell_mux <= current_cell_mux + 1'b1;
end
    
reg [6:0] segment_data; // 실제 seg data(분/초 데이터)가 들어갈 변수
reg dp_on; // dp(분/초 구분점) 제어 임시 변수 

// 8cell 7세그먼트 출력
always @(*) begin
    // default: blank
    seg_anode = 8'hff;
    
    dp_on = 1'b1; // dp(분/초 구분점) 제어 임시 변수 
    segment_data = 7'b1111111;
    
    // timer output
    if(state == DEACTIVATE || state == EMERGENCY || state == INPUT_CAL) begin
        
        case(current_cell_mux)
            // DISPLAY: M1 M0 ; S1 S0 ( 6 )
            3'd7: begin seg_anode = 8'h7F; segment_data = bcd_to_7seg(S0);dp_on = 1'b1; end // 8번 CELL에 초(일의 자리) 출력
            3'd6: begin seg_anode = 8'hBF; segment_data = bcd_to_7seg(S1);dp_on = 1'b1; end // 7번 CELL에 초(십의 자리) 출력
            3'd5: begin seg_anode = 8'hDF; segment_data = bcd_to_7seg(M0);dp_on = 1'b0; end // 6번 CELL에 분(일의 자리) 출력
            3'd4: begin seg_anode = 8'hEF; segment_data = bcd_to_7seg(M1);dp_on = 1'b1; end // 5번 CELL에 분(십의 자리) 출력
            default: seg_anode = 8'hff;
       endcase
    end
    
    // seg data와 dp(분/초 구분점) 결합
    seg_cathode = {dp_on, segment_data};
end

// 남은 기회 led 출력 로직
always @(*) begin
    case(chance_count)
        3: chance_led = 3'b111; // 남은 기회 3번
        2: chance_led = 3'b110; // 남은 기회 2번
        1: chance_led = 3'b100; // 남은 기회 1번
        0: chance_led = 3'b000; // 남은 기회 0번
        default: chance_led = 3'b000;
    endcase
end

endmodule 
        
 
    