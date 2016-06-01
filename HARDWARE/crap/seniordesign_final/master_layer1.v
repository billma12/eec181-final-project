module sdram_master(
	input clk,
	output reg read_n = 1,
	output reg write_n  = 1,
	output chipselect,
	input waitrequest,
	output reg [31:0] address = 0,
	output [1:0] byteenable,
	input readdatavalid,
	input [15:0] readdata,
	output reg [15:0] writedata,
	input reset_n,
	
	//to HPS
	
	output reg [3:0] state = 0, //want to see states on board
	input ready,
	output reg done
);

//should always be these values
assign byteenable = 2'b11;
assign chipselect = 1;

//macro defs
localparam W1_OFST = 32'd400
localparam TD_OFST = 32'd300000
localparam L1_OFST = 32'd200000

localparam INPUT_SIZE = 784
localparam LAYER = 200

//states
localparam IDLE = 0;
localparam READ_W1 = 1;
localparam READ_TD = 2;
localparam ADD = 3;
localparam WRITE = 4;
localparam DONE = 5;
localparam INCR_COUNT = 6;
localparam INCR_COUNT2 = 7;

//-----------------internal registers-------------//

reg[15:0] w1_cur = 16'd0; //holds current value of w1
reg[15:0] td_cur = 16'd0; //holds current value of test data
reg[15:0] layer1_cur = 16'd0; //what i want to write to sdram

//w1 is 2-dimensional matrix need row and column, for now callling it count and count2
reg[15:0] count = 0;
reg[15:0] count2 = 0;

//for waitrequest and readdatavalid
reg step;

//output stuff
always @ (posedge clk)
begin
	case(state)
	IDLE:
		begin
			read_n <= 1;
			write_n <= 1;
			address <= 1;
			writedata <= 0;
			
			w1_cur <= 0;
			td_cur <= 0;
			layer1_cur <= 0;
			
			count <= 0;
			count2 <= 0;
			step <= 0;
			
			done <= 0;

			state <= (ready) ? READ_W1: IDLE;
		end
	READ_W1:
		begin
			if(step == 0) //will arrive here from wait or incr_count2 or add
			begin
				read_n <= 0; //send read request to slave (chipselect is always 1 and so is byteenable)
				address <= W1_OFST + INPUT_SIZE*count2 + count; //count2 indicates which layer index we're on
				if(waitrequest == 0) begin //sample waitrequest until it's deasserted
					step <= 1; //waitrequest has been deasserted, we can read from slave now
				end
				else begin
					step <= 0; //keep sampling until waitrequest is 0
				end
			end
			else //step = 1, can access bus now
			begin
				if(readdatavalid == 1) begin //we are now sampling readdatavalid until it's 1
					w1_cur <= readdata; //get data from address
					state <= READ_TD; //we can move onto next state cause we got the data we want
					step <= 0; //update step for next state
				end
				else begin
					step <= 1; //keep on sampling until readdatavalid is good
				end
			end
		end
	READ_TD: //same logic as READ_W1
		begin
			if(step == 0) //first arrive here from READ_W1
			begin
				read_n <= 0; //still want to read
				address <= TD_OFST + count; //now reading from test data, k is what image we're on 
				if(waitrequest == 0) begin
					step <= 1;
				end
				else begin
					step <= 0;
				end
			end//if(step == 0)
			else begin
				if(readdatavalid == 1) begin
					td_cur <= readdata;
					state <= INCR_COUNT;
					step <= 0;
				end
				else begin
					step <= 1;
				end
			end//else
		end
	ADD:
		begin
			read_n <= 1; //no read
			write_n <= 1; //no write
			address <= address; //shouldn't matter what address here...probably don't need this
			layer1_cur <= (td_cur != 0) ? layer1_cur + w1_cur : layer1_cur; //just add
			state <= (count/2 == INPUT_SIZE) ? WRITE : READ_W1;
		end
	WRITE: //we arrive at this state means we've added enough to fill in 1 index in our layer
		begin
			read_n <= 1; //prolly don't need this 
			write_n <= 0; //we are now writing
			address <= L1_OFST + count2; //write to L1 OFST
			if(waitrequest == 0) begin
				writedata <= layer1_cur;
				state <= (count2/2 == (LAYER-1)) ? DONE : INCR_COUNT2; //-1 cause layer starts at 0
			end
			else begin
				state <= WRITE; //keep on sampling waitrequest until it's deasserted
			end
		end
	DONE:
		begin
			done <= 1;
			read_n <= 1;
			write_n <= 1;
			address <= 0;
			writedata <=0;
			state <= (~ready) ? IDLE: DONE;
		end
	INCR_COUNT: //prev state was READ_TD
		begin
			address <= address; //probably don't need this
			count <= count + 2;
			state <= ADD;
		end
	INCR_COUNT2: //prev state was write, means we finished filling in an index
		begin
			count <= 0; //reset the INPUT_SIZE counter
			count2 <= count2 + 2; //increase layer index
			state <= READ_W1; //iterating to the next layer index
		end
	//default:
	//	state <= IDLE;
	endcase
end
/*
always @ (posedge clk)
begin
	case(state)
		 //IDLE: state <= (ready) ? READ_W1 : IDLE;
		//READ_W1: state <= (readdatavalid ) READ_TD; //UPDATE THIS!!!
		//READ_TD: state <= INCR_COUNT;
		//INCR_COUNT: state <= ADD;
		//ADD: state <= (count == 10) ? WRITE : READ_W1; 
		//WRITE: state <= (count2 == 2) ? DONE: INCR_COUNT2;
		//INCR_COUNT2: state <= READ_W1;
		//CHECK: state <= 
		//DONE: state <= (~ready) ? IDLE: DONE;
		default: state <= IDLE;
	endcase
end
*/
endmodule