/*********************************************************************************************/
TITLE1 'AD Prevalence';

* AUTHOR: Patricia Ferido;

* DATE: 4/20/2018;

* PURPOSE: Selecting Sample
					- Require over 65+ in year
					- Require FFS, enr AB and Part D in all 12 months in year t-2 and t-1
					- Require FFS, enr AB and Part D all year enrollment in year t 
						(does not need to be 12 months and allows for death)
					- Drop those of Native American and unknown ethnicity;

* INPUT: bene_status_yearYYYY, bene_demog2016;
* OUTPUT: samp_3yrffsptd_0316;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

***** Running header;
%include "../header.sas";

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
%let mindatayear=2005;
%let maxdatayear=2018;

***** Years of sample;
%let minsampyear=2007;
%let maxsampyear=2018;

**** Step 1: Merge together bene_status yearly files;
%macro mergebene;
%do year=&mindatayear %to &maxdatayear;
%if &year<2006 %then %do;
	data bene&year;
		set &benedata..bene_status_year&year (keep=bene_id age_beg enrFFS_allyr enrAB_mo_yr);
		rename age_beg=age_beg&year enrFFS_allyr=enrFFS_allyr&year enrAB_mo_yr=enrAB_mo_yr&year;
	run;
%end;
%else %do;
	data bene&year;
		set &benedata..bene_status_year&year (keep=bene_id age_beg enrFFS_allyr enrAB_mo_yr ptD_allyr);
		rename age_beg=age_beg&year enrFFS_allyr=enrFFS_allyr&year enrAB_mo_yr=enrAB_mo_yr&year ptD_allyr=ptD_allyr&year;
	run;
%end;
%end;

data benestatus;
	merge bene&mindatayear-bene&maxdatayear;
	by bene_id;
run;
%mend; 

%mergebene;

**** Step 2: Merge to bene_demog which has standardized demographic variables & flag sample;
%macro sample;
data &outlib..samp_3yrffsptd_0718;
	merge benestatus (in=a) &benedata..bene_demog2018 (in=b keep=bene_id dropflag race_bg sex birth_date death_date);
	by bene_id;
	if a and b;

	* Dropping native american, unknown and other race and ad diagnosis before 2004;
	race_drop=(race_bg in("","0","3","6"));    
		
	%do year=&minsampyear %to &maxsampyear;
		
		%let prev1_year=%eval(&year-1);
		%let prev2_year=%eval(&year-2);
			
		* Age groups;
		age_group&year=put(age_beg&year,agegroup.);
		
		* First, doing Part D years where you cant look back due to enrollment issues in 2006;
		* Second, doing Part D year with only 1 year lookback;
		* Third, doing Part D years with two year lookback;
		%if &year<=2007 %then %do; 
		
			%let ptdprev1_year=&year;
			%let ptdprev2_year=&year;
			
			* limiting to age 67 and in FFS and Part D in 2 previous years;
			if age_beg&year>=67 
			and race_drop=0
			and dropflag="N"
			and (enrFFS_allyr&prev2_year="Y" and enrFFS_allyr&prev1_year="Y" and enrFFS_allyr&year="Y")
			and (enrAB_mo_yr&prev2_year=12 and enrAB_mo_yr&prev1_year=12) 
			and (ptD_allyr&ptdprev2_year="Y" and ptd_allyr&ptdprev1_year="Y" and ptd_allyr&year="Y")
			then insamp&year=1;
			else insamp&year=0;
			
		%end;
		
		%if &year=2008 %then %do;
		
			%let ptdprev1_year=%eval(&year-1);
			%let ptdprev2_year=%eval(&year-1);
			
			* limiting to age 67 and in FFS and Part D in 2 previous years;
			if age_beg&year>=67 
			and race_drop=0
			and dropflag="N"
			and (enrFFS_allyr&prev2_year="Y" and enrFFS_allyr&prev1_year="Y" and enrFFS_allyr&year="Y")
			and (enrAB_mo_yr&prev2_year=12 and enrAB_mo_yr&prev1_year=12) 
			and (ptD_allyr&ptdprev2_year="Y" and ptd_allyr&ptdprev1_year="Y" and ptd_allyr&year="Y")
			then insamp&year=1;
			else insamp&year=0;
			
		%end;
		
		%else %if &year>2008 %then %do;
			
			%let ptdprev1_year=%eval(&year-1);
			%let ptdprev2_year=%eval(&year-2);
			
			* Limiting to age 67 and in FFS and Part D in 2 previous years;
			if age_beg&year>=67 
			and race_drop=0
			and dropflag="N"
			and (enrFFS_allyr&prev2_year="Y" and enrFFS_allyr&prev1_year="Y" and enrFFS_allyr&year="Y")
			and (enrAB_mo_yr&prev2_year=12 and enrAB_mo_yr&prev1_year=12) 
			and (ptD_allyr&ptdprev2_year="Y" and ptd_allyr&ptdprev1_year="Y" and ptd_allyr&year="Y")
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
proc freq data=&outlib..samp_3yrffsptd_0718 noprint;
	where insamp&year=1;
	format race_bg $raceft. sex $sexft.;
	table race_bg / out=byrace_&year;
	table age_group&year / out=byage_&year;
	table sex / out=bysex_&year;
run;

proc transpose data=byrace_&year out=byrace_&year._t (drop=_name_ _label_); var count; id race_bg; run;
proc transpose data=byage_&year out=byage_&year._t (drop=_name_ _label_); var count; id age_group&year; run;
proc transpose data=bysex_&year out=bysex_&year._t (drop=_name_ _label_); var count; id sex; run;

proc contents data=byrace_&year._t; run;
proc contents data=byage_&year._t; run;
proc contents data=bysex_&year._t; run;

proc means data=&outlib..samp_3yrffsptd_0718 noprint;
	where insamp&year=1;
	output out=avgage_&year (drop=_type_ rename=_freq_=total_bene) mean(age_beg&year)=avgage;
run;

data stats&year;
	length year $7.;
	merge byrace_&year._t byage_&year._t bysex_&year._t avgage_&year;
	year="&year";
run;
%end;

* Overall - only from 2007 to 2013;
proc means data=&outlib..samp_3yrffsptd_0718 noprint;
	where anysamp;
	output out=totalsamp_all (drop=_type_ rename=_freq_=total_bene);
run;

proc freq data=&outlib..samp_3yrffsptd_0718 noprint;
	where anysamp=1;
	format race_bg $raceft. sex $sexft.;
	table race_bg / out=byrace_all;
	table sex / out=bysex_all;
run;

proc transpose data=byrace_all out=byrace_all_t (drop=_name_ _label_); var count; id race_bg; run;
proc transpose data=bysex_all out=bysex_all_t (drop=_name_ _label_); var count; id sex; run;

data allages;
	set
	%do year=&minsampyear %to &maxsampyear;
		&outlib..samp_3yrffsptd_0718 (where=(insamp&year=1) keep=insamp&year bene_id age_beg&year rename=(age_beg&year=age_beg))
	%end;;
run;

proc means data=allages;
	var age_beg;
	output out=avgage_all (drop=_type_ _freq_) mean=avgage;
run;

data statsoverall;
	merge byrace_all_t bysex_all_t avgage_all totalsamp_all;
	year="all";
run;

data stats_output;
	set stats&minsampyear-stats&maxsampyear statsoverall;
run;
%mend;

%stats;

proc print data=stats_output; run;
proc contents data=&outlib..samp_3yrffsptd_0718; run;

