/**
* Name: entities
* Based on the internal empty template. 
* Author: histidine
* Tags: 
*/

model kp

import "inits.gaml"
import "parameter.gaml"
import "fungsi.gaml"

species Individual {
	
	// -------------------------- //
	// ATRIBUT-ATRIBUT INDIVIDUAL //
	// -------------------------- //
	// ATRIBUT UMUM
	int age;
	int sex;
	Building current_place;
	Building home;
	list<map<int, Building>> agenda_week; // Memetakan jam dengan agenda sekolah/kerja
	string major_agenda_type; // string jenis profesi atau sekolah
	Building major_agenda_place; // Entitas Building tempat kerja/sekolah
	map<int,list<int>> major_agenda_hours; // map memetakan hari dengan jam kerja/sekolah
	list<Building> recreation_buildings <- []; // list entitas Building sebagai rekreasi
	
	// ATRIBUT EPIDEMIK
	//int num_comorbidities <- 0;
	string status <- susceptible; // Opsi: susceptible, exposed, infectious, recovered
	string quarantine_status <- none; // Opsi: none, home, hospital, ICU
	string severity <- none; // Opsi: none (asymptomatic), mild, moderate, severe, deadly
	bool must_test <- false;
	int infection_time <- 0; // Waktu sejak infeksi (jam)
	int quarantine_time <- 0; // Waktu sejak karantina (jam)
	int death_recovery_time <- 0; // Waktu hingga kematian/ sembuh (jam)
	int incubation_period; // Periode inkubasi (jam)
	int serial_interval; // Serial Interval (jam)
	
	
	// ------------------------ //
	// ACTION DAN FUNGSI-FUNGSI //
	// ------------------------ //
	
	action enter_building(Building b) {
		// Digunakan pada beberapa reflex untuk masuk ke dalam bangunan.
		// Melibatkan update atribut Individuals_inside milik bangunan.
		
		if (current_place != nil) {
			current_place.Individuals_inside >> self;
		}
		current_place <- b;
		current_place.Individuals_inside << self;
		location <- any_location_in (current_place);
	}
	
	action assign_agenda(list<int> the_time) {
		// Mengacak jam memulai agenda kecil melalui 2 variabel: start dan end.
		// Terdapat percabangan untuk mengakomodasi keadaan lockdown dan tidak lockdown.
		
		int start <- rnd((min(the_time)),(max(the_time)-1));
		int end <- rnd(start+1,max(the_time));
		
		if (not lockdown) {
			agenda_week[current_day_of_week][start] <- one_of (recreation_buildings);
			agenda_week[current_day_of_week][end] <- home;
		} else { // lockdown
			Building temp <- one_of (recreation_buildings);
			if (temp.type in possible_shopping) {
				// Pada keadaan lockdown, aktivitas hanya berhasil direncanakan
				// apabila pengacakan bangunan menghasilkan bangunan yang merupakan
				// tempat belanja.
				
				agenda_week[current_day_of_week][start] <- temp;
				agenda_week[current_day_of_week][end] <- home;
			}
		}
	}
	
	action init_infection {
		 /* Action untuk mengawali infeksi, dengan menetapkan variabel-variabel
		 * yang terkait dengan infeksi: periode inkubasi, serial interval, 
		 * tingkat keparahan penyakit, dan waktu hingga sembuh / meninggal.
		 */
		
		incubation_period <- int(24*get_proba(incubation_distribution,"lognormal"));
		serial_interval <- int(24*get_proba(serial_distribution,"gamma"));
		
		// Menentukan apakah simptomatik atau asimptomatik.
		list<int> l <- match_age(clinical_fraction.keys);
		float proba_symptomatic <- get_proba(clinical_fraction[l],"normal");
		bool is_symptomatic <- flip(proba_symptomatic);
		
		// Menentukan probabilitas masuk rumah sakit (apabila simptomatik),
		// jika masuk rumah sakit berarti keparahannya sedang. Jika tidak,
		// keparahannya ringan.
		l <- match_age(prop_hospitalization.keys);
		float proba_hospitalization <- prop_hospitalization[l];
		bool is_hospitalized <- flip(proba_hospitalization/proba_symptomatic);
		
		// Menentukan probabilitas masuk ICU (apabila masuk rumah sakit),
		// yang berarti keparahannya tinggi.
		l <- match_age(prop_ICU.keys);
		float proba_ICU <- prop_ICU[l];
		bool is_ICUed <- flip(proba_ICU/proba_hospitalization);
		
		// Menentukan probabilitas kematian (apabila masuk ICU), yang berarti
		// keparahannya sangat tinggi (deadly).
		l <- match_age(prop_fatality.keys);
		float proba_fatal <- prop_fatality[l];
		bool is_fatal <- (proba_ICU = 0) ? false : flip(proba_fatal/proba_ICU);
		
		// Menentukan tingkat keparahan: asimptomatik, ringan, sedang, tinggi,
		// atau sangat tinggi, berdasarkan probabilitas simptomatik,
		// probabilitas masuk rumah sakit, probabilitas masuk ICU, serta
		// probabilitas kematian.
		if (is_symptomatic) {
			if (is_hospitalized) {
				if (is_ICUed) {
					if (is_fatal) {
						severity <- deadly;
					} else {
						severity <- severe;
					}
				} else {
					severity <- moderate;
				}
			} else {
				severity <- mild;
			}
		} else {
			severity <- none;
		}
		
		// Menentukan waktu (jam) hingga kematian atau sembuh, berdasarkan proporsi
		// yang ditentukan pada parameters.gaml
		l <- match_age(days_symptom_until_recovered.keys);
		death_recovery_time <- int(24*get_proba(days_symptom_until_recovered[l], "normal")) + incubation_period;
		
	}
	
	action contact_trace {
		 /* Action untuk melakukan contact tracing pada keluarga dan teman kerja
		 * dari seorang Individual yang dinyatakan positif terinfeksi oleh
		 * rumah sakit.
		 * Kontak-kontak yang dimaksud akan diubah di variabel must_test
		 * menjadi bernilai true.
		 */
		
		// Mengisi contacts dengan anggota keluarga dan teman kerja.
		list<Individual> contacts <- self.home.residents - self;
			
		if (not (major_agenda_type in ["none", "swasta"])) {
			contacts <- contacts + self.major_agenda_place.residents - self;
		}
		
		// Menentukan jumlah kontak yang gagal di-trace, berdasarkan tracing effectivity.
		int num_contacts_untraced <- round((1-tracing_effectivity)*length(contacts));
		loop times: num_contacts_untraced {
			contacts >> one_of(contacts);
		}
		
		// Mengubah status karantina Individu menjadi karantina mandiri.
		// Status bisa berubah jika Individu terinfeksi dan simptomatik,
		// dan sudah melewati periode inkubasi (reflex during_infection)
		if (contacts != []) {
			ask contacts {
				if (quarantine_status = none) {
					quarantine_status <- "home";
				}
			}
		}
	}
	
	bool check_free(list<int> the_time) {
		/*
		 * Fungsi untuk menentukan apakah pada pagi, siang, sore, atau malam
		 * hari terdapat waktu kosong. Hal ini dicek melalui atribut
		 * major_agenda_hours yang berisi jam masuk kerja/sekolah dan
		 * jam pulangnya.
		 */
		
		list<int> start_end_hours <- major_agenda_hours[current_day_of_week];
		if ((min(start_end_hours) > max(the_time)) or (max(start_end_hours) < min(the_time))) {
			return true;
		} else {
			return false;
		}
	}
	
	list<int> match_age (list<list<int>> the_list) {
		/*
		 * Fungsi untuk mencocokkan atribut usia Individu dengan list<list<int>>.
		 */
		loop l over: the_list {
			if (age >= min(l) and age <= max(l)) {
				return l;
			}
		}
	}
	
	float get_proba(list<float> proba, string method) {
		/*
		 * Fungsi untuk memudahkan memanggil fungsi built-in
		 * untuk menentukan probabilitas dari distribusi.
		 */
		
		switch method {
			match "lognormal" {
				return lognormal_rnd(proba[0],proba[1]);
			}
			match "normal" {
				return gauss_rnd(proba[0],proba[1]);
			}
			match "gamma" {
				return gamma_rnd(proba[0],proba[1]);
			}
		}
	}
	
	// ------------------------ //
	// REFLEX-REFLEX INDIVIDUAL //
	// ------------------------ //
	
	reflex execute_agenda when: (quarantine_status = none) {
		/*
		 * Reflex untuk menjalankan apapun agenda pada hari itu, agenda besar maupun kecil.
		 * Mempergunakan action enter_building.
		 */
		 
		map<int, Building> agenda_day <- agenda_week[current_day_of_week];
		if (agenda_day[current_hour] != nil) {
			do enter_building(agenda_day[current_hour]);
		}
	}
	
	reflex minor_agenda when: ((current_hour = 2) and (quarantine_status = none) and age >= min_student_age and age <= max_age) {
		/*
		 * Reflex untuk menetapkan agenda kecil setiap hari pukul 2 untuk menghindari bentrok jadwal.
		 * action check_free dan assign_agenda digunakan di sini.
		 * Digunakan loop untuk menelusur time_of_day yang merupakan list<list<int>>
		 * berisi kapan saja waktu pagi, siang, sore, dan malam.
		 * Agenda pagi, siang, sore, dan malam ditentukan dalam sekali jalan.
		 * Agenda kecil yang berhasil ditentukan akan mempengaruhi atribut agenda_week.
		 */
		
		bool is_free;
		float proba_activity;
		loop Time from: 0 to: length(time_of_day)-1 {
			if (check_free(time_of_day[Time])) {
				proba_activity <- proba_activities[Time] * (1-activity_reduction_factor);
				if (flip(proba_activity)) {
					do assign_agenda(time_of_day[Time]);
				}
			}
		}		
	}
	
	reflex remove_minor_agenda when: current_hour = 23 {
		/*
		 * Menghapus bekas agenda kecil pada atribut agenda_week sehingga
		 * setiap hari akan ada variasi agenda kecil yang berbeda, yang
		 * ditentukan reflex minor_agenda.
		 */
		
		map<int, Building> agenda_day <- agenda_week[current_day_of_week];
		if (major_agenda_hours[current_day_of_week] != nil) {
			loop agenda over: agenda_day.keys {
				if (not (agenda in major_agenda_hours[current_day_of_week])) {
					remove key:agenda from: agenda_day;
				}
			}
		} else {
			loop agenda over: agenda_day.keys {
				remove key:agenda from: agenda_day;
			}
		}
	}
	 
	
	
	reflex infect_myself when: (status = susceptible and quarantine_status in ["home", none]) {
		/*
		 * Reflex menginfeksi diri sendiri jika statusnya susceptible dan sedang tidak
		 * di rumah sakit atau ICU. Kemungkinan infeksi dipengaruhi susceptibility, proporsi
		 * orang yang berstatus infectious, penggunaan masker, dan faktor reduksi lainnya.
		 */
		
		list<Individual> people_inside <- current_place.Individuals_inside where (not dead(each));
		int num_people <- length(people_inside - self);
		int num_infected <- length(people_inside where (each.quarantine_status = none and each.status = infectious));
		
		// Individu yang sedang dikarantina tetap mungkin untuk menginfeksi Individu susceptible.
		int num_quarantined <- length(people_inside where (each.quarantine_status != none and each.status = infectious));
		
		float mask_factor <- 1 - mask_effectiveness*mask_usage_proportion;
		
		float proba <- 0.0;
		if(num_people > 0) {
			
			// Individu yang dikarantina memiliki kemungkinan lebih kecil untuk menginfeksi.
			// Hal itu dipastikan oleh proportion_quarantined_transmission.
			float infection_proportion <- (num_infected+proportion_quarantined_transmission*num_quarantined)/num_people;
			list<int> l <- match_age(susceptibility.keys);
			proba <- get_proba(susceptibility[l],"normal");
			proba <- proba * infection_proportion * mask_factor * (1-infection_reduction_factor);
		}
		if (flip(proba)) {
			status <- exposed;
		}
	}

	reflex update_infection when: (status in [exposed, infectious]) {
		/*
		 * Update atribut infection_time untuk Individual exposed dan infectious.
		 * infection_time akan dibandingkan dengan periode inkubasi, serial interval,
		 * serta recovery time.
		 */
		
		if (infection_time = 0) {
			do init_infection;
			infection_time <- infection_time + 1;
		} else {
			infection_time <- infection_time + 1;
			if (infection_time = serial_interval) {
				status <- infectious;
			}
			
			// Jika waktu infeksi sudah mencapai periode inkubasi, maka gejala muncul
			// (untuk yang simptomatik).
			// Diasumsikan ketika gejala muncul, Individual diharuskan/berniat untuk tes.
			if (infection_time = incubation_period and severity != none and quarantine_status in [none, "home"]) {
				must_test <- true;
			}
			
			// Recovery dan kematian
			if (infection_time  >= death_recovery_time) {
				if (severity = deadly) {
					current_place >> self;
					do die;
				} else {
					status <- recovered;
					infection_time <- 0;
				}
				
			}
		}
	}
	

	
/*
* Individu akan melakukan tes dengan syarat must_test = true atau karena keinginan atau random.
* must_test true jika memiliki gejala.
* Tes karena keinginan/random menurut proba_voluntary_random_test (parameters.gaml)
* 
* Mekanisme tes dibagi menjadi dua.
* Yakni ketika penerima tes memang sudah terinfeksi penyakit, dan ketika penerima tidak terinfeksi.
* Untuk yang sudah terinfeksi penyakit, terdapat dua kemungkinan: True Positive dan False Negative.
* Untuk yang tidak terinfeksi, terdapat dua kemungkinan: True Negative dan False Positive.
* Individu yang tes karena gejala (suspek, probabel) sudah pasti terinfeksi.
* Individu yang tes karena keinginan/random belum pasti terinfeksi.
* 
*/
	reflex take_test when: ((current_hour = 6) and ((must_test and flip(proba_test)) or (flip(proba_voluntary_random_test) and status != recovered and quarantine_status = none)) ) {
		
		
		Building the_hospital <- one_of (buildings_per_activity["hospital"]);
		do enter_building(the_hospital);
		
		//Jika statusnya memang terinfeksi (exposed atau infectious)
		if (status in [exposed, infectious]) {
			float proba <- sensitivity_pcr * test_accuracy;
			bool positive_result <- flip(proba);
			
			// Jika True Positive
			if (positive_result) {
				
				// Penentuan tempat perawatan
				switch severity {
					match mild {
						quarantine_status <- hospital;
					}
					match moderate {
						quarantine_status <- hospital;
					}
					match severe {
						quarantine_status <- ICU;
					}
					match deadly {
						quarantine_status <- ICU;
					}
					match none {
						quarantine_status <- hospital;
					}
				}
				
				// Reset waktu karantina. Berguna untuk kasus orang yang sebelum ini lakukan karantina mandiri di rumah.
				quarantine_time <- 0;
				
				do contact_trace;
				must_test <- false;
			} else {
				// Jika False Negative, dipulangkan tapi must_test tidak dijadikan false.
				// Dengan tujuan Individual ini akan mengambil tes lagi keesokan hari.
				
				quarantine_status <- none;
				do enter_building(home);
			}
		
		// Jika sebenarnya tidak infeksi (susceptible, recovered)	
		} else {
			float proba <- specificity_pcr * test_accuracy;
			if (flip(proba)) {
				
				// Jika True Negative, dipulangkan.
				quarantine_status <- none;
				do enter_building(home);
				must_test <- false;
			} else {
				
				// Jika False Positive
				quarantine_status <- hospital;
				do contact_trace;
				death_recovery_time <- 24 * 14;
				quarantine_time <- 0;
				must_test <- false;
			}
		}
	}
	
	reflex update_quarantine when: (quarantine_status in ["home", hospital, ICU]) {
		/* 
		 * Reflex untuk tracking waktu karantina. Jika sudah recovered, Individual akan
		 * dilepas dari karantina atau mati. Atau jika sebenarnya tidak terinfeksi tapi
		 * masuk rumah sakit (false positive), dikeluarkan setelah 14 hari.
		 */
		quarantine_time <- quarantine_time + 1; 
		if (status = recovered) {
			quarantine_status <- none;
			quarantine_time <- 0;
			do enter_building(home);
		} else if (status in [susceptible, recovered]) {
			if (quarantine_time > (24 * 14)) {
				quarantine_status <- none;
				quarantine_time <- 0;
			}
		} 
				
	}
	
	
	
	aspect circle {
		if (status = exposed) {
			draw circle(8) color: #orange;
		} else if (status = infectious) {
			draw circle(8) color: #red;
		} else if (status = susceptible) {
			draw circle(8) color: #green;
		} else {
			draw circle(8) color: #blue;
		}
		highlight self color: #yellow;
	}
}

species Building {
	int ch <- 0 update: current_hour;
	string type;
	list<Individual> Individuals_inside;
	list<Individual> residents;
	aspect geom {
		draw shape color: #lightcoral;
		highlight self color: #yellow;
	}
}

species Boundary {
	string kel;
	list<Building> homes_at_rw;
	aspect geom {
		draw shape color: #turquoise;
	}
}

species Roads {
	aspect geom {
		draw shape color: #orange;
	}
}