/*********************************************************************************************/
title1 'Cohort Analysis';

* Author: PF;
* Purpose: Run models with the additional covariate for CCI;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/
options obs=max;
proc format;
	value mortalitycat
		1="survived"
		2="died"
		3="left samp";
	value dxcat
		1="unspec"
		2="nonad"
		3="ad";
	value $raceft
		"0"="3. Unknown"
		"1"="1. Non-Hispanic White"
		"2"="5. Black"
		"3"="2. Other"
		"4"="6. Asian/Pacific Islander"
		"5"="4. Hispanic"
		"6"="7. American Indian/Alaska Native"
		"7"="8. All Races";
	value $sexft
		"1"="Male"
		"2"="Female";
	value agegroup
		67-<76 = "1. <=75"
		76-<81  = "2. 76-80"
		81-<86 = "3. 81-85"
		86-high = "4. 86+";
run;

* Export macro;
%macro exportannual(data);
proc export data=&tempwork..&data.
	outfile="&rootpath./Projects/Programs/mortality/exports/mortality01_annual_models_allrace_ccisq.xlsx"
	dbms=xlsx 
	replace;
	sheet="&data.";
run;
%mend;

ods graphics on;
data covs;
format race_bg $raceft. sex $sexft.;
input race_bg age_begdx age_begdx_sq sex cc_diab cc_hyperl cc_hyp cc_str cc_ami cc_atf
dual  charlson charlsonsq lis;
datalines;
0 82 6724 2 1 1 1 0 0 0 0 0 1 1 0
1 82 6724 2 1 1 1 0 0 0 0 0 1 1 0
2 82 6724 2 1 1 1 0 0 0 0 0 1 1 0
3 82 6724 2 1 1 1 0 0 0 0 0 1 1 0
4 82 6724 2 1 1 1 0 0 0 0 0 1 1 0
5 82 6724 2 1 1 1 0 0 0 0 0 1 1 0
6 82 6724 2 1 1 1 0 0 0 0 0 1 1 0
;
run;

ods graphics on;
%macro annual_cci(startyr,endyr);
%do yr=&startyr. %to &endyr;
	
	data &tempwork..cohort_5yrsurvival&yr._cci;
		merge mort.cohort_5yrsurvival_allrace&yr. (in=a) mort.cci_2001_2013_otherrace (in=b keep=bene_id charlson);
		by bene_id;
		if a;
		if charlson=. then charlson=0;
		charlsonsq=charlson*charlson;
	run;

	proc means data=&tempwork..cohort_5yrsurvival&yr._cci noprint;
		class race_bg;
		var charlson;
		output out=&tempwork..stats_byrace&yr._cci mean()= p25()= p50()= p75()= median()= / autoname;
	run;

	* By race adjusting for age, cmd, dual/lis, charlson;
	ods output parameterestimates=&tempwork..byrace_ccisq&yr.;
	proc phreg data = &tempwork..cohort_5yrsurvival&yr._cci plots(overlay)=(survival);
		where follow_type ne "leavesamp";
		format race_bg $raceft.sex $sexft.;
		class race_bg (desc) sex (desc) cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
		cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) 
		%if &yr.>=2006 %then lis(desc);;
		model mortality*censor(1) = race_bg age_begdx age_begdx_sq sex cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual 
		%if &yr.>=2006 %then lis; 
		charlson charlsonsq / risklimit;
		baseline covariates=covs out=&tempwork..survival_cci&yr. survival=s lower=s_lower upper=s_upper/ rowid=race_bg;
	run;

	%exportannual(byrace_ccisq&yr.);

%end;
%mend;

%annual_cci(2001,2013);

%macro annual_state(startyr,endyr);
%do yr=&startyr. %to &endyr;

	data &tempwork..cohort_5yrsurvival&yr._cci;
		merge mort.cohort_5yrsurvival_allrace&yr. (in=a) mort.cci_2001_2013 (in=b keep=bene_id charlson);
		by bene_id;
		if a;
		if charlson=. then charlson=0;
	run;

	* By race adjusting for age, cmd, dual/lis, charlson, state;
	data &tempwork..cohort_5yrsurvival&yr._state;
		set &tempwork..cohort_5yrsurvival&yr._cci;
		* california will be st01 so that it will be ommitted;
		stcd=state_code*1;
		array st [*] st1-st51;
		do i=1 to 51;
			st[i]=0;
		end;
		if stcd=5 then st1=1;
		do i=1 to 4;
			if stcd=i then st[i+1]=1;	
		end;
		do i=6 to 8;
			if stcd=i then st[i]=1;
		end;
		do i=10 to 39;
			if stcd=i then st[i-1]=1;
		end;
		do i=41 to 47;
			if stcd=i then st[i-2]=1;
		end;
		do i=49 to 53;
			if stcd=i then st[i-3]=1;
		end;
		if stcd in(.,9,40,48,54,55,56,57,58,59,60,61,62,63,97,98,99) then st51=1;
	run;

%macro annual_state(byear,eyear);
%do yr=&byear. %to &eyear.;
	ods output parameterestimates=&tempwork..byrace_state&yr.;
	proc phreg data = &tempwork..cohort_5yrsurvival&yr._state;
		where follow_type ne "leavesamp";
		format race_bg $raceft.sex $sexft.;
		class race_bg (desc) sex cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
		cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) 
		%do i=2 %to 51; st&i. (desc) %end;
		%if &yr.>=2006 %then lis(desc);;
		model mortality*censor(1) = race_bg age_begdx age_begdx_sq sex cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual 
		%do i=2 %to 51; st&i. %end; %if &yr.>=2006 %then lis; 
		charlson / risklimit;
	run;

	proc export data=&tempwork..byrace_state&yr.
	outfile="&rootpath./Projects/Programs/mortality/exports/mortality01_annual_models_st.xlsx"
	dbms=xlsx 
	replace;
	sheet="byrace_state&yr.";
	run;
%end;
%mend;

%annual_state(2001,2013);


ods graphics off;

options obs=max;
