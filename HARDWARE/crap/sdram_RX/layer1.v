module layer1(
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
	assign chipselect = 1;  
	assign byteenable = 2'b11;
	
	reg [15:0] img_cur = 16'h0;
	reg [15:0] w1_cur = 16'h0;
	reg [15:0] total = 16'h0;
	reg [3:0]  state = 0;
	reg [3:0]  nextstate = 0;
	reg [31:0] img_adr = 32'd600_000; 
	reg [31:0] layer1_adr = 32'd400_000; 
	reg [31:0] w1_adr = 32'd800; 
	reg [15:0] img_count = 1; 
	reg [15:0] w1_count = 1; 
	reg [3:0] check = 4'hF;

	assign toHexLed = {24'h0,check,state};
	
	localparam IDLE = 0;
	localparam READ_IMG = 1;
	localparam WAIT_IMG = 2;
	localparam ADD = 3;
	localparam WRITE = 4;
	localparam CONT = 5;
	localparam DONE = 6;
	localparam READ_W1 = 7;
	localparam WAIT_W1 = 8;
	localparam CONT2 = 9;
	
	localparam IMG_BASE = 32'd600_000;
	localparam LAYER1_BASE = 32'd400_000;
	localparam W1_BASE = 32'd800;
	
	always @ (posedge clk) begin
		if(~reset_n) begin
			state <= IDLE;
		end
		else begin
			case(state)
				IDLE: begin
								state <= (ready) ? READ_IMG : IDLE;
								total <= 0;
								img_count <= 1;
								w1_count <= 1;
								img_adr <= IMG_BASE;
								layer1_adr <= LAYER1_BASE;
								w1_adr <= W1_BASE;
				end
				READ_IMG: begin
								state <= (!waitrequest) ? WAIT_IMG : READ_IMG;			
				end
				WAIT_IMG: begin
								state <= (readdatavalid) ? READ_W1: WAIT_IMG;
								img_adr <= (readdatavalid) ? img_adr + 2 : img_adr;
								img_count <= (readdatavalid) ? img_count + 1: img_count;
								img_cur <= (readdatavalid) ? readdata : img_cur;
				end
				READ_W1: begin
								state <= (!waitrequest) ? WAIT_W1 : READ_W1;
				end
				
				WAIT_W1: begin
								state <= (readdatavalid) ? ADD : WAIT_W1;
								w1_adr <= (readdatavalid) ? w1_adr + 2: w1_adr;
								w1_cur <= (readdatavalid) ? readdata : w1_cur;
				end
				
				ADD: begin
								state <= (img_count < 784) ? READ_IMG : WRITE;
								total <= (img_cur != 0) ? w1_cur + total : total;
				end
				
				WRITE: begin
								state <= (!waitrequest) ? CONT : WRITE;
								layer1_adr <= (!waitrequest) ? layer1_adr + 2: layer1_adr;
								w1_count <= (!waitrequest) ? w1_count + 1 : w1_count;
								writedata <= total;
				end
				
				CONT: begin
								state <= (w1_count < 200) ? READ_IMG : DONE;
								total <= 0;
								img_count <= 1;
								img_adr <= IMG_BASE;
								w1_adr <= w1_adr;
								w1_count <= w1_count;
				end
				
				DONE: begin
								state <= (~ready) ? IDLE : DONE;
				end
			endcase
		end
	end
	
	always @ (*) begin
		done = (state == DONE) ? 1 : 0;
		case(state)
			IDLE: begin
				read_n <= 1;
				write_n <= 1;
				address <= 0;
			end
			READ_IMG: begin
				read_n <= 0;
				write_n <= 1;
				address <= img_adr;
			end
			WAIT_IMG: begin
				read_n <= 0;
				write_n <= 1;
				address <= img_adr;			
			end
			READ_W1: begin
				read_n <= 0;
				write_n <= 1;
				address <= w1_adr;			
			end	
			WAIT_W1: begin
				read_n <= 0;
				write_n <= 1;
				address <= w1_adr;			
			end	
			DONE: begin
				read_n <= 1;
				write_n <= 1;
				address <= img_adr;			
			end
		endcase
	end
					
endmodule
/*		
	//Outputs
	always @ (posedge clk)
	begin
		counter <= counter;
		counter2 <= counter2;
		total <= total;
		img_adr <= img_adr;
		layer1_adr <= layer1_adr;
		w1_adr <= w1_adr;
		
		case(state)
			IDLE: begin
							counter    <= 1;
							counter2   <= 1;
							img_adr    <= 32'd600_000; //test data
							w1_adr     <= 32'd800;     //weight 1
							layer1_adr <= 32'd400_000; //layer1
							total      <= 16'd0;
			end

			// Read test data
			READ:
			begin
			end

			// Read test data pt2
			LOAD:
			begin
				data <= (readdatavalid) ? readdata : data;
				img_adr <= (readdatavalid) ? img_adr + 2 : img_adr;
			end
			
			// Read Weight
			READ2:
			begin
			end

			// Read Weight pt 2
			LOAD2:
			begin
				data2  <= (readdatavalid) ? readdata   : data2;
				w1_adr <= (readdatavalid) ? w1_adr + 2 : w1_adr;
				counter <= (readdatavalid) ? counter + 1 : counter;
			end
			
			// Sum up weights
			ADD:
			begin
				total <= (data != 0) ? total + data2 : total;
			end
			
			// Have we read 784 times?
			//CONT:			begin counter <= counter + 1; end
			
			// Write request (to layer1)
			WRITE:
			begin
				layer1_adr <= (waitrequest) ? layer1_adr : layer1_adr + 2;
				counter2 <= (waitrequest) ? counter2 : counter2 + 1;
			end
			
			//Have we written 200 times?
			CONT2:
			begin
				img_adr <= 600_000; //reset td address
				counter <= 1; //reset counter
				total <= 0; //reset total
			end

			// Done
			FINISH:
			begin
			end
			
		endcase
	end

	// Nextstate logic
	always @ (*)
	begin
	
		read_n  <= 1;
		write_n <= 1;
		address <= address;

		case(state)
			
			// Wait for ready == 1
			IDLE:
			begin
				nextstate <= (ready) ? READ: IDLE;
			end


			// Read request
			READ:
			begin
				read_n <= 0;
				address <= img_adr;
				nextstate <= (waitrequest) ? READ : LOAD;
			end

			// Read request pt2
			LOAD:
			begin
				nextstate <= (readdatavalid) ? READ2 : LOAD;
			end
			
			// Read weights
			READ2:
			begin
				read_n <= 0;
				address <= w1_adr;
				nextstate <= (waitrequest) ? READ2 : LOAD2;
			end
			
			// Read weights pt2
			LOAD2:
			begin
				nextstate <= (readdatavalid) ? ADD : LOAD2;
			end

			//Add state
			ADD:
			begin
				//nextstate <= CONT;
				nextstate <= (counter < 784) ? READ : WRITE;
			end
			
			//Have we read 784 times?
//			CONT:	begin nextstate <= (counter < 784) ? READ : WRITE; end
			
			//Write Request
			WRITE:
			begin
				read_n <= 1;
				write_n <= 0;
				writedata <= total;
				address <= layer1_adr;
				nextstate <= (waitrequest) ? WRITE : CONT2;
			end
			
			//Have we written 200 times?
			CONT2:
			begin
				nextstate <= (counter2 < 200) ? READ : FINISH;
			end
			
			//Done state
			FINISH:
			begin
				read_n <= 1;
				write_n <= 1;
				done <= (ready) ? 1 : 0;
				nextstate <= (ready) ? FINISH : IDLE;
			end
			
		endcase
	end

endmodule
*/