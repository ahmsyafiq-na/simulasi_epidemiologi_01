/**
* Name: kp
* Based on the internal empty template. 
* Author: histidine
* Tags: 
*/

model kp

import "inits.gaml"
import "agen.gaml"
import "parameter.gaml"

global {
	
	int individuals <- 0;
	int infections <- 0;
	int hospitalizations <- 0;
	int treated_non_ICU <- 0;
	int treated_ICU <- 0;
	int recoveries <- 0;
	int susceptibles <- 0;
	int deaths <- 0;
	int positives <- 0;
	
	int positives_today <- 0;
	int infections_today <- 0;
	int recoveries_today <- 0;
	int deaths_today <- 0;
	
	int positives_yesterday <- 0;
	
	int infections_temp <- 0;
	int recoveries_temp <- 0;
	int deaths_temp <- 0;
	
	int total_testst <- 0;
	
	int pos_decrease_counter <- 0;
	
	
	reflex update_data_1 when: current_hour = 23 {
		/*
		 * reflex untuk update data jumlah Individu terinfeksi, Individu di rumah sakit,
		 * dan lain-lain. Dilakukan pada jam 23 karena pada jam 0, data akan didisplay
		 * pada grafik di experiment.gaml.
		 */
		
		individuals <- length(Individual);
		infections <- Individual count (each.status in [exposed, infectious]);
		hospitalizations <- Individual count (each.quarantine_status in [hospital, ICU]);
		treated_non_ICU <- Individual count (each.quarantine_status = hospital);
		treated_ICU <- Individual count (each.quarantine_status = ICU);
		recoveries <- Individual count (each.status = recovered);
		susceptibles <- Individual count (each.status = susceptible);
		deaths <- num_individuals_init - length(Individual);
		
		infections_today <- Individual count (each.status in [exposed, infectious] and each.infection_time < 24);
		recoveries_today <- recoveries - recoveries_temp;
		deaths_today <- deaths - deaths_temp;
		positives_today <- Individual count (each.quarantine_status in [hospital,ICU] and each.quarantine_time < 24);
		
		// Percabangan di bawah untuk mengecek apakah terjadi penurunan
		// jumlah positif dibandingkan hari sebelumnya.
		// Penurunan berturut beberapa hari menunjukkan kualitas
		// pelayanan kesehatan/surveilans yang baik. 
		if (positives_today < positives_yesterday) {
			pos_decrease_counter <- pos_decrease_counter + 1;
		} else { // Reset counter
			pos_decrease_counter <- 0;
		}
		
		positives_yesterday <- positives_today;
		infections_temp <- infections;
		recoveries_temp <- recoveries;
		deaths_temp <- deaths;
	}	
	
	reflex enforce_lockdown when: hospitalizations >= lockdown_threshold 
	and not lockdown and not new_normal {
		/*
		 * reflex global untuk melakukan lockdown, dengan syarat total
		 * Individual yang dirumahsakitkan melebihi threshold.
		 */
		loop occupation over: individuals_per_profession.keys {
			if (occupation  in (possible_shopping + possible_offices)) {
				// Menyuruh Individual yang bekerja di tempat belanja atau kantor
				// untuk wfh pada 3 hari dari keseluruhan hari kerjanya.
				ask individuals_per_profession[occupation] {					
					int wfh_day_1 <- one_of (major_agenda_hours.keys);
					int wfh_day_2 <- one_of (major_agenda_hours.keys - wfh_day_1);
					int wfh_day_3 <- one_of (major_agenda_hours.keys - wfh_day_1 - wfh_day_2);
					int start_hour <- min(major_agenda_hours[wfh_day_1]);
					agenda_week[wfh_day_1][start_hour] <- home;
					start_hour <- min(major_agenda_hours[wfh_day_2]);
					agenda_week[wfh_day_2][start_hour] <- home;
					start_hour <- min(major_agenda_hours[wfh_day_3]);
					agenda_week[wfh_day_3][start_hour] <- home;
				}
			} else if (occupation != hospital and occupation != none) {
				// Menyuruh Individual yang bekerja di tempat selain kantor dan tempat
				// belanja, untuk wfh secara menyeluruh
				ask individuals_per_profession[occupation] {
					loop agenda_day over:agenda_week {
						int start_hour <- min(agenda_day.keys);
						agenda_day[start_hour] <- home;
					}
				}
			}
		}
		lockdown <- true;
		activity_reduction_factor <- 0.75;
		mask_usage_proportion <- 0.9;
		infection_reduction_factor <- 0.75;
	}
	reflex lift_lockdown when: pos_decrease_counter = new_normal_threshold 
	and lockdown and not new_normal {
		/*
		 * Melakukan pengangkatan lockdown ketika counter penurunan
		 * jumlah positif mencapai threshold.
		 * Tiap Individual yang bekerja tidak di rumah sakit dapat 
		 * bekerja kembali seperti biasa.
		 */
		
		loop occupation over: individuals_per_profession.keys {
			if (occupation  != none) {
				ask individuals_per_profession[occupation] {
					loop agenda_day over: agenda_week {
						int start_hour <- min(agenda_day.keys);
						agenda_day[start_hour] <- major_agenda_place;
					}
				}
			}
		}
		lockdown <- false;
		new_normal <- true;
		activity_reduction_factor <- 0.25;
		mask_usage_proportion <- 0.9;
		infection_reduction_factor <- 0.75;
	}
}
