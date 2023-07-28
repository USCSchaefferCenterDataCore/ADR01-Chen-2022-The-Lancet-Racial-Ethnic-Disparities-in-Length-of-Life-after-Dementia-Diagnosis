/*********************************************************************************************/
title1 'Cohort Analysis';

* Author: PF;
* Purpose: Identify cohort and get mortality descriptives;
* Input: adrdinc_verified_ffs2018, samp_3yrffs_9918;
* Output:	;

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
		67-<76 = "1. <=75"
		76-<81  = "2. 76-80"
		81-<86 = "3. 81-85"
		86-high = "4. 86+";
run;

* Limit to people who have incident ADRD (using drugs and dx) and in sample during incident ADRD;
data mort.cohort01_allrace;
	merge ad.adrdinc_verified (in=a 
	where=(year(final_dx_inc)=2001) keep=bene_id final_dx_inc final_dxrx_inc final_all_inc scen1_adrddxdt)
	base.samp_3yrffs_9918_allrace (keep=bene_id race_bg age_beg: insamp: birth_date death_date sex rename=race_bg=race_bg_) 
	base.cc9917 (in=b keep=bene_id hypert_ever hyperl_ever ami_ever atrial_fib_ever diabetes_ever stroke_tia_ever) 
	base.otcc0017 (in=c keep=bene_id depsn_medicare_ever anxi_medicare_ever)
	sh054066.bene_status_year2001 (in=d keep=bene_id anydual)
	mbsf.mbsf_ab_2001 (in=e keep=bene_id bene_zip_cd bene_county_cd state_code);

	by bene_id;

	if a;

	cc=b;
	otcc=c;
	status=d;
	zip=e;

	format death_date followenddt mmddyy10. follow_type $9.;

	* Getting age and comorbidities at dx;
	if year(final_dx_inc)=2001 then do;
		age_groupdx=put(age_beg2001,agegroup.);
		age_begdx=age_beg2001;
	end;

	cc_hyp=(.<year(hypert_ever)<=year(final_dx_inc));
	cc_hyperl=(.<year(hyperl_ever)<=year(final_dx_inc));
	cc_ami=(.<year(ami_ever)<=year(final_dx_inc));
	cc_atf=(.<year(atrial_fib_ever)<=year(final_dx_inc));
	cc_diab=(.<year(diabetes_ever)<=year(final_dx_inc));
	cc_str=(.<year(stroke_tia_ever)<=year(final_dx_inc));
	cc_depsn=(.<year(depsn_medicare_ever)<=year(final_dx_inc));
	cc_anxi=(.<year(anxi_medicare_ever)<=year(final_dx_inc));

	if insamp2001;

	array insamp [2001:2018] insamp2001-insamp2018;

	format follow_type $9.;
	 * we're going to quantify switchers but leave them in the sample;
	switcher=0;
	do year=2001 to min(2018,year(death_date));
		if insamp[year] ne 1 then switcher=1;
	end;
	if follow_type="" and death_date ne . then do;
		follow_type="death";
		followenddt=death_date;
	end;
	if follow_type="" then do;
		follow_type="censor";
		followenddt=mdy(12,31,2018);
	end;
	censor=0;
	if follow_type='censor' then censor=1;

	mortality=followenddt-final_dx_inc;
	negativefix=0;
	if mortality<0 then do;
		mortality=0;
		negativefix=1;
	end;

	* bucket for mortality;
	mortality_bucket=ceil(mortality/60);

	* dummies;
	female=(sex=2);
	race_bg=race_bg_;
	if race_bg_="" then race_bg="0";
	race_dw=(race_bg=1);
	race_db=(race_bg=2);
	race_da=(race_bg=4);
	race_dh=(race_bg=5);
	race_dn=(race_bg=6);
	race_du=(race_bg=0);
	race_do=(race_bg=3);
	age_begdx_sq=age_begdx**2;
	dual=(anydual="Y");
	*lis=(anylis="Y"); * no more LIS;
	
run;

proc freq data=mort.cohort01_allrace;
	table cc otcc status negativefix censor switcher zip state_code / missing;
run;
* California is SSA state code 05 and FIPS state code 06;

proc means data=mort.cohort01_allrace noprint;
	class race_bg;
	var female cc: dual censor age_begdx;
	output out=&tempwork..mortality_byrace sum()= mean()= / autoname;
run;

proc means data=mort.cohort01_allrace noprint;
	class race_bg;
	var censor;
	output out=&tempwork..censor_byrace mean()= lclm()= uclm()= / autoname;
run;

proc means data=mort.cohort01_allrace noprint;
	class dual;
	var censor;
	output out=&tempwork..censor_bydual mean()= lclm()= uclm()= / autoname;
run;

proc univariate data=mort.cohort01_allrace noprint outtable=&tempwork..mortality_agedist;
	class race_bg;
	var age_begdx mortality;
run;

proc univariate data=mort.cohort01_allrace noprint outtable=&tempwork..mortality_dual;
	class dual;
	var age_begdx mortality;
run;

proc freq data=mort.cohort01_allrace noprint;
	table dual*age_begdx / out=&tempwork..freq_dual_age;
	table dual*mortality / out=&tempwork..freq_dual_mortality;
run;

proc univariate data=mort.cohort01_allrace noprint outtable=&tempwork..mortality_all;
	var age_begdx mortality;
run;

proc freq data=mort.cohort01_allrace noprint;
	table race_bg*mortality / out=&tempwork..freq_race_mortality;
	table race_bg*age_begdx / out=&tempwork..freq_race_agedist;
	table mortality / out=&tempwork..freq_mortality_all;
run;

data &tempwork..mortality_yrs;
	set mort.cohort01_allrace;
	mortality_yrs=round(mortality/365,0.5);
run;

proc freq data=&tempwork..mortality_yrs;
	table race_bg*mortality_yrs / out=&tempwork..freq_race_mortalityyrs;
run;

* Unadjusted tables;
proc freq data=mort.cohort01_allrace noprint;
	where race_bg='1';
	table mortality_bucket / out=&tempwork..mortality_white outcum;
run;

proc freq data=mort.cohort01_allrace noprint;
	where race_bg="2";
	table mortality_bucket / out=&tempwork..mortality_black outcum;
run;

proc freq data=mort.cohort01_allrace noprint;
	where race_bg='5';
	table mortality_bucket / out=&tempwork..mortality_hispanic outcum;
run;

proc freq data=mort.cohort01_allrace noprint;
	where race_bg='4';
	table mortality_bucket / out=&tempwork..mortality_asian outcum;
run;

proc freq data=mort.cohort01_allrace noprint;
	where race_bg='6';
	table mortality_bucket / out=&tempwork..mortality_aian outcum;
run;

proc freq data=mort.cohort01_allrace noprint;
	where race_bg='0';	
	table mortality_bucket / out=&tempwork..mortality_other outcum;
run;

proc freq data=mort.cohort01_allrace noprint;
	where race_bg='3';	
	table mortality_bucket / out=&tempwork..mortality_unknown outcum;
run;

proc freq data=mort.cohort01_allrace;
	table age_groupdx / out=&tempwork..agegroup_dist;
run;

%macro export(data);
proc export data=&tempwork..&data.
	outfile="&rootpath./Projects/Programs/mortality/exports/mortality_byrace01_allrace.xlsx"
	dbms=xlsx 
	replace;
	sheet="&data.";
run;
%mend;

%export(mortality_byrace);
%export(mortality_agedist);
%export(censor_byrace);
%export(mortality_white);
%export(mortality_black);
%export(mortality_hispanic);
%export(mortality_asian);
%export(mortality_aian);
%export(agegroup_dist);
%export(mortality_dual);
%export(mortality_all);
%export(mortality_other);
%export(mortality_unknown);


/* Switcher Characteristics */
proc freq data=mort.cohort01_allrace noprint;
	format race_bg $raceft. sex $sexft. age_begdx agegroup.;
	table switcher*race_bg / out=&tempwork..switcher_race outpct;
	table switcher*sex / out=&tempwork..switcher_sex outpct;
	table switcher*age_begdx / out=&tempwork..switcher_age outpct;
run;

proc means data=mort.cohort01_allrace noprint;
	class switcher;
	var age_begdx cc: dual;
	output out=&tempwork..switcher_cc mean()=;
run;

%macro export(data);
proc export data=&tempwork..&data.
	outfile="&rootpath./Projects/Programs/mortality/exports/switcher_characteristics_allrace.xlsx"
	dbms=xlsx 
	replace;
	sheet="&data.";
run;
%mend;

%export(switcher_race);
%export(switcher_sex);
%export(switcher_age);
%export(switcher_cc);

