module layer1_safe(
input clk,
input reset_n,
input waitrequest,
input readdatavalid,
input [15:0] readdata,

output chipselect,
output [1:0] byteenable,
output reg read_n,
output reg write_n,

output reg [15:0] writedata,
output reg [31:0] address,

input ready,
output reg done,
output [31:0] toHexLed
);
	reg [31:0] Adr_Img = 600_000;
	reg [31:0] Adr_L1 = 650_000;
	reg [31:0] Adr_W1 = 800;
	
   reg [15:0] Data_Img = 16'hABCD;
	reg signed [15:0] Data_W1 = 16'h0000;
	reg signed [15:0] Total = 16'h0000;
	
	reg [7:0] state;
	reg [7:0] nextstate = 0;
	
	reg [15:0] Img_Count = 1;
	reg [15:0] W1_Count = 1;
	reg [15:0] Node_Count = 1;

	reg [3:0] cycles = 0;
	
	localparam IDLE = 0;
	localparam READ_IMG = 1;
	localparam WAIT_IMG = 2;
	localparam ADD = 3;
	localparam WRITE_TO_L1 = 4;
	localparam CONT_IMG = 5;
	localparam DONE = 6;
	localparam READ_W1 = 7;
	localparam WAIT_W1 = 8;
	localparam CONT_W1 = 9;
	localparam CONT_L1 = 10;
	localparam STORE_IMG = 11;
	localparam DELAY = 12;
	
	localparam Base_Img = 32'd600_000;
	localparam Base_Layer1 = 32'd400_000;
	localparam Base_W1 = 32'd800;

	assign toHexLed = {Node_Count,Data_Img,state};

	assign chipselect = 1;
	assign byteenable = 2'b11;
	
	always @ (posedge clk)
	begin
		state <= nextstate;
		if(reset_n == 0)
		begin
			state <= IDLE;
		end
	end

	always @ (posedge clk)
	begin
		case(state)
			IDLE:
			begin
				W1_Count <= 1;
				Node_Count <= 1;
				Adr_Img <= Base_Img;
				Adr_L1 <= Base_Layer1;
				Adr_W1 <= Base_W1;
				Total <= 0;
			end

//--------------- State Machine for TD -----------------------//
			
			READ_IMG: // Read TD request
			begin

			end

			WAIT_IMG: // Wait TD request
			begin
				Data_Img <= (readdatavalid) ? readdata : Data_Img;
				Adr_Img <= (readdatavalid) ? Adr_Img + 2 : Adr_Img;
			end
			
/*			
			STORE_IMG: // Store into Image register
			begin
				Image[Img_Count-1] <= (Data_Img == 0) ? 0: 1;
			end
			
			CONT_IMG: // Increase until 784
			begin
				Img_Count <= Img_Count + 1;
			end
*/
// -------------------- State Machine for W1 -------------------------------/

			//CHECK: begin if (Image[W1_Count-1] == 1) nextstate <= READ_W1: CONT_W1:end
			
			READ_W1: //waitrequest w1
			begin
				
			end
			
			WAIT_W1: //readdatavalid w1
			begin
				Data_W1 <= (readdatavalid) ? readdata : Data_W1;
				Adr_W1 <= (readdatavalid) ? Adr_W1 + 2 : Adr_W1;
			end
			
			ADD: //add using our img register
			begin
				//Total <= (Image[W1_Count-1] == 1) ? Total + Data_W1 : Total;
				Total <= (Data_Img != 0) ? Total + Data_W1 : Total;
			end
			
			CONT_W1: //keep reading from w1 til 784
			begin
				W1_Count <= W1_Count + 1;
			end
			
			WRITE_TO_L1: //once w1 count == 784, write to layer1
			begin
				Adr_L1 <= (!waitrequest) ? Adr_L1 + 2: Adr_L1;
			end

			CONT_L1: //reset count,total and read from img again
			begin
				W1_Count <= 0;
				Total <= 0;
				Adr_Img <= Base_Img;
				Node_Count <= Node_Count + 1;
			end

			DONE:
			begin
			end
		endcase
	end

	always @ (*)
	begin
		//read_n <= read_n;
		//write_n <= write_n;
		//address <= address;

		case(state)
			IDLE: 
			begin
				read_n <= 1;
				write_n <= 1;
				address <= address;
				nextstate <= (ready) ? READ_IMG : IDLE;
			end

//-------------------- State Logic TD --------------------------//
			READ_IMG:
			begin
				read_n <= 0;
				write_n <= 1;
				address <= Adr_Img;
				nextstate <= (!waitrequest) ? WAIT_IMG : READ_IMG;
			end

			WAIT_IMG:
			begin
				nextstate <= (readdatavalid) ? READ_W1 : WAIT_IMG;
			end
			
			// STORE_IMG: begin nextstate <= CONT_IMG; end

			// CONT_IMG: begin nextstate <= (Img_Count < 784) ? READ_IMG : READ_W1; end

////------------ State Logic Weight 1 -----------------//
			
			READ_W1:
			begin
				read_n <= 0;
				write_n <= 1;
				address <= Adr_W1;
				nextstate <= (!waitrequest) ? WAIT_W1 : READ_W1;
			end
			
			WAIT_W1:
			begin
				nextstate <= (readdatavalid) ? ADD : WAIT_W1;
			end
			
			ADD:
			begin
				nextstate <= CONT_W1;
			end
			
			//DELAY:begin nextstate <= (cycles == 5) ? CONT_W1 : DELAY; end
			
			CONT_W1:
			begin
				nextstate <= (W1_Count < 784) ? READ_IMG : WRITE_TO_L1;
			end

//-------------------- Layer 1 Logic ----------------------------//
			WRITE_TO_L1:
			begin
				write_n <= 0;
				read_n <= 1;
				address <= Adr_L1;
				writedata <= Total;
				nextstate <= (!waitrequest) ? CONT_L1: WRITE_TO_L1;
			end

			CONT_L1:
			begin
				nextstate <= (Node_Count < 200) ? READ_IMG : DONE;
			end

			DONE:
			begin
				done <= (ready) ? 1 : 0;
				nextstate <= (!ready) ? IDLE : DONE;
			end
		endcase
	end

	
/*	
always@(posedge clk)
begin
	if(state == DELAY)
	begin
		cycles <= (cycles < 5) ? cycles + 1 : 0;
	end
	else begin
		cycles <= cycles;
	end
end
*/


endmodule

/*

module layer1_safe(
input clk,
input reset_n,
input waitrequest,
input readdatavalid,
input [15:0] readdata,

output chipselect,
output [1:0] byteenable,
output reg read_n,
output reg write_n,

output reg [15:0] writedata,
output reg [31:0] address,

input ready,
output reg done,
output [31:0] toHexLed
);
	reg [31:0] Adr_Img = 600_000;
	reg [31:0] Adr_L1 = 650_000;
	reg [31:0] Adr_W1 = 800;
	
   reg [15:0] Data_Img = 16'hABCD;
	reg signed [15:0] Data_W1 = 16'h0000;
	reg signed [15:0] Total = 16'h0000;
	
	reg [7:0] state;
	reg [7:0] nextstate = 0;
	
	reg [15:0] Img_Count = 1;
	reg [15:0] W1_Count = 1;
	reg [15:0] Node_Count = 1;

	reg [3:0] cycles = 0;
	
	localparam IDLE = 0;
	localparam READ_IMG = 1;
	localparam WAIT_IMG = 2;
	localparam ADD = 3;
	localparam WRITE_TO_L1 = 4;
	localparam CONT_IMG = 5;
	localparam DONE = 6;
	localparam READ_W1 = 7;
	localparam WAIT_W1 = 8;
	localparam CONT_W1 = 9;
	localparam CONT_L1 = 10;
	localparam STORE_IMG = 11;
	localparam DELAY = 12;
	
	localparam Base_Img = 32'd600_000;
	localparam Base_Layer1 = 32'd400_000;
	localparam Base_W1 = 32'd800;

	assign toHexLed = {Total,Node_Count,state};

	assign chipselect = 1;
	assign byteenable = 2'b11;
	
	always @ (posedge clk)
	begin
		state <= nextstate;
		if(reset_n == 0)
		begin
			state <= IDLE;
		end
	end

	always @ (posedge clk)
	begin
		case(state)
			IDLE:
			begin
				W1_Count <= 1;
				Node_Count <= 1;
				Adr_Img <= Base_Img;
				Adr_L1 <= Base_Layer1;
				Adr_W1 <= Base_W1;
				Total <= 0;
			end

//--------------- State Machine for TD -----------------------//
			
			READ_IMG: // Read TD request
			begin

			end

			WAIT_IMG: // Wait TD request
			begin
				Data_Img <= (readdatavalid) ? readdata : Data_Img;
				Adr_Img <= (readdatavalid) ? Adr_Img + 2 : Adr_Img;
			end
			
			
			/*STORE_IMG: // Store into Image register begin Image[Img_Count-1] <= (Data_Img == 0) ? 0: 1;end
			
			//CONT_IMG: // Increase until 784	beginImg_Count <= Img_Count + 1;end

// -------------------- State Machine for W1 -------------------------------

			//CHECK: begin if (Image[W1_Count-1] == 1) nextstate <= READ_W1: CONT_W1:end
			
			READ_W1: //waitrequest w1
			begin
				
			end
			
			WAIT_W1: //readdatavalid w1
			begin
				Data_W1 <= (readdatavalid) ? readdata : Data_W1;
				Adr_W1 <= (readdatavalid) ? Adr_W1 + 2 : Adr_W1;
			end
			
			ADD: //add using our img register
			begin
				//Total <= (Image[W1_Count-1] == 1) ? Total + Data_W1 : Total;
				Total <= (Data_Img != 0) ? Total + Data_W1 : Total;
			end
			
			CONT_W1: //keep reading from w1 til 784
			begin
				W1_Count <= W1_Count + 1;
			end
			
			WRITE_TO_L1: //once w1 count == 784, write to layer1
			begin
				Adr_L1 <= (!waitrequest) ? Adr_L1 + 2: Adr_L1;
			end

			CONT_L1: //reset count,total and read from img again
			begin
				W1_Count <= 0;
				Total <= 0;
				Adr_Img <= Base_Img;
				Node_Count <= Node_Count + 1;
			end

			DONE:
			begin
			end
		endcase
	end

	always @ (*)
	begin
		//read_n <= read_n;
		//write_n <= write_n;
		//address <= address;

		case(state)
			IDLE: 
			begin
				read_n <= 1;
				write_n <= 1;
				address <= address;
				nextstate <= (ready) ? READ_IMG : IDLE;
			end

//-------------------- State Logic TD --------------------------//
			READ_IMG:
			begin
				read_n <= 0;
				write_n <= 1;
				address <= Adr_Img;
				nextstate <= (!waitrequest) ? WAIT_IMG : READ_IMG;
			end

			WAIT_IMG:
			begin
				nextstate <= (readdatavalid) ? READ_W1 : WAIT_IMG;
			end
			
			// STORE_IMG: begin nextstate <= CONT_IMG; end

			// CONT_IMG: begin nextstate <= (Img_Count < 784) ? READ_IMG : READ_W1; end

////------------ State Logic Weight 1 -----------------//
			
			READ_W1:
			begin
				read_n <= 0;
				write_n <= 1;
				address <= Adr_W1;
				nextstate <= (!waitrequest) ? WAIT_W1 : READ_W1;
			end
			
			WAIT_W1:
			begin
				nextstate <= (readdatavalid) ? ADD : WAIT_W1;
			end
			
			ADD:
			begin
				nextstate <= CONT_W1;
			end
			
			//DELAY:begin nextstate <= (cycles == 5) ? CONT_W1 : DELAY; end
			
			CONT_W1:
			begin
				nextstate <= (W1_Count < 784) ? READ_IMG : WRITE_TO_L1;
			end

//-------------------- Layer 1 Logic ----------------------------//
			WRITE_TO_L1:
			begin
				write_n <= 0;
				read_n <= 1;
				address <= Adr_L1;
				writedata <= Total;
				nextstate <= (!waitrequest) ? CONT_L1: WRITE_TO_L1;
			end

			CONT_L1:
			begin
				nextstate <= (Node_Count < 200) ? READ_IMG : DONE;
			end

			DONE:
			begin
				done <= (ready) ? 1 : 0;
				nextstate <= (!ready) ? IDLE : DONE;
			end
		endcase
	end


endmodule
*/