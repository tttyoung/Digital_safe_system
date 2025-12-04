module timer(
    input wire clk,          
    input wire rst_n,        
    
    input wire clk_1hz,  //타이머용 1hz 클럭    
    input wire run_timer,    //1: 시간감소 시작
    input wire reset_timer,  //1: 타이머 다시 1분으로 리셋시키기
    
    // 0이면 1분 모드, 1이면 5분 모드
    input wire timer_mode_5min, 
    
    output reg [5:0] curr_min, 
    output reg [5:0] curr_sec, 
    output reg time_out    //시간 종료    
);

    reg clk_1hz_prev;
    wire tick_1s;
    assign tick_1s = (clk_1hz == 1'b1) && (clk_1hz_prev == 1'b0);

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) clk_1hz_prev <= 0;
        else       clk_1hz_prev <= clk_1hz;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            curr_min <= 1; curr_sec <= 0; // 기본 1분
            time_out <= 0;
        end 
        else begin
            if (reset_timer) begin
                time_out <= 0;
                curr_sec <= 0;
                
                if (timer_mode_5min == 1'b1) 
                    curr_min <= 5; // 점검 모드면 5분
                else 
                    curr_min <= 1; // 평소에는 1분
            end 
            
            else if (run_timer && !time_out && tick_1s) begin
                if (curr_sec == 0) begin
                    if (curr_min == 0) begin
                        time_out <= 1; 
                    end else begin
                        curr_min <= curr_min - 1;
                        curr_sec <= 59;
                    end
                end else begin
                    curr_sec <= curr_sec - 1;
                end
            end
        end
    end

endmodule