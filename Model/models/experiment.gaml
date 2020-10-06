/**
* Name: kp
* Based on the internal empty template. 
* Author: histidine
* Tags: 
*/


model kp

import "inits.gaml"
import "fungsi.gaml"
import "reflex_global.gaml"

global {
	init {
		do init_building_type_parameters;
		do init_building_lists;
		do population_generation;
		do assign_school_work;
		do assign_major_agenda;
		do user_inputs;
		ask num_infected_init among Individual {
			status <- exposed;
		}
	}
	
	
	action user_inputs {
		map<string,unknown> values6 <- user_input("Masukkan jumlah hari yang akan disimulasikan.",[enter("Hari",60)]);
		simulation_days <- int(values6 at "Hari");
		map<string,unknown> values1 <- user_input("Masukkan jumlah individu terinfeksi di awal.",[enter("Jumlah",5)]);
		num_infected_init <- int(values1 at "Jumlah");
		map<string,unknown> values2 <- user_input("Masukkan berapa threshold jumlah pasien yang dirumahsakitkan sehingga terjadi PSBB.",[enter("Orang",3)]);
		lockdown_threshold <- int(values2 at "Orang");
		map<string,unknown> values3 <- user_input("Masukkan berapa hari terjadi penurunan konfirmasi positif sampai PSBB dilonggarkan",[enter("Hari",14)]);
		new_normal_threshold <- int(values3 at "Hari");
		map<string,unknown> values4 <- user_input("Masukkan persen akurasi tes.",[enter("(%)",100)]);
		test_accuracy <- int(values4 at "(%)")/100.0;
		map<string,unknown> values5 <- user_input("Masukkan persen efektivitas contact tracing.",[enter("(%)",100)]);
		tracing_effectivity <- int(values5 at "(%)")/100.0;
		
	}
	
	
	
	reflex stop_simulation when: (current_day = simulation_days) {
		do pause;
	}

}


experiment "Run experiment" type: gui autorun:true {
	bool allow_rewrite <- true;
	reflex output_file when: current_hour = 0 {
		// Refleks untuk mengatur data apa saja yang dioutputkan ke file .csv output.
		save [string(current_day), infections_today, positives_today, recoveries_today, deaths_today] to: "save_infeksi_positif_sembuh_meninggal_harian.csv" type:csv rewrite:allow_rewrite;
		allow_rewrite <- false;
	}
	
	string simulation_name <- "Hari " + hari_apa + " jam " + current_hour
	update: "Hari " + hari_apa + " jam " + current_hour;
	string legend <- ("Hijau: S; Jingga: E; Merah: I; Biru: R");
	output {
		layout #split consoles:false editors:false navigator:false;
		
		display chart_1 refresh:(current_hour = 0) {
			chart "Data harian" type: xy background: #white axes:#black color: #black tick_line_color: #grey {
				data "Jumlah Individu yang dinyatakan positif pada hari ini"
					value: {current_day, positives_today} color: #red line_visible:false;
				data "Jumlah Individu yang meninggal pada hari ini"
					value: {current_day, deaths_today} color: #green line_visible:false;
				data "Jumlah Individu yang sembuh pada hari ini"
					value: {current_day, recoveries_today} color: #blue line_visible:false;
			}
		}
		
		display view draw_env:false type:opengl {
			
			species Boundary aspect:geom;
			species Roads aspect:geom;
			species Building aspect:geom;
			species Individual aspect:circle;
			graphics title {
				draw simulation_name color: #black anchor: #top_center;
				draw legend color: #black anchor: #bottom_center;
			}
		}
		
		display chart_2 refresh:(current_hour = 0) {
			chart "Data total" type: xy background: #white axes:#white color: #black tick_line_color: #grey{
				data "Jumlah Individu terinfeksi dalam kenyataannya"
					value: {cycle/24, infections} color: #green marker:false;
				data "Jumlah Individu dirawat di rumah sakit, termasuk ICU"
					value: {cycle/24, hospitalizations} color: #blue marker:false;
				data "Jumlah Individu dirawat di ICU"
					value: {cycle/24, treated_ICU} color: #red marker:false;
				}
		}
		
		display chart_3 refresh:(current_hour = 0) {
			chart "Data sembuh dan meninggal" type: xy background: #white axes:#white color: #black tick_line_color: #grey{
				data "Jumlah Individu dirawat di rumah sakit, termasuk ICU"
					value: {cycle/24, hospitalizations} color: #green marker:false;
				data "Jumlah Individu yang sembuh"
					value: {cycle/24, recoveries} color: #blue marker:false;
				data "Jumlah Individu yang meninggal"
					value: {cycle/24, deaths} color: #red marker:false;
				}
		}
	}
}
