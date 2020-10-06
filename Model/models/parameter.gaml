/**
* Name: parameters
* Based on the internal empty template. 
* Author: histidine
* Tags: 
*/


model kp

global {
	//SIMULATION PARAMETERS
	int num_infected_init;
	int lockdown_threshold;
	bool lockdown <- false;
	bool new_normal <- false;
	float test_accuracy;
	float tracing_effectivity;
	float obedience <- 0.8;
	int new_normal_threshold;
	int num_homes <- 7500;
	int num_individuals_init;
	int simulation_days;
	
	//DEMOGRAPHICAL PARAMETERS
	float proba_active_family <- 0.9;
	float proba_employed_male <- 0.81;
	float proba_employed_female <- 0.56;
	float proba_works_at_home <- 0.1;
	int max_num_children <- 2;
	float proba_grandfather <- 0.175;
	float proba_grandmother <- 0.175;
	float proba_rewang <- 0.25;
	float proba_high_eco_status <- 0.5;
	
	int min_age <- 1;
	int min_student_age <- 4;
	int max_student_age <- 24;
	int min_working_age <- 25;
	int max_working_age <- 59;
	int max_age <- 90;
	
	//TIME DIVISION
	list<int> morning <- [7,8,9,10];
	list<int> daytime <- [11,12,13,14];
	list<int> evening <- [15,16,17,18];
	list<int> night <- [19,20,21,22];
	list<list<int>> time_of_day <- [morning, daytime, evening, night];
	
	//EPIDEMIOLOGICAL PARAMETERS
	list<string> states <- [
		"susceptible", "exposed", "infectious", "recovered"
	];
	list<string> disease_severity <- [
		"none", "mild", "moderate", "severe", "deadly"
	];
	
	map<list<int>,list<float>> clinical_fraction <- [
		/*
		 * Tipe data berbentuk map, yang memetakan rentang usia
		 * dengan parameter distribusi probabilitas.
		 */
		 
		[1,9]::[0.29,0.059],
		[10,19]::[0.205,0.052],
		[20,29]::[0.265,0.052],
		[30,39]::[0.325,0.052],
		[40,49]::[0.4,0.059],
		[50,59]::[0.49,0.059],
		[60,69]::[0.645,0.067],
		[70,90]::[0.695,0.067]
	];
	list<float> incubation_distribution <- [1.57,0.65]; // Tipe data berbentuk list, berisi parameter distribusi probabilitas.
	list<float> serial_distribution <- [2.29,0.36]; // Tipe data berbentuk list, berisi parameter distribusi probabilitas.
	map<list<int>,list<float>> susceptibility <- [
		/*
		 * Tipe data berbentuk map, yang memetakan rentang usia
		 * dengan parameter distribusi probabilitas.
		 */
		 
		[1,9]::[0.395,0.082],
		[10,19]::[0.375,0.067],
		[20,29]::[0.79,0.104],
		[30,39]::[0.865,0.082],
		[40,49]::[0.8,0.089],
		[50,59]::[0.82,0.089],
		[60,69]::[0.88,0.074],
		[70,90]::[0.74,0.089]
	];
	float sensitivity_pcr <- 1.0;
	float specificity_pcr <- 1.0;
	map<list<int>,float> prop_hospitalization <- [
		/*
		 * Tipe data berbentuk map, yang memetakan rentang usia
		 * dengan parameter distribusi probabilitas.
		 */
		 
		[1,19]::0.025,
		[20,44]::0.208,
		[45,54]::0.283,
		[55,64]::0.301,
		[65,74]::0.435,
		[75,84]::0.587,
		[85,90]::0.703
	];
	map<list<int>,float> prop_ICU <- [
		/*
		 * Tipe data berbentuk map, yang memetakan rentang usia
		 * dengan parameter distribusi probabilitas.
		 */
		 
		[1,19]::0,
		[20,44]::0.042,
		[45,54]::0.104,
		[55,64]::0.112,
		[65,74]::0.188,
		[75,84]::0.31,
		[85,90]::0.29
	];
	map<list<int>,float> prop_fatality <- [
		/*
		 * Tipe data berbentuk map, yang memetakan rentang usia
		 * dengan parameter distribusi probabilitas.
		 */
		 
		[1,19]::0,
		[20,44]::0.002,
		[45,54]::0.008,
		[55,64]::0.026,
		[65,74]::0.049,
		[75,84]::0.105,
		[85,90]::0.273
	];
	map<list<int>, list<float>> days_symptom_until_recovered <- [
		/*
		 * Tipe data berbentuk map, yang memetakan rentang usia
		 * dengan parameter distribusi probabilitas.
		 */
		 
		[1,9]::[17.65,1.2],
		[10,19]::[19.35,1.81],
		[20,29]::[19.25,0.89],
		[30,39]::[19.25,0.64],
		[40,49]::[21.7,0.87],
		[50,59]::[22.45,0.84],
		[60,69]::[22.95,0.89],
		[70,90]::[24.4,0.97]
	];
	
	//BEHAVIORAL PARAMETERS
	float proba_voluntary_random_test <- 0.05;
	float proba_test <- 0.95;
	float proba_activity_morning <-0.15;
	float proba_activity_daytime <-0.25;
	float proba_activity_evening <-0.325;
	float proba_activity_night <-0.05;
	list<float> proba_activities <- [
		proba_activity_morning,
		proba_activity_daytime,
		proba_activity_evening,
		proba_activity_night
	];
	float activity_reduction_factor <- 0.0;
	float mask_effectiveness <- 0.8;
	float mask_usage_proportion <- 0.75;
	float infection_reduction_factor <- 0.0;
	float proportion_quarantined_transmission <- 0.1;
	
	//STRING CONSTANTS
	string susceptible <- "susceptible";
	string exposed <- "exposed";
	string infectious <- "infectious";
	string recovered <- "recovered";
	string home <- "home";
	string none <- "none";
	string hospital <- "hospital";
	string ICU <- "ICU";
	string mild <- "mild";
	string moderate <- "moderate";
	string severe <- "severe";
	string deadly <- "deadly";
	
}

