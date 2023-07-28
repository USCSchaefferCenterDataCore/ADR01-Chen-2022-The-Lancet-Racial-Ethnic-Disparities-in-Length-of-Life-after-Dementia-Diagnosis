/*********************************************************************************************/
title1 'Cohort Analysis';

* Author: PF;
* Purpose: Create annual cohorts from 2001 to 2013 - will look at 5 year mortality;
* Input: adrdinc_verifiedffs9918, ffs_samp9918;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

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

data covs;
format race_bg $raceft. sex $sexft.;
input race_bg age_begdx age_begdx_sq sex cc_diab cc_hyperl cc_hyp cc_str cc_ami cc_atf dual 
cci;
datalines;
0 82 6724 2 1 1 1 0 0 0 0 1
1 82 6724 2 1 1 1 0 0 0 0 1
2 82 6724 2 1 1 1 0 0 0 0 1
3 82 6724 2 1 1 1 0 0 0 0 1
4 82 6724 2 1 1 1 0 0 0 0 1
5 82 6724 2 1 1 1 0 0 0 0 1
6 82 6724 2 1 1 1 0 0 0 0 1
;
run;

%macro export(data);
proc export data=&tempwork..&data.
	outfile="&rootpath./Projects/Programs/mortality/exports/mortality_annual_models_allrace.xlsx"
	dbms=xlsx 
	replace;
	sheet="&data.";
run;
%mend;

%macro annualcohorts(startyr,endyr);

%do yr=&startyr. %to &endyr.;

%let outyr=%eval(&yr.+5);

* Limit to people who have incident ADRD (using drugs and dx) and in sample during incident ADRD;
data mort.cohort_5yrsurvival_allrace&yr.;
	merge ad.adrdinc_verified (in=a 
	where=(year(final_dx_inc)=&yr.) keep=bene_id final_dx_inc final_dxrx_inc final_all_inc scen1_adrddxdt) 
	base.samp_3yrffs_9918_allrace (keep=bene_id race_bg age_beg: insamp: birth_date death_date sex rename=race_bg=race_bg_) 
	base.cc9917 (in=b keep=bene_id hypert_ever hyperl_ever ami_ever atrial_fib_ever diabetes_ever stroke_tia_ever) 
	base.otcc0017 (in=c keep=bene_id depsn_medicare_ever anxi_medicare_ever)
	%if &yr.<2006 %then %do;
		mbsf.mbsf_ab_&yr. (in=e rename=(bene_zip_cd=zip_cd bene_county_cd=county_cd) keep=bene_id bene_zip_cd bene_county_cd state_code)
		sh054066.bene_status_year&yr. (in=d keep=bene_id anydual)
	%end;
	%if &yr.>=2006 %then %do;
		mbsf.mbsf_abcd_&yr. (in=e keep=bene_id zip_cd county_cd state_code)
		sh054066.bene_status_year&yr. (in=d keep=bene_id anydual anydual_cstshr anylis)
	%end;;

	by bene_id;

	if a;

	cc=b;
	otcc=c;
	status=d;
	zip=e;

	format death_date followenddt mmddyy10. follow_type $9.;

	* Getting age and comorbidities at dx;
	if year(final_dx_inc)=&yr. then do;
		age_groupdx=put(age_beg&yr.,agegroup.);
		age_begdx=age_beg&yr.;
	end;

	cc_hyp=(.<year(hypert_ever)<=year(final_dx_inc));
	cc_hyperl=(.<year(hyperl_ever)<=year(final_dx_inc));
	cc_ami=(.<year(ami_ever)<=year(final_dx_inc));
	cc_atf=(.<year(atrial_fib_ever)<=year(final_dx_inc));
	cc_diab=(.<year(diabetes_ever)<=year(final_dx_inc));
	cc_str=(.<year(stroke_tia_ever)<=year(final_dx_inc));
	cc_depsn=(.<year(depsn_medicare_ever)<=year(final_dx_inc));
	cc_anxi=(.<year(anxi_medicare_ever)<=year(final_dx_inc));

	if insamp&yr.;

	array insamp [&yr.:&outyr.] insamp&yr.-insamp&outyr.;

	format follow_type $9.;
	 * Quantify switchers but leave them in the sample;
	switcher=0;
	do year=&yr. to min(&outyr.,year(death_date));
		if insamp[year] ne 1 then switcher=1;
	end;
	if follow_type="" and .<death_date<=mdy(12,31,&outyr.)  then do;
		follow_type="death";
		followenddt=death_date;
	end;
	if follow_type="" then do;
		follow_type="censor";
		followenddt=mdy(12,31,&outyr.);
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
	%if &yr.<2006 %then %do;
		dual=(anydual="Y");
		lis=0;
	%end;
	%if &yr.>=2006 %then %do;
		dual=(anydual="Y");
		lis=(anylis="Y");
	%end;

run;

proc freq data=mort.cohort_5yrsurvival_allrace&yr.;
	table cc otcc status negativefix censor switcher zip;
run;

proc means data=mort.cohort_5yrsurvival_allrace&yr. noprint;
	class race_bg;
	var female cc: dual lis age_begdx;
	output out=&tempwork..stats_byrace&yr. mean()= / autoname;
run;

proc univariate data=mort.cohort_5yrsurvival_allrace&yr. noprint outtable=&tempwork..stats_agedist&yr.;
	class race_bg;
	var age_begdx mortality;
run;

%export(stats_byrace&yr.);
%export(stats_agedist&yr.);

%end;

%mend;

%annualcohorts(2001,2013);

options obs=max;
