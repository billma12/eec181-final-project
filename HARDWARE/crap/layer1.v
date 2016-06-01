module read_w1(
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



	reg [15:0] data = 16'hF00D;
	reg [7:0] state;
	reg [7:0] nextstate = 0;
	reg [31:0] addr = 600_000;
	reg [31:0] addw = 650_000;
	reg [31:0] counter = 1;
	reg[31:0] counter2 = 1;
	reg [783:0] image;

	assign toHexLed = {counter,data,state};

	assign chipselect = 1;
	assign byteenable = 2'b11;

	localparam base_w1 = 32'd800;
	localparam base_layer1 = 32'd400_000;
	
	always @ (posedge clk)
	begin
		state <= nextstate;
		if(reset_n == 0)
		begin
			state <= 0;
		end
	end

	always @ (posedge clk)
	begin
		counter <= counter;
		counter2 <= counter2;
		addr <= addr;
		addw <= addw;
		
		case(state)
			8'h0:
			begin
				counter <= 1;
				counter2 <= 1;
				addr <= base_w1;
				addw <= base_layer1;
			end

			// Read request
			8'h1:
			begin

			end

			// Read request pt2
			8'h2:
			begin
				data <= (readdatavalid) ? readdata : data;
				addr <= (readdatavalid) ? addr + 2 : addr;
			end

			// add
			8'h3:
			begin
				total <= (1) ? data + total : total;
			end
			
			// increase counter until 784
			8'h4:
			begin
				counter <= counter + 1;
			end
			
			// Write request
			8'h5:
			begin
				addw <= (waitrequest) ? addw : addw + 2;
			end
			// cont2
			8'h6:
			begin
				total <= 0;
				counter <= 1;
				counter2 <= counter2 + 1;
			end
		endcase
	end

	always @ (*)
	begin
		read_n <= 1;
		write_n <= 1;
		address <= address;

		case(state [7:0])
			// Wait for ready == 1
			8'h0:
			begin
				nextstate <= (ready) ? 1 : 0;
			end

			// Read request
			8'h1:
			begin
				read_n <= 0;
				address <= addr;
				nextstate <= (!waitrequest) ? 2 : 1;
			end

			// Read request pt2
			8'h2:
			begin
				nextstate <= (readdatavalid) ? 10 : 2;
			end
			
			8'h10:
			begin
				nextstate <= (delay == 5) ? 8 : 10;
			end
			
			
			8'h8:
			begin
				read_n <= 0;
				address <= addr_img;
				nextstate <= (!waitrequest) ? 9: 8;
			end
			
			8'h9:
			begin
				nextstate <= (readdatavalid) ? 3: 9;
			end
			
			// add
			8'h3:
			begin
				nextstate <= 4;
			end
			
			// have we read 784 times
			8'h4:
			begin
				nextstate <= (counter < 784) ? 1: 5; //go back to reading weights
			end

			// Write Request
			8'h5:
			begin
				write_n <= 0;
				address <= addw;
				writedata <= data;
				nextstate <= (!waitrequest) ? 6 : 5;
			end

			// have we written 200 times
			8'h6:
			begin
				nextstate <= (counter2 < 200) ? 1 : 7;
			end
			
			8'h7:
			begin
				done <= (ready) ? 1 : 0;
				nextstate <= (!ready) ? 7 : 0;
			end
		endcase
	end

endmodule