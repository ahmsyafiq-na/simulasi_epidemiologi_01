/**
* Name: kp
* Based on the internal empty template. 
* Author: histidine
* Tags: 
*/


model kp

import "parameter.gaml"

global {
	
	string int_to_day (int x) {
		string str;
		switch x {
			match 0 {str <- "Senin";}
			match 1 {str <- "Selasa";}
			match 2 {str <- "Rabu";}
			match 3 {str <- "Kamis";}
			match 4 {str <- "Jumat";}
			match 5 {str <- "Sabtu";}
			match 6 {str <- "Minggu";}
		}
		if (lockdown) {
			str <- str + " (PSBB)";
		}
		if (new_normal) {
			str <- str + " (NEW_NORMAL)";
		}
		return str;
	}
	
}