module clock_divider(
    input clk,          // 보드 기본 클럭 (보통 50MHz)
    input rst_n,
    output reg clk_1khz, // 7-세그먼트 스캔용 (빠르게 깜빡임)
    output reg clk_1hz   // 타이머 카운트용 (1초)
);
    // 50MHz = 50,000,000Hz
    // 1kHz를 만들려면 50,000분주 -> 25,000마다 토글
    // 1Hz를 만들려면 50,000,000분주 -> 25,000,000마다 토글
    
    integer cnt_1k = 0;
    integer cnt_1h = 0;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_1k <= 0; clk_1khz <= 0;
            cnt_1h <= 0; clk_1hz <= 0;
        end else begin
            // 1kHz 생성
            if(cnt_1k >= 24999) begin // 50,000 / 2 - 1
                cnt_1k <= 0;
                clk_1khz <= ~clk_1khz;
            end else cnt_1k <= cnt_1k + 1;

            // 1Hz 생성
            if(cnt_1h >= 24999999) begin // 50,000,000 / 2 - 1
                cnt_1h <= 0;
                clk_1hz <= ~clk_1hz;
            end else cnt_1h <= cnt_1h + 1;
        end
    end
endmodule