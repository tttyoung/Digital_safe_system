module cal_result(
    // 난수 입력 (4자리)
    input wire [3:0] d1, // 천의 자리 (제일 왼쪽)
    input wire [3:0] d2,
    input wire [3:0] d3,
    input wire [3:0] d4, // 일의 자리 (제일 오른쪽)

    // 연산자 입력 (관리자 모드에서 올 신호 -> 지금은 임의로 넣을 예정)
    input wire op1, //0이면 +, 1이면 *
    input wire op2, 
    input wire op3, 

    output reg [15:0] correct_ans // 최대 9*9*9*9=6561 이므로 16비트면 충분
);

    // 중간 계산 과정을 저장할 변수들
    reg [15:0] step1_res; // (d1 op1 d2) 결과
    reg [15:0] step2_res; // (step1 op2 d3) 결과

    always @(*) begin
        // 1단계: d1과 d2 연산 
        if (op1 == 1'b0) step1_res = d1 + d2;      // 덧셈
        else             step1_res = d1 * d2;      // 곱셈

        // 2단계: 1단계 결과와 d3 연산 
        if (op2 == 1'b0) step2_res = step1_res + d3;
        else             step2_res = step1_res * d3;

        // 3단계: 2단계 결과와 d4 연산 
        if (op3 == 1'b0) correct_ans = step2_res + d4;
        else             correct_ans = step2_res * d4;
    end

endmodule
