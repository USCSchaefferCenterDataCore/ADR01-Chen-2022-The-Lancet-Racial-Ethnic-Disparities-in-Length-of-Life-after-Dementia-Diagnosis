/*********************************************************************************************/
title1 'Cohort Analysis';

* Author: PF;
* Purpose: Running cohort models with CCI ;
* Input: cohort01_geo_allrace;
* Output:	;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

ods graphics on;
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

* Types of Charts & models:
- By race unadjusted
- By race adjusting for:
	- age, sex
	- age, sex, and comorbids
	- age, comorbids & dual/
- By race and sex adjusting for:
	- age
	- age and comorbids
	- age, comorbids & dual/;

data &tempwork..cohort01_ccisq;
	set mort.cohort01_geo_allrace;
	charlsonsq=charlson*charlson;
run;

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

* By race adjusting for age, cmd, dual/, Charlson;
ods output parameterestimates=&tempwork..byrace_ccisq;
proc phreg data = &tempwork..cohort01_ccisq plots(overlay)=(survival);
	format race_bg $raceft.sex $sexft.;
	class race_bg (desc) sex cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc)  ;
	model mortality*censor(1) = race_bg age_begdx age_begdx_sq sex cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual  charlson charlsonsq/ risklimit;
	baseline covariates=covs out=&tempwork..survival_ccisq survival=s lower=s_lower upper=s_upper/ rowid=race_bg;
run;

/************************************************ Stratified models *********************************************/
* By race and sex, controlling for age;
proc sort data=&tempwork..cohort01_ccisq out=&tempwork..cohort01_ccisq_s; by race_bg sex; run;

* By race and sex, controlling for ses, Charlson;
ods output parameterestimates=&tempwork..byracesex_ccisq;
proc phreg data=&tempwork..cohort01_ccisq_s;
	by race_bg sex;
	class cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc)  dual(desc);
	model mortality*censor(1)=age_begdx age_begdx_sq cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab  dual charlson charlsonsq/ risklimit;
run;

/* By race and sex, charts*/
data covs_dual_bysex;
format race_bg $raceft.;
input race_bg age_begdx age_begdx_sq female cc_diab cc_hyperl cc_hyp cc_str cc_ami cc_atf dual 
charlson charlsonsq;
datalines;
0 82 6724 0 1 1 1 0 0 0 0 0 1 1
1 82 6724 0 1 1 1 0 0 0 0 0 1 1
2 82 6724 0 1 1 1 0 0 0 0 0 1 1
3 82 6724 0 1 1 1 0 0 0 0 0 1 1
4 82 6724 0 1 1 1 0 0 0 0 0 1 1
5 82 6724 0 1 1 1 0 0 0 0 0 1 1
6 82 6724 0 1 1 1 0 0 0 0 0 1 1
0 82 6724 1 1 1 1 0 0 0 0 0 1 1
1 82 6724 1 1 1 1 0 0 0 0 0 1 1
2 82 6724 1 1 1 1 0 0 0 0 0 1 1
3 82 6724 1 1 1 1 0 0 0 0 0 1 1
4 82 6724 1 1 1 1 0 0 0 0 0 1 1
5 82 6724 1 1 1 1 0 0 0 0 0 1 1
6 82 6724 1 1 1 1 0 0 0 0 0 1 1
;
run;

proc phreg data = &tempwork..cohort01_ccisq plots(overlay)=(survival);
	format race_bg $raceft.sex $sexft.;
	class race_bg (desc) female (desc) cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) ;
	model mortality*censor(1) = race_bg age_begdx age_begdx_sq female cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual  charlson charlsonsq/ risklimit;
	baseline covariates=covs_dual_bysex out=&tempwork..survival_byracesex_ccisq survival=s lower=s_lower upper=s_upper/ group=female rowid=race_bg;
run;

* By age group;
proc sort data=&tempwork..cohort01_ccisq out=&tempwork..cohort01_byage_ccisq_s; by age_groupdx; run;

ods output parameterestimates=&tempwork..byagegroup_ccisq;
proc phreg data = &tempwork..cohort01_byage_ccisq_s plots(overlay)=(survival);
	by age_groupdx;
	format race_bg $raceft.sex $sexft.;
	class race_bg (desc) sex cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) ;
	model mortality*censor(1) = race_bg age_begdx age_begdx_sq sex cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual  charlson charlsonsq/ risklimit;
	baseline covariates=covs out=&tempwork..survival_byage_ccisq survival=s lower=s_lower upper=s_upper/ rowid=race_bg;
run;

/* Regressions stratified sex */
proc sort data=&tempwork..cohort01_byage_ccisq_s; by sex; run;

ods output ParameterEstimates=&tempwork..bysex_ccisq;
ods output hazardratios=&tempwork..bysex_hr_ccisq;
proc phreg data = &tempwork..cohort01_byage_ccisq_s plots(overlay)=(survival);
	format race_bg $raceft. sex $sexft.;
	by sex;
	class race_bg (desc) cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual (desc) ;
	model mortality*censor(1) = race_bg age_begdx age_begdx_sq cc_hyp  cc_hyperl  cc_ami 
	cc_atf  cc_str  cc_diab  dual   charlson charlsonsq/ risklimit;
	baseline covariates=covs out=&tempwork..survival_bysex_ccisq survival=s lower=s_lower upper=s_upper/ rowid=race_bg;
run;

/************************************* Stratified by Dual ****************************************/
data covs_poolses;
format race_bg $raceft. sex $sexft.;
input race_bg age_begdx age_begdx_sq sex cc_diab cc_hyperl cc_hyp cc_str cc_ami cc_atf dual
charlson charlsonsq;
datalines;
0 82 6724 2 1 1 1 0 0 0 0 1 1
1 82 6724 2 1 1 1 0 0 0 0 1 1
2 82 6724 2 1 1 1 0 0 0 0 1 1
3 82 6724 2 1 1 1 0 0 0 0 1 1
4 82 6724 2 1 1 1 0 0 0 0 1 1
5 82 6724 2 1 1 1 0 0 0 0 1 1
6 82 6724 2 1 1 1 0 0 0 0 1 1
; 
run;

proc sort data=&tempwork..cohort01_ccisq; by dual; run;

ods output parameterestimates=&tempwork..bydual_ccisq;
ods output hazardratios=&tempwork..bydual_hr_ccisq;
proc phreg data = &tempwork..cohort01_ccisq plots(overlay)=(survival);
	format race_bg $raceft. sex $sexft.;
	by dual;
	class race_bg (desc) sex cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc);
	model mortality*censor(1) = race_bg sex age_begdx age_begdx_sq cc_hyp cc_hyperl cc_ami 
	cc_atf  cc_str  cc_diab  charlson charlsonsq/ risklimit;
	baseline covariates=covs_poolses out=&tempwork..survival_pool_cci survival=s lower=s_lower upper=s_upper/ rowid=race_bg;
run;

* By urban;
proc sort data=&tempwork..cohort01_ccisq; by urban; run;
ods output parameterestimates=&tempwork..byurban_ccisq;
proc phreg data=&tempwork..cohort01_ccisq;
	format race_bg $raceft.sex $sexft.;
	by urban;
	class race_bg (desc) sex cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) ;
	model mortality*censor(1) = race_bg age_begdx age_begdx_sq sex cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual charlson charlsonsq / risklimit;
run;

ods graphics off;

%macro exportccisq(data);
proc export data=&tempwork..&data.
	outfile="&rootpath./Projects/Programs/mortality/exports/mortality01_models_allrace_ccisq.xlsx"
	dbms=xlsx 
	replace;
	sheet="&data.";
run;
%mend;

%exportccisq(byrace_ccisq);
%exportccisq(bydual_ccisq);
%exportccisq(bysex_ccisq);
%exportccisq(byagegroup_ccisq);
%exportccisq(byurban_ccisq);

options obs=max;
