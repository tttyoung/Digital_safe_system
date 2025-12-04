module clock_divider(
    input clk,           // 보드 기본 클럭 (50MHz)
    input rst_n,
    output reg clk_1khz, // 7-세그먼트 스캔용 (1kHz)
    output reg clk_1hz,  // 타이머 카운트용 (1Hz)
    output reg clk_500khz // ADC 제어용 클럭 (500kHz)
);
    
    integer cnt_1k = 0;
    integer cnt_1h = 0;
    integer cnt_500k = 0; 

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_1k <= 0;   clk_1khz <= 0;
            cnt_1h <= 0;   clk_1hz <= 0;
            cnt_500k <= 0; clk_500khz <= 0; 
        end else begin
            // 1kHz 생성
            if(cnt_1k >= 24999) begin
                cnt_1k <= 0;
                clk_1khz <= ~clk_1khz;
            end else cnt_1k <= cnt_1k + 1;

            // 1Hz 생성
            if(cnt_1h >= 24999999) begin
                cnt_1h <= 0;
                clk_1hz <= ~clk_1hz;
            end else cnt_1h <= cnt_1h + 1;

            // 500kHz 생성 (ADC용)
            if(cnt_500k >= 49) begin 
                cnt_500k <= 0;
                clk_500khz <= ~clk_500khz;
            end else cnt_500k <= cnt_500k + 1;
        end
    end
endmodule
