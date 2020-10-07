/**
* Name: kp
* Based on the internal empty template. 
* Author: histidine
* Tags: 
*/


model kp

import "agen.gaml"
import "parameter.gaml"
import "reflex_global.gaml"

global {
	date cur_date <- #now;
	string cur_date_str <- replace(string(cur_date),':','-');
	int hours_elapsed <- 0 update: hours_elapsed + 1;
	int current_hour <- 0 update: (hours_elapsed) mod 24;
	int current_day_of_week <- 0 update: ((hours_elapsed) div 24) mod 7;
	string hari_apa <- int_to_day(current_day_of_week) update: int_to_day(current_day_of_week);
	int current_day <- 0 update: ((hours_elapsed) div 24);
	int previous_day <- 0;	
	
	// SHAPEFILE GIS
	
	file shp_boundary <- file("../includes/RW_Gubeng.shp");
	file shp_buildings <- file("../includes/gubengo.shp");
	geometry shape <- envelope(shp_buildings);
	file shp_roads <- file("../includes/jalan.shp");
	
	// VARIABEL TERKAIT BANGUNAN DAN AKTIVITAS
	
	map<string, list<Building>> buildings_per_activity;
	// map memetakan jenis bangunan ke semua bangunan yang sesuai.
	map<string, list<Individual>> individuals_per_profession;
	// map untuk mengelompokkan Individual dengan profesinya, ada maupun tidak.
	map<string, list<string>> activities;
	// map akan memetakan jenis aktivitas dengan bangunan yang sesuai
	list<string> possible_homes;
	// list akan diisi jenis bangunan apa saja yang dianggap sebagai rumah.
	list<Building> homes;
	// list akan diisi semua entitas Bangunan yang digolongkan rumah.
	map<list<int>,string> possible_schools;
	// map akan memetakan rentang usia dengan jenis pendidikan yang sesuai.
	map<string, float> possible_workplaces;
	// map untuk memetakan jenis pekerjaan dengan peluangnya.
	list<string> possible_offices;
	// list akan diisi dengan semua jenis bangunan yang termasuk kantor.
	list<string> possible_shopping;
	// list akan diisi dengan semua jenis bangunan yang dapat digunakan untuk belanja.
	list<string> possible_recreations;
	// list akan diisi dengan semua jenis bangunan yang menjadi tempat rekreasi.
	list<list<Individual>> families;
	//membuat map berisi ID keluarga dan list Indiviudal.
	
	//INITIAL ACTIONS
		
	action init_building_type_parameters {
	/*
	 * Action untuk load file csv berisi jenis aktivitas dan jenis bangunan.
	 * Juga digunakan untuk mengisi map activities.
	 * Juga digunakan untuk membuat entitas Boundary, Roads, dan Building.
	 */
	
		file csv_parameters <- csv_file("akt.csv",",",true);
		matrix data <- matrix(csv_parameters);
		loop i from: 0 to: data.rows-1{
			string activity_type <- data[0,i];
			list<string> bd_type;
			loop j from: 1 to: data.columns - 1 {
				if (!(data[j,i] = nil or data[j,i] = '')) {
					bd_type << data[j,i];
				}
			}
			activities[activity_type] <- bd_type;
		}
		create Boundary from: shp_boundary with: [kel:: read("is_in_vill")];
		create Roads from: shp_roads;
		create Building from: shp_buildings with: [type:: read("building") ];
	}
	
	action init_building_lists {
		/*
		 * Action untuk mengisi list dan map yang akan digunakan nantinya di action lainnya.
		 * Juga digunakan untuk membaca file csv okupasi berisi jenis pekerjaan dan peluangnya.
		 */
		
		possible_homes <- activities["staying at home"];
		possible_shopping <- ["convenience","marketplace","supermarket"];
		possible_offices <- ["bank","commercial","community_group_office","embassy","governement_office","office","police","subdistrict_office","village_office","industrial"];
		possible_recreations <- activities["recreation and working"] + activities["only recreation"];
		file csv_occupations <- csv_file("okupasi.csv",",",true);
		matrix data <- matrix(csv_occupations);
		loop i from: 0 to: data.rows-1 {
			string occupation <- data[0,i];
			float weight <- float(data[1,i]);
			possible_workplaces << occupation::weight;
		}
		possible_schools <- [[4,5]::"tk", [6,11]::"sd", [12,14]::"smp", [15,17]::"sma", [18,24]::"college"];
		buildings_per_activity <- Building group_by (each.type);
		homes <- Building where (each.type in possible_homes);
		ask homes {
			ask Boundary {
				if (myself overlaps self) {
					homes_at_rw << myself;
				}
			}
		}
	}
	
	action population_generation {
	/*
	 * Action untuk membuat populasi entitas Individual.
	 * Melibatkan penentuan bangunan rekreasi. Tiap anggota keluarga memiliki jenis rekreasi persis.
	 * Kemudian keluarga dibentuk dengan probabilitas-probabilitas di parameters.gaml.
	 * Dalam action ini ditentukan atribut-atribut seperti usia, jenis kelamin, komorbiditas, rumah,
	 * dan bangunan rekreasi.
	 */
		
		
		ask num_homes among homes {	
			
			
			/*
			 * Dilakukan dengan pertama-tama memilih
			 * entitas Bangunan rumah secara random, kemudian memilih 3 bangunan untuk rekreasi, 
			 * 1 bangunan untuk belanja, dan memilih rumah-rumah lain yang berada dalam radius tertentu,
			 * untuk dijadikan tetangga. Semua bangunan digabung dalam list minor_buildings_temp.
			 */
			list<Building> minor_buildings_temp <- [];
			loop times: 3 {
				string recreation <- one_of(possible_recreations);
				minor_buildings_temp << one_of(buildings_per_activity[recreation]);
			}
			string shopping <- one_of (possible_shopping);
			minor_buildings_temp << one_of (buildings_per_activity[shopping]);
			list<Building> neighbors;
			ask Boundary {
				if (myself overlaps self) {
					neighbors <- homes_at_rw at_distance 25;
				}
			}
			loop b over:neighbors {minor_buildings_temp << b;}
			
			
			
			if (flip(proba_active_family)) {
				// Keluarga aktif didefinisikan sebagai keluarga yang setidaknya ada ayah dan ibu.
				
				create Individual {
					age <- rnd(min_working_age,max_working_age);
					sex <- 1;
					home <- myself;
					myself.residents << self;
					recreation_buildings <- minor_buildings_temp;
				}
				
				create Individual {
					age <- rnd(min_working_age,max_working_age);
					sex <- 0;
					home <- myself;
					myself.residents << self;
					recreation_buildings <- minor_buildings_temp;
				}
				
				int num_children <- rnd(0,max_num_children);
				loop times: num_children {
					create Individual {
						age <- rnd(min_age,max_student_age);
						sex <- rnd(0,1);
						home <- myself;
						myself.residents << self;
						recreation_buildings <- minor_buildings_temp;
					}
				}
				
				if (flip(proba_grandfather)) {
					create Individual {
						age <- rnd(max_working_age+1,max_age);
						sex <- 1;
						home <- myself;
						myself.residents << self;
						recreation_buildings <- minor_buildings_temp;
					}
				}
				
				if(flip(proba_grandmother)) {
					create Individual {
						age <- rnd(max_working_age+1,max_age);
						sex <- 0;
						home <- myself;
						myself.residents << self;
						recreation_buildings <- minor_buildings_temp;
					}
				}
				
				if(flip(proba_rewang)) {
					create Individual {
						age <- rnd(min_working_age,max_working_age);
						sex <- rnd(0,1);
						home <- myself;
						myself.residents << self;
						recreation_buildings <- minor_buildings_temp;
					}
				}
				
			} else {
				// Individual yang tinggal sendirian
				
				create Individual {
					age <- rnd(min_working_age,max_age);
					sex <- rnd(0,1);
					home <- myself;
					myself.residents << self;
					recreation_buildings <- minor_buildings_temp;
				}
			}			
		}
		num_individuals_init <- length (Individual);
	}

	action assign_school_work {
		/*
		 * action untuk meng-assign jenis dan lokasi sekolah/kerja (tapi bukan agendanya)
		 * Sekolah yang sesuai dengan usia dipilih berdasarkan kedekatan (asumsikan zonasi).
		 * major_agenda_type akan berisi jenis pekerjaan, atau "sekolah", atau "none".
		 */
		
		ask Individual {
			do enter_building(home);
			if (age >= min_student_age and age <= max_student_age) {
				list<int> L <- match_age(possible_schools.keys);
				string temp <- possible_schools[L];
				list<Building> schools <- buildings_per_activity[temp];
				major_agenda_place <- schools closest_to self;
				major_agenda_place.residents << self;
				major_agenda_type <- "school";
			} else if (age >= min_working_age and age <= max_working_age) {
				bool is_employed;
				if (sex=1) {
					is_employed <- flip(proba_employed_male);
				} else {
					is_employed <- flip(proba_employed_female);
				}
				if (is_employed) {
					if (flip(proba_works_at_home)) {
						// Memperhitungkan kemungkinan orang yang memang kerjanya
						// dari rumah.
						
						major_agenda_place <- home;
						major_agenda_type <- "swasta";
					} else {
						major_agenda_type <- rnd_choice(possible_workplaces);
						list<Building> working_places;
						if (major_agenda_type = "guru") {
							string school_type <- one_of(possible_schools.values);
							working_places <- buildings_per_activity[school_type];
	
						} else {
							working_places <- buildings_per_activity[major_agenda_type];
						}
						major_agenda_place <- one_of(working_places);
						major_agenda_place.residents << self;
					}
				} else {
					major_agenda_type <- "none";
				}
			} else {
				major_agenda_type <- "none";
			}
		}
		individuals_per_profession <- (Individual group_by (each.major_agenda_type));
	}
	
	action assign_major_agenda {
		/*
		 * action untuk menambahkan agenda sekolah/kerja sesuai dengan yang sudah
		 * di-assign di action sebelumnya. Atribut Individual yang diisi adalah
		 * agenda_week.
		 * 
		 */
		
		ask Individual {
			loop i from: 0 to: 6 {
				agenda_week << [];
			}
			if (major_agenda_type = "school") {
				loop L over: possible_schools.keys {
					if (age >= min(L) and age <= max(L)) {
						string temp <- possible_schools[L];
						loop d over: [0,1,2,3,4] {
							int start_hour;
							int end_hour;
							
							// Penentuan jam masuk dan pulang untuk setiap jenis sekolah.
							switch temp {
								match "tk" {
									start_hour <- 7;
									end_hour <- 10;
								}
								match "sd" {
									start_hour <- 7;
									end_hour <- 13;
								}
								match "smp" {
									start_hour <- 7;
									end_hour <- 15;
								}
								match "sma" {
									start_hour <- 7;
									end_hour <- 15;
								}
								match "college" {
									start_hour <- rnd(7,10);
									end_hour <- rnd(14,18);
								}
							}
							major_agenda_hours[d] <- [start_hour, end_hour];
							(agenda_week[d])[start_hour] <- self.major_agenda_place;
							(agenda_week[d])[end_hour] <- self.home;
							
						}
					}
				}
			} else if (!(major_agenda_type in ["none", "school"])) {
				// Penetapan jam kerja dan pulang.
				
				if (major_agenda_type in possible_offices) {
					// Untuk yang bekerja di kantor, maka hari kerjanya 0-4
					// yakni hari Senin-Jumat.
					
					loop d over: [0,1,2,3,4] {
						int start_hour <- rnd(7,10);
						int end_hour <- rnd(15,19);
						major_agenda_hours[d] <- [start_hour, end_hour];
						agenda_week[d][start_hour] <- self.major_agenda_place;
						agenda_week[d][end_hour] <- self.home;
					}
					
				} else if (major_agenda_type != none) {
					// Untuk yang bekerja di selain kantor, hari kerja acak.
					list<int> working_days <- [];
					loop i over: [0,1,2,3,4,5,6] {
						working_days << i;
					}
					
					// Sebanyak 3 hari kerja dibuang secara random dari semua
					// hari yang mungkin (0-6)
					int i <- one_of(working_days);
					working_days >> i;
					i <- one_of(working_days);
					working_days >> i;
					i <- one_of(working_days);
					working_days >> i;
					
					// Penetapan jam kerja dan pulang
					loop d over: working_days {
						int start_hour <- rnd (7,10);
						int end_hour <- rnd(16,21);
						major_agenda_hours[d] <- [start_hour, end_hour];
						(agenda_week[d])[start_hour] <- self.major_agenda_place;
						(agenda_week[d])[end_hour] <- self.home;
					}
				}
			}
		}
	}
	
	
	
	
}
