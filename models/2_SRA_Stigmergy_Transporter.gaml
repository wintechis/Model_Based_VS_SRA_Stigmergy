/**
* Name: SRA_Stigmergy_Transporter
* Model_Based_VS_SRA_Stigmergy
* Author: Sebastian Schmid
* Description: uses SRA with quantitative stigmergy   
* Tags: 
*/

@no_warning
model SRA_Stigmergy_Transporter

global{
	int shop_floor_diameter <-500 min:10 max: 500;
	geometry shape <- square(shop_floor_diameter);
	int no_station <- 4 min: 2 max: 20;
	int no_transporter <- 17 min: 1 max: 100;
	
	int cell_width <- 20;
	int cell_height <- cell_width;
	list<string> placement_mode const: true <- ["strict" , "random", "centered", "corners"];
		//describes the distribution mode for stations:
		/*strict:		4 stations making a square near the center  
		 *random: 		picks a random spot to place a station
		 *structured:	stations are placed in a symmetrical distance around the world center
		 *corners: 		stations are placed towards the world corners, but there also randomly  
		 */
	string selected_placement_mode <- placement_mode[0]; //default is 'strict'
	float strict_placement_factor <- 0.33 min:0.1 max:0.45; //for strict mode to influence placement
	
	/*this variable is only needed when placement mode "centered" is chosen and defines the radius of the placement circle in the center */
	float circle_radius <- 0.25*shop_floor_diameter min: 0.0 max:0.5*shop_floor_diameter;

	list<rgb> colors <- list_with(no_station, rnd_color(255)); //creates a list with no. of stations random colors. 
	
	list<string> color_mode const:true <- ["unique", "random"];  
	//describes the coloring mode for stations:
		/*unique: 		each color is only allowed once
		 *random:		colors are picked randomly and can therefor occure more than once
		 */
	string selected_color_mode <- color_mode[0]; //default is 'unique'
	
	int disturbance_cycles <- 500#cycles; //in strict mode: all N cycles, we change the color of our stations	
	
	bool stigmergy_activated <- true; //flag for switching stigmergy on and off
	bool activate_evaporation <- true; //flag for switching evopartion of stigmergy marks on and off
	float evaporation_factor <- 0.003 min: 0.0; //how fast the evaporation takes place. Is direct subtracted from color mark value  
	bool activate_negative_stigmergy <- false;
	/*I define the color of the thing as maximum (= 1.0) s.t. all other gradient have to lie below that. To make them distinguishable, the STRONG mark may have (color_gradient_max )*THING_COLOR. All other WEAK gradients are below. */
	float color_gradient_max <- 0.75 max: 0.99;
	
	
	/* Investigation variables - PART I (other part is places behind init block)*/
		map<rgb, int> delivered <- []; //will be used to keep track of how many things of each color have been delivered. "keys" of this maps contains the list of station colors. also used in Statio init!!
		int total_delivered <- 0; //holds the total amount of delivered things 
		
		//the time it took to deliver the thing to any accepting station
		int time_to_deliver_SUM <- 0; //this variable holds the SUM of all delivery times for calculating the mean
		float mean_of_delivered_cycles <- 0; //holds the average amount of cycles it took to deliver a thing successfully
		int window_for_last_N_deliveries <- 10 min: 1; //breadth of the moving average window for the last N deliveries
		list<float> moving_average <- []; //holds the last "window_for_last_N_deliveries" values for deliveries to calculate a moving average 
		float moving_average_SUM <- 0; //holds the average value over the moving average
		
		map<string, int> transporter_usage <- []; //transporter will add themselves in their init block
		
		rgb observe_color <- #red;
	
	list<float> moving_average_steps <- []; //  holds the last "window_for_last_N_deliveries" values for the amount of steps it took a transporter to find its destination after picking up an item
			
	
	init{
							
		create station number: no_station returns: stations;
		
		if(selected_placement_mode = "strict")
		{
			selected_color_mode <- "strict";
		}
		
		/*Assign colors to all stations wrt the simulation settings */
		switch selected_color_mode{
			match "strict"{
				//the strict coloring mode for the strict placement mode that only uses 4 stations
				
				if(no_station != 4)
				{
					write "Coloring mode is still set to strict!";					
				}
				
				list<rgb> col_tmp <- [#red,#blue,#green, #orange];
				
				int i <- 0 ;
				
				loop s over: station{
					
					ask s{
						
						proba_thing_creation <- 0.8; //fixed PROBABILITY of item creation here to 0.8
												
						accept_color <- col_tmp[i]; //the color we accept
						color <- accept_color; //the color we display
						
						add 0 at: col_tmp[i] to: delivered; //create a key::value pair in the delivered variable, corresponding to a color::amount_of_delivered_things_of_this_color pair later
					}
					
					i <- i+1;//to get next colo
				}
			}
			match "unique"{
				ask station{
					rgb col_tmp <- one_of(where(colors, !(in(each, delivered.keys)) )); //choose a random color that hasn't been already chosen
					accept_color <- col_tmp; //set accepted color of station
					color <- col_tmp;	//set displayed color of station
						
					add 0 at: col_tmp to: delivered; //create a key::value pair in the delivered variable, corresponding to a color::amount_of_delivered_things_of_this_color pair later
				}
			}
			
			match "random"{
				ask station{
					rgb col_tmp<- one_of(colors); //choose a random color
					accept_color <- col_tmp; //set accepted color of station
					color <- col_tmp;	//set displayed color of station
					
					add 0 at: col_tmp to: delivered; //create a key::value pair in the delivered variable, corresponding to a color::amount_of_delivered_things_of_this_color pair later
				}
				
				//it COULD be that all stations got assigned the same color - which is bad, hence check it here. If this is the case, inform the user
				list<rgb> r <- station collect each.accept_color;
				int i <- r count (each = first(r));
				if(i = length(r)){
					warn "Color picking went wrong";
					write "RNG picked for all stations the same color. Restart the experiment!!" color:#red;
					do die; //kill the simulation
					}
			}
			
			default{
				write "Something went VERY wrong in color selection...." color:#red;
				warn "Something went VERY wrong in color selection....";
			}
			
		}
		
		/*After the colors have been assigned, choose valid colors for thing production */
		ask stations{
			
			valid_colors <- delivered.keys - accept_color; //delivered keys holds the list of all colors used by stations, exclude my own color
			
			//valid_colors <- delivered.keys; //delivered keys holds the list of all colors used by stations
			//remove all: self.accept_color from: valid_colors; //remove the station's own color s.t. only other colors are produced			
		}
		
		/*Place stations acc. to simulation settings */
		switch selected_placement_mode{
			match "strict"{
				
				//This declaration here is intentionally a bit awkward, because it's implemented for fixed 4 stations...
				
				float factor <- strict_placement_factor;
				
				shop_floor up_left <- shop_floor({factor * shop_floor_diameter, factor * shop_floor_diameter});
				shop_floor up_right <- shop_floor({(1-factor) * shop_floor_diameter, factor * shop_floor_diameter});
				shop_floor down_left <- shop_floor({factor * shop_floor_diameter, (1-factor) * shop_floor_diameter});
				shop_floor down_right <- shop_floor({(1-factor) * shop_floor_diameter, (1-factor)* shop_floor_diameter});
				
				station[0].my_cell <- up_left;
				station[1].my_cell <- up_right;
				station[2].my_cell <- down_left;
				station[3].my_cell <- down_right;
				
				loop s over: stations{	

					ask s{
							location<-my_cell.location ;
						}	
				}
			}
			match "random"{
				//loop over all stations to assign positions					
				loop s over: stations{	
					//draw a random position and check if it has been already assigned. If so, draw again etc
					loop while: true{
						point cellAgent <- {rnd(shop_floor_diameter ), rnd(shop_floor_diameter )};
						
						//count amount of agents inside. if list is empty, the space is still free and the station is assigned there
						if(empty(station inside cellAgent)){
							ask s{
									my_cell <- shop_floor(cellAgent);
									location<-my_cell.location ;//cellAgent.location;
								}
							 
							break;	
						}
					}
				}				
			}
			
			match "centered" {
				// structered distribution of stations w.r.t. center of world
				point center <- {shop_floor_diameter/2, shop_floor_diameter/2};				
				geometry g <- circle(circle_radius, center); //circle_radius is calculated wrt shop_floor_diameter 
				//loop over all stations to assign positions									
				loop s over: stations{	
					//draw a random position from inside the circle and check if it has been already assigned. If so, draw again etc
					loop while: true{
						point celltmp <- any_location_in(g); //pick a point inside the circle
						//count amount of agents inside. if list is empty, the space is still free and the station is assigned there
						if(empty(station inside shop_floor(celltmp))){
							ask s{
									my_cell<- shop_floor(celltmp);
									location<- my_cell.location;
								}
							 
							break;	
						}
					}
				}				
			}
			
			match "corners"{
				//loop over all stations to assign positions in corners of the environment					
					loop s over: stations{	
						//draw a random position and check if it has been already assigned. If so, draw again etc
						loop while: true{
							
							//calculate a random spot in a corner environment
							float partial_x <- rnd(0.25); //part of the x dimension 
							float partial_y <- rnd(0.25); //part of the y dimension 
							
							//calculate if it either in the "lower" (0.0-0.25) or "higher" (f.i. 1.0-0.25=0.75) parts of the respective dimension  
							partial_x <- (flip(0.5) ? (partial_x): (1-partial_x));
							partial_y <- (flip(0.5) ? (partial_y): (1-partial_y));
							
							point cellAgent <- {partial_x * shop_floor_diameter, partial_y * shop_floor_diameter};
							
							//count amount of agents inside. if list is empty, the space is still free and the station is assigned there
							if(empty(station inside cellAgent)){
								ask s{
										my_cell <- shop_floor(cellAgent);
										location<-my_cell.location ;//cellAgent.location;
									}
								 
								break;	
							}
						}
					}
			}
			
			default{
				write "Something went VERY wrong in mode selection...." color:#red;
				warn "Something went VERY wrong in mode selection....";
			}
			
		}
			
		create transporter number: no_transporter;	
	}
	
	/*For random color change of stations */
	//every "disturbance_cycles" cycles, we take the already given colors and switch them randomly around
	reflex change_station_colors when: (cycle > 1) and every(disturbance_cycles){
		
		list<rgb> col_tmp <- nil; //will hold all current colors
		ask station{
			col_tmp <- col_tmp + accept_color; //add your color to the list of all color
		}
		
		col_tmp <- shuffle(col_tmp); // shuffle randomly
		
		int i <- 0 ;
				
		loop s over: station{
			
			ask s{										
				accept_color <- col_tmp[i]; //assign possibly new color
				
				color <- accept_color; //the color we display
				valid_colors <- col_tmp - accept_color; //update items that may be created
				
				//sanity check for assignment of new color - manipulate item, if it has the same color as the station now...
				if(storage != nil and (storage.color = accept_color))
				{
					storage.color <- one_of(valid_colors); //choose a random valid one
				}
				 
			}
			
			i <- i+1;//to get next color
		}	
	}
	
	/* Investigation variables - PART II (other part is places before init block)*/
	//nothing	

}


//##########################################################
species superclass{
	shop_floor my_cell <- one_of(shop_floor);
	
	init{
		location <- my_cell.location;	
	}
}


species thing parent: superclass{
	rgb color <- #white;
	int cycle_created <- -1; //the cycle when this thing was created by a station
	int cycle_delivered <- -1; //the cycle when this thing was delivered to a accepting station via a transporter	
	
	aspect base{
		
		draw circle(0.25*cell_width) color: color border:#black;
	}
	
	map get_states{
		return create_map(["color", "location"],[color, location]);
	}
	
	init{
		cycle_created <- cycle; //set the current cycle as "creation date" for this thing
	}
}

species station parent: superclass{

	
	thing storage<- nil; //if nil, then this storage is empty
	
	rgb accept_color <- nil; //colors that this stations accepts
	
	float max_proba_thing_creation <- 0.8;
	float min_proba_thing_creation <- 0.01;
	float proba_thing_creation <- rnd(min_proba_thing_creation , max_proba_thing_creation ); //probability that thing is created
	
	list<rgb> valid_colors <- []; //contains all colors that may be created (= all stations colors MINUS its own color)
	
	reflex create_things when: (storage = nil) and (flip(proba_thing_creation)){  
		create thing number: 1 returns: t{
			location <- myself.location;	
			//create a thing based on the generated station colors
			color <- one_of(myself.valid_colors);		
		}

		storage <- t[0]; //there is only one thing created, therefore take first entry and assign it to storage
	}
	
	aspect base{
		draw square(cell_width) color: accept_color border:#black;
	}
	
	thing get_storage{
		//a thing if something is stored. nil if it is empty
		return storage;		
	}
	
	map get_states{
		return create_map(['storage', "accept_color"],[storage, accept_color]);
	}
	
}

species transporter parent: superclass {
	thing load <- nil;
	
	float amount_of_steps<- 0.0; //the amount of steps this transporter made after it pickep up an item   
	
	init{
	
	}
	
	reflex wander when: (load = nil) {
		
		//generate a list of all my neighbor cells in a random order
		list<shop_floor> s <- shuffle(my_cell.neighbors); //get all cells with distance ONE
		
		loop cell over: s{ //check all cells in order if they are already taken.
			if(empty(transporter inside cell) and empty(station inside cell)) //as long as there is no other transporter or station
			{
				my_cell <- cell; //if the cell is free - go there
				location <- my_cell.location;
			}
		}

	}
	
	reflex color_mark_wandering when:(load != nil) {
		
		//generate a list of all my neighbor cells in a random order
		list<shop_floor> s <- shuffle(my_cell.neighbors); //get all cells with distance ONE

		//check for matching colors. if there are matching color marks present, follow them. if not, just take anything else
		list<shop_floor> cells_with_color_marks <- s where (each.color_marks.keys contains rgb((load.get_states())["color"])); //get cells that do have OUR color marks
		
		s <- s - cells_with_color_marks; //Remove all cells with color marks from the set of adjacent cells. Later we will forst check for cells with color marks and, if none are left, we will check s  
		
		shop_floor cell<-my_cell; //initialize cell variable with own tranporter's cell. this gurantees that the first check fails (because the transporter itself is already at its own position)... basically a do-while ^^**
		
		list<shop_floor> sorted <- nil; //holds all cells with color marks sorted in ascending order of their mark strength 
		
		if(!empty (cells_with_color_marks)){
			sorted <- (shuffle(cells_with_color_marks)) sort_by (each.color_marks at rgb((load.get_states())["color"])); //ascending order of mark strength is default
			sorted <- reverse(sorted); //now descending order of strength
		}
		
		//We iterate over all possible cells, until we find a free cell 
		//I know this could be solved above more easily with just taking the first entry of my sorted list, but I want to keep the possibility to go to cells that are not the optimum path, e.g. if optimum is blocked (avoid deadlock) 
		loop while: !(empty(transporter inside cell) and empty(station inside cell)){ 
			
			//if no cells with marks are left to check (or no are there..?), just wander
			if(empty(sorted)){
					
					if(empty(s)){
						cell<-my_cell; //if no cells are left in neighbors s, just stay where you are
						break;
					}
					else{
						cell <- first(shuffle(s)); //pick a random neighboring cell without a color mark
						
						remove cell from: s; //s.t. we wont pick it again
					}					
			}
			else{//if there are cells with color marks left

				cell <- first(sorted); //first option is always best, because it's sorted in descending order of strength. If more than one cell have the same strength, the probability to be at the front is the same.
				remove cell from: sorted; //s.t. we wont pick it again, if the check will state it is occupied
				sorted <- reverse(sorted sort_by (each.color_marks at rgb((load.get_states())["color"]))); //sort cells again in descending order
			} 
		}
		
		//if I am also carrying something around and I actually DID take a step , increase my step counter
		if(load != nil and (my_cell != cell))
		{
			amount_of_steps <- amount_of_steps +1;
		}
		
		my_cell <- cell; //cell is determined as goal for next step - go there
		location <- my_cell.location;

	}
		
	
	//this reflex is for the case that I have a thing and am now looking for a station. Up to now, i DO NOT have to queue
	reflex get_rid_of_thing when: (load != nil){			
		//get the first cell with a station on it that is adjacent to me
		shop_floor cell_tmp <- (my_cell.neighbors) first_with (!(empty(station inside (each)))); //only ONE (the first cell...)
		list<shop_floor> cell_tmp_list <- (my_cell.neighbors) where (!(empty(station inside (each)))); //get all stations 
 
		//check all adjacent cells with stations inside 
		loop cell over: cell_tmp_list{
			
			station s <- one_of(station inside cell); //there should only be one station per cell, but this ensures that only one is picked.
		
			//if the station we picked has the color of our item
			if((s.get_states())["accept_color"] = (load.get_states())["color"]) {
				
				/*Update all variables and containers for investigations*/
					put delivered[load.color]+1 key:load.color in: delivered; //count as delivered in respective colo category
					total_delivered <- total_delivered +1; //increase counter for total amount of delivered things by 1
					
					//add current cycle to thing to denote time when it was delivered
					load.cycle_delivered <- cycle; //sent new cycle as state to load
					int cycle_difference <- load.cycle_delivered - load.cycle_created; //calculate the cycle difference to add it to the evaluation variables in the next step
					time_to_deliver_SUM <- time_to_deliver_SUM + cycle_difference ; //add it to the total sum
					mean_of_delivered_cycles <- time_to_deliver_SUM/(total_delivered); //after successful delivery, update average amount of cycles
					moving_average <- moving_average + float(cycle_difference / window_for_last_N_deliveries);
					moving_average_steps <- moving_average_steps + amount_of_steps; //add to rest
					amount_of_steps <- 0.0; //reset amount of steps
					
					if(length(moving_average) > window_for_last_N_deliveries) //make sure that only the requested amount of data is saved
					{
						//as time_to_deliver is filled successively, we only have to get rid of the first entry (FIFO)  
						remove index: 0 from:moving_average;
						moving_average_SUM <- sum(moving_average);
					}
					
					//MoAvg steps taken until destination
					if(length(moving_average_steps ) > window_for_last_N_deliveries) //make sure that only the requested amount of data is saved
					{
						//as time_to_deliver is filled successively, we only have to get rid of the first entry (FIFO)  
						remove index: 0 from:moving_average_steps;
					}
				
				if(stigmergy_activated){
					//after our thing has been successfully delivered, let the transporter create a color mark for others (stigmergy)
					do set_aphid_marks;
				}
								
				do deliver_load(); //load is delivered
				break; //as we have loaded off our item, we do not need to check any leftover stations (also it would lead to an expection because load is now nil)
			}
		}		
	}
	
	//check neighobring marks and perpetuate the distribution of color marks that are near me
	reflex check_aphid_marks{
		
		list<shop_floor> cell_tmp <-my_cell.neighbors;// take all neighboring cells
		
		map<rgb, float> my_marks <- my_cell.color_marks; //take MY current color marks
		
		map<rgb, float> neighbor_marks <- nil; 
		
		//check all neighboring cells
		loop cell over: cell_tmp{
			
			map<rgb, float> marks <- cell.color_marks; //get neighbors color marks
			
			//check for each entry its color marks
			loop col over: marks.keys{
				
				if((marks at col) > (neighbor_marks at col)){ //check if their color mark is stronger than current one
					add (marks at col) at: col to: neighbor_marks;//if so, overwrite it and gather these maximum values in the neighbor color mark map
				}
				
			}
		}
		
		//check all entries in the neighbors marks
		loop col over: neighbor_marks.keys{
						
			if((neighbor_marks at col) > (my_marks at col)){//check if the maximum around me is bigger than my value
				add (neighbor_marks at col)*0.9 at: col to: my_marks; //if so, add an entry to myself with reduced maximum
				ask my_cell{changed <- true;} //set status to changend s.t. color display is updated 
			}
			
		}
		
		ask my_cell	{
			do set_color_marks(my_marks); //update my color mark values
		}
	}
	
	
	//in the above reflexes, we checked our surroundings, looked for a possible maximum of color marks, took a step and checked for stations.
	//NOW, we check, if we are trapped in a local maximum, e.g. created by evaporation or an "island"
	//this can happen independently of our transportation task and the chance to deliver something
	//We just consider marks of the thing we are currently transporting
	reflex negative_stigmergy when: ((load != nil) and  activate_negative_stigmergy) {
		
		do check_for_local_maximum(load.color);		
	}
	
	/*Transporter check all of their surrounding marks, if there is a local maximum and if so, if an applicable station is adjacent. If not, they delete it*/
	//This applies to all transporters, independently of their load color, and only considers their environment
	reflex social_negative_stigmergy when: activate_negative_stigmergy {
		
		//generate a list of all my neighbor cells in a random order with my color marks
		list<rgb> local_color_marks <- my_cell.color_marks.keys; //
		
		//if there's nothing to compare, abort
		if(empty(local_color_marks)){
			return;
		}
		
		list<shop_floor> cells_with_color_marks <- my_cell.neighbors where (each.color_marks.keys contains_any local_color_marks); //get cells that do have any of OUR local color marks
		
		if(empty(cells_with_color_marks )){
			return; //if there are now color marks to be checked, abort mission.
		}
		
		
		loop col over: local_color_marks {
			//check for suiting stations nearby
			//get all possible stations around me; 'accumulate' returns a flat list of all stations inside the given list of cells aka my neighbors; apply a filter to this list of stations for the currently checked color 
			list<station> cell_with_suiting_station <- (my_cell.neighbors accumulate (station inside each)) where (each.accept_color = col); //returns a list of nearby stations that accept the currently checked color
			 
			if(!empty(cell_with_suiting_station)){
				//if this is NOT empty, there are stations nearby that would accept this checked color, hence the local maximum is valid.
				//Thus, break - no further check is needed
				
				break;
			}
			
			//if NO suitable station is nearby, we check for a local maximum that has to be removed 
			do check_for_local_maximum(col);
	
		}			
	}
	

	
	//search adjacency for a station. If it has a thing, pick it up. Depending in stigmergy settings, also initiate color marks
	reflex search_thing when: load = nil{			
		//get the first cell with a station on it that is adjacent to me
		shop_floor cell_tmp <- (my_cell.neighbors) first_with (!(empty(station inside (each))));
		
		if(cell_tmp != nil) //if this cell is NOT empty, the transporter has a station neighbor
		{
			station s <- first(station inside cell_tmp); //cells can only have one station at a time, hence this list has exactly one entry. 'First' is sufficient to get it.
			
			//Request state of s to ask about storage. if this NOT nil, a thing has been created and is waiting there and assigned as load.
			load <- (s.get_states())["storage"]; //thanks, we'll take your thing as load over from here 
			
			if( load != nil){
				
				//if load is NOT nil now, we took something over. If it would still be nil, then the station was simply empty
				s.storage <- nil; //we took the thing, thus set station's storage to nil
				//Remark: here used to be an update for the load's location, but as the reflex for updating the thing follows immediately after this reflex here, we don't need it
			}
			
		}		
	}
	
	//updates position of the current load s.t. it appears at the same posiiton as the transporter
	reflex update_thing when: (load != nil){
		ask load{
				my_cell <- myself.my_cell; //just ask the thing you carry to go to the same spot as you.
				location <- myself.my_cell.location;
			}			
	}
		
	//check for and remove a specific color marks if it is part of a specific local maximum that should not be there...
	action check_for_local_maximum(rgb col){
		list<shop_floor> cells_with_color_marks <- my_cell.neighbors where (each.color_marks.keys contains col); //get cells that do have OUR color marks
		
		float max_strength_of_neighbors <- 0;
		
		if(!empty(cells_with_color_marks)){
		
			max_strength_of_neighbors <- cells_with_color_marks max_of (each.color_marks at col); //get maximum strength of my surroundings with seeked color marks 
		
		}
			
		//if my strength is higher than my surroundings... and I DID NOT deliver my item (load = nil), then I am trapped in a local maximum
		if((my_cell.color_marks at col) >= max_strength_of_neighbors){ //greater OR EQUAL
			remove key: col from: my_cell.color_marks ; //deletes color mark without a trace << not using evaporation gives better results up to now! (@@@)	
			my_cell.changed <- true;
			
		}				
	}
	
	action set_aphid_marks{
		//only for setting the maximum mark on successful delivery
		ask my_cell{
			
			if(get_color_strength(myself.load.color) < color_gradient_max ){ //if it's weaker, overwrite
				do add_color_mark(myself.load.color, color_gradient_max);	
			}
		}	
	}
		
	action deliver_load{
		ask load{
			do die;
		}

		load<-nil; //reset load after delivery
	}
	
			
	aspect base{
		draw circle(cell_width*0.5) color: #grey border:#black;
	}
	
	aspect info{	
		draw circle(cell_width*0.5) color: #grey border:#black;
		draw replace(name, "transporter", "") size: 10 at: location-(cell_width/2) color: #red;
	}
	
}


/////////////////////////////////////////////////////////////////////////////////////////////////////
grid shop_floor cell_width: cell_width cell_height: cell_height neighbors: 8 use_individual_shapes: false use_regular_agents: false { 	
	//width: shop_floor_diameter height: shop_floor_diameter cannot be set, because the cell widht/height is set
	//the amount of cells hence depends on the environment
	//definition of a grid agent, here as shop floor cell agent with respective topology
	
	rgb color <- #white;// color is only used to display the colors. for recognition use colors_marks 
	map<rgb,float> color_marks <- nil; //holds the color marks and is used for recognition of marks
	bool changed <- false; //inidcates that something has been added or changed and initialised blending of colors again
	
	list<shop_floor> neighbors2 <- self neighbors_at 2;  
	//neighbors_at is pre-defined for grid agents, here with a distance of 2. Result dependes on the grid's topology
	
	//Calculates the evaporation for each cell if marks are there 
	reflex evaporation when: (activate_evaporation and (length(color_marks) >= 1)){
		
		list<rgb> colors <- color_marks.keys;
		list<float> strengths <- color_marks.values;
		float tmp <- 0.0;
		
		loop i from: 0 to: length(colors)-1 { 
			
			tmp <- strengths[i]-evaporation_factor;
			
			if(tmp <= 0.0)
			{
				remove key:colors[i] from: color_marks;
			}
			else
			{
				add tmp at:colors[i] to: color_marks;
			}
			
			changed <- true;	
		}
	}
	
	//reset color
	reflex when: empty(color_marks){
		color <- #white;
	}

	//color blender for display
	reflex when: ((length(color_marks) >= 1) and changed){
		//operates the following way: first(color_marks.keys) gets the first rgb value and first(color_marks) the associate strength, which modifies the alpha channel gives blended_color its first value 		
		//displays all colors
		
		rgb blended_color <- first(color_marks.keys); //variable to mix colors. There is at least one color mark
		blended_color <-rgb(blended_color.red * first(color_marks.values), blended_color.green * first(color_marks.values), blended_color.blue * first(color_marks.values));
		
		if(length(color_marks) > 1){
			
			list<rgb> colors <- color_marks.keys;
			list<float> strengths <- color_marks.values;
				
			loop i from: 1 to: length(colors)-1 { //REMARK: We skip the first value ON PURPOSE, because it is already included in blended_color!!
								
				blended_color <- blend(blended_color, rgb(colors[i].red*strengths[i], colors[i].green*strengths[i], colors[i].blue*strengths[i])); //mix colors by taking each channel and manipulating the strength w.r.t. factor 
			}
		}
		
		color <- blended_color; //display
		changed <- false;
	}
	

	list<shop_floor> neighbors_with_distance(int distance){
		//if distance is one, naturally i am only my own neighbor
		return (distance >= 1) ? self neighbors_at distance : (list<shop_floor>(self));
	} 
	
	//adds a new color to the color mark container
	action add_color_mark(rgb new_color, float strength){
					
		add strength at:new_color to: color_marks;
		changed <- true;
	}

	//deletes a color from the color mark container
	action delete_color_mark (rgb del_color){
		
		if(del_color in color_marks)
		{
			remove key: del_color from: color_marks;
			changed <- true;
		}
		
	}
	
	map<rgb,float> get_color_marks{
		return color_marks;
	}
	
	action set_color_marks(map<rgb,float> new_color_marks){
		color_marks <- new_color_marks; //override color marks with new values
		changed <- true;
	}
	
	float get_color_strength(rgb col)
	{	
		return (color_marks at col);
	}
	
	 aspect info {
        draw string(name) + " - " + string(color_marks at #red with_precision 5) size: 3 color: #grey;
        
    }
}



//##########################################################
experiment SRA_Stigmergy_Transporter_No_Charts type:gui{
	parameter "Activate stigmergy" category: "Simulation settings" var: stigmergy_activated; //switch stigmergy on or off 
	parameter "Station placement distribution" category: "Simulation settings" var: selected_placement_mode among:placement_mode; //provides drop down list
	
	parameter "No. of transporters" category: "Transporter" var: no_transporter<-5;
	
	parameter "Activate evaporation" category: "Stigmergy settings" var: activate_evaporation<-false ; //switch evaopration of stigmergy on or off		
	parameter "Activate negative stigmergy" category: "Simulation settings" var: activate_negative_stigmergy<-true; //window for average of last N deliveries and their cycles
	 
	parameter "Disturbance cycles" category: "Simulation settings" var: disturbance_cycles<-500#cycles;
	parameter "Observe color" category: "Simulation settings" var: observe_color among:[#red, #green, #blue,#orange] on_change:{
		
		ask shop_floor{
			color <- #white;
		}
		
	};
	
	
		
	output {	
		layout #split;
		 display "Shop floor display" { 
				
		 		grid shop_floor lines: #black;
		 		species shop_floor aspect:info;
		 		species transporter aspect: info;
		 		species station aspect: base;
		 		species thing aspect: base;
	
		 }
	 }
	
}

experiment SRA_Stigmergy_Transporter type: gui {

	
	// Define parameters here if necessary
	parameter "Cell diameter" category: "Shopfloor" var: cell_width;
	parameter "No. of stations" category: "Stations" var: no_station;
	parameter "No. of transporters" category: "Transporter" var: no_transporter ;
	
	parameter "Station placement distribution" category: "Simulation settings" var: selected_placement_mode among:placement_mode; //provides drop down list
	parameter "Station placement parameter (only for strict mode)" category: "Simulation settings" var: strict_placement_factor; //provides drop down list
	
	parameter "Station colors" category: "Simulation settings" var: selected_color_mode among:color_mode; //provides drop down list	
	parameter "Moving average window breadth" category: "Simulation settings" var: window_for_last_N_deliveries ; //window for average of last N deliveries and their cycles
	
	
	parameter "Activate stigmergy" category: "Simulation settings" var: stigmergy_activated<-true; //switch stigmergy on or off
	parameter "Activate evaporation" category: "Simulation settings" var: activate_evaporation<-false ; //switch evaopration of stigmergy on or off
	parameter "Activate negative stigmergy" category: "Simulation settings" var: activate_negative_stigmergy<-true; //window for average of last N deliveries and their cycles 
	
	parameter "Evaporation factor" category: "Simulation settings" var: evaporation_factor<-0.001 ; //switch evaopration of stigmergy on or off	
	
	parameter "Disturbance cycles" category: "Simulation settings" var: disturbance_cycles<-500#cycles; //amount of cycles until stations change their positions
	
	
	//Define attributes, actions, a init section and behaviors if necessary
	
	
	output {

	layout #split;
	 display "Shop floor display" { 
			
	 		grid shop_floor lines: #black;
	 		species transporter aspect: base;
	 		species station aspect: base;
	 		species thing aspect: base;

	 }	 
	  
	 display statistics{
			
			chart "Average steps of last "+ string(window_for_last_N_deliveries) +" transporters to correct destination" type:series size:{1 ,0.25} position:{0, 0}{
				data "Average steps of last "+ string(window_for_last_N_deliveries) +" transporters to correct destination" value: sum(moving_average_steps)/window_for_last_N_deliveries color:#darkgreen marker:false ;
			}
			
			chart "Mean cycles to deliver" type:series size:{1 ,0.5} position:{0, 0.25}{
					data "Mean of delivered cycles" value: mean_of_delivered_cycles color:#purple marker:false ;		
			}
			
			chart "Mean over last " + string(window_for_last_N_deliveries) +" deliveries" type:series size:{1 ,0.25} position:{0, 0.75}{
					data "Mean over last " + string(window_for_last_N_deliveries) +" deliveries" value: moving_average_SUM color: #red marker: false;		
			}
	 }
	
	 display delivery_information refresh: every(20#cycles){
			 
			chart "total delivered things" type: series size: {1, 0.5} position: {0,0}{				
				data "total delivered things" value: total_delivered color:#red marker:false; 

			}
			
									 
			chart "Delivery distribution" type:histogram size:{1 ,0.5} position:{0, 0.5} {
					//datalist takes a list of keys and values from the "delivered" map  
					datalist delivered.keys value: delivered.values color:delivered.keys ;
			}
		}	
	}
  
}

/*Runs an amount of simulations in parallel, keeps the seeds and gives the final values after 10k cycles*/
experiment SRA_Stigmergy_Transporter_batch type: batch until: (cycle >= 10000) repeat: 40 autorun: true keep_seed: true{
		
	parameter "Activate stigmergy" category: "Simulation settings" var: stigmergy_activated<-true; //switch stigmergy on
	parameter "Activate evaporation" category: "Simulation settings" var: activate_evaporation<-false ; //switch evaopration of stigmergy off
	parameter "Activate negative stigmergy" category: "Simulation settings" var: activate_negative_stigmergy<-true; //activate the negative feedback 
	
	parameter "Disturbance cycles" category: "Simulation settings" var: disturbance_cycles<-500#cycles; //amount of cycles until stations change their positions
	
	
	reflex save_results_explo {
    ask simulations {
    	
    	float mean_cyc_to_deliver <- ((self.total_delivered = 0) ? 0 : self.time_to_deliver_SUM/(self.total_delivered));
    	
    	save [int(self), self.seed, disturbance_cycles ,self.cycle, self.activate_negative_stigmergy, self.total_delivered, mean_cyc_to_deliver]  
          to: "result/2_SRA_Stigmergy_results.csv" type: "csv" rewrite: false header: true; 
    	}       
	}		
}

