/*********************************************************************************************/
TITLE1 'AD Prevalence';

* AUTHOR: Patricia Ferido;

* DATE: 6/23/2019;

* PURPOSE: Selecting Sample - No Part D Requirement
					- Require over 65+ in year
					- Require FFS, enr AB in all 12 months in year t-2 and t-1
					- Require FFS, enr AB all year enrollment in year t 
						(does not need to be 12 months and allows for death)
					- Drop those of Native American and unknown ethnicity;

* INPUT: bene_status_yearYYYY, bene_demog2018;
* OUTPUT: samp_3yrffs_0319_allrace;

options compress=yes nocenter ls=160 ps=200 errors=5  errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

***** Running header;
***%include "header.sas";

***** Formats;
proc format;
	value $raceft
		"0"="Unknown"
		"1"="Non-Hispanic White"
		"2"="Black"
		"3"="Other"
		"4"="Asian/Pacific Islander"
		"5"="Hispanic"
		"6"="American Indian/Alaska Native"
		"7"="All Races";
	value $sexft
		"1"="Male"
		"2"="Female";
	value agegroup
		low-<75 = "1. <75"
		75-84  = "2. 75-84"
		85 - high = "3. 85+";
run;

***** Years of data;
%let mindatayear=1999;
%let maxdatayear=2018;

***** Years of sample;
%let minsampyear=1999;
%let maxsampyear=2018;

options obs=max;

**** Step 1: Merge together bene_status yearly files;
%macro mergebene;
%do year=&mindatayear %to &maxdatayear;
	data &tempwork..bene&year;
		set &datalib..bene_status_year&year (keep=bene_id age_beg enrFFS_allyr enrAB_mo_yr);
		rename age_beg=age_beg&year enrFFS_allyr=enrFFS_allyr&year enrAB_mo_yr=enrAB_mo_yr&year;
	run;
%end;

data &tempwork..benestatus;
	merge &tempwork..bene&mindatayear-&tempwork..bene&maxdatayear;
	by bene_id;
run;
%mend; 

%mergebene;

**** Step 2: Merge to bene_demog which has standardized demographic variables & flag sample;
%macro sample;
data &outlib..samp_3yrffs_9918_allrace;
	merge &tempwork..benestatus (in=a) &datalib..bene_demog2018 (in=b keep=bene_id dropflag race_bg sex birth_date death_date);
	by bene_id;
	if a and b;

	* Undoing the race drop;
	*race_drop=(race_bg in("","0","3"));    
		
	%do year=&minsampyear %to &maxsampyear;
		
		%let prev1_year=%eval(&year-1);
		%let prev2_year=%eval(&year-2);

		* Age groups;
		age_group&year=put(age_beg&year,agegroup.);

		* Limiting to age 67 and in FFS and Part D in 2 previous years;
		%if &year=1999 %then %do;
			if age_beg&year>=67 
			and dropflag="N"
			and enrFFS_allyr&year="Y"
			then insamp&year=1;
			else insamp&year=0;
		%end;

		%if &year=2000 %then %do;
			if age_beg&year>=67 
			and dropflag="N"
			and (enrFFS_allyr&prev1_year="Y" and enrFFS_allyr&year="Y")
			and (enrAB_mo_yr&prev1_year=12) 
			then insamp&year=1;
			else insamp&year=0;
		%end;

		%if &year>=2001 %then %do;
			if age_beg&year>=67 
			and dropflag="N"
			and (enrFFS_allyr&prev2_year="Y" and enrFFS_allyr&prev1_year="Y" and enrFFS_allyr&year="Y")
			and (enrAB_mo_yr&prev2_year=12 and enrAB_mo_yr&prev1_year=12) 
			then insamp&year=1;
			else insamp&year=0;
		%end;
	
	%end;
	
	anysamp=max(of insamp&minsampyear-insamp&maxsampyear);

run;
%mend;

%sample;

***** Step 3: Sample Statistics;
%macro stats;

* By year;
%do year=&minsampyear %to &maxsampyear;
proc freq data=&outlib..samp_3yrffs_9918_allrace noprint;
	where insamp&year=1;
	format race_bg $raceft. sex $sexft.;
	table race_bg / out=&tempwork..byrace_&year;
	table age_group&year / out=&tempwork..byage_&year;
	table sex / out=&tempwork..bysex_&year;
run;

proc transpose data=&tempwork..byrace_&year out=&tempwork..byrace_&year._t (drop=_name_ _label_); var count; id race_bg; run;
proc transpose data=&tempwork..byage_&year out=&tempwork..byage_&year._t (drop=_name_ _label_); var count; id age_group&year; run;
proc transpose data=&tempwork..bysex_&year out=&tempwork..bysex_&year._t (drop=_name_ _label_); var count; id sex; run;

proc contents data=&tempwork..byrace_&year._t; run;
proc contents data=&tempwork..byage_&year._t; run;
proc contents data=&tempwork..bysex_&year._t; run;

proc means data=&outlib..samp_3yrffs_9918_allrace noprint;
	where insamp&year=1;
	output out=&tempwork..avgage_&year (drop=_type_ rename=_freq_=total_bene) mean(age_beg&year)=avgage;
run;

data &tempwork..stats&year;
	length year $7.;
	merge &tempwork..byrace_&year._t &tempwork..byage_&year._t &tempwork..bysex_&year._t &tempwork..avgage_&year;
	year="&year";
run;
%end;

* Overall - only from 2007 to 2013;
proc freq data=&outlib..samp_3yrffs_9918_allrace noprint;
	where anysamp=1;
	format race_bg $raceft. sex $sexft.;
	table race_bg / out=&tempwork..byrace_all;
	table sex / out=&tempwork..bysex_all;
run;

proc transpose data=&tempwork..byrace_all out=&tempwork..byrace_all_t (drop=_name_ _label_); var count; id race_bg; run;
proc transpose data=&tempwork..bysex_all out=&tempwork..bysex_all_t (drop=_name_ _label_); var count; id sex; run;

data &tempwork..allages;
	set
	%do year=&minsampyear %to &maxsampyear;
		&outlib..samp_3yrffs_9918_allrace (where=(insamp&year=1) keep=insamp&year bene_id age_beg&year rename=(age_beg&year=age_beg))
	%end;;
run;

proc means data=&tempwork..allages;
	var age_beg;
	output out=&tempwork..avgage_all (drop=_type_ _freq_) mean=avgage;
run;

data &tempwork..statsoverall;
	merge &tempwork..byrace_all_t &tempwork..bysex_all_t &tempwork..avgage_all;
	year="all";
run;

data samp_stats_ffs;
	set &tempwork..stats&minsampyear-&tempwork..stats&maxsampyear &tempwork..statsoverall;
run;
%mend;

%stats;

proc export data=samp_stats_ffs
	outfile="&rootpath./Projects/Programs/base/exports/samp_stats_ffs9918_allrace.xlsx"
	dbms=xlsx
	replace;
	sheet="stats";
run;

proc datasets library=&tempwork kill; run;
