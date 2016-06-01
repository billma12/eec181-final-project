module sdram_rx2(
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



	reg [15:0] data = 16'hA1;
	reg [7:0] state;
	reg [7:0] nextstate = 0;
	reg [31:0] addr = 10;
	reg [31:0] addw = 100;
	reg [31:0] counter = 1;

	assign toHexLed = {counter,data,state};
	//assign toHexLed [15:0] = data [15:0];
	//assign toHexLed [30:16] = counter [14:0];
	//assign toHexLed [33:31] = state [2:0];

	assign chipselect = 1;
	assign byteenable = 2'b11;

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
		addr <= addr;
		addw <= addw;
		case(state)
			8'h0:
			begin
				counter <= 1;
				addr <= 100;
				addw <= 400;
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

			// Write request
			8'h3:
			begin
				addw <= (waitrequest) ? addw : addw + 2;
			end

			8'h4:
			begin
				counter <= counter + 1;
			end

			8'h5:
			begin
			end
		endcase
	end

	always @ (*)
	begin
		// state [7:0] <= nextstate [7:0];
		read_n <= 1;
		write_n <= 1;
		address <= 100;

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
				nextstate <= (waitrequest) ? 1 : 2;
			end

			// Read request pt2
			8'h2:
			begin
				nextstate <= (readdatavalid) ? 3 : 2;
			end

			// Write Request
			8'h3:
			begin
				write_n <= 0;
				address <= addw;
				writedata <= data;
				nextstate <= (waitrequest) ? 3 : 4;
			end

			8'h4:
			begin
				nextstate <= (counter < 5) ? 1 : 5;
			end

			8'h5:
			begin
				done <= (ready) ? 1 : 0;
				nextstate <= (ready) ? 5 : 0;
			end
		endcase
	end

endmodule