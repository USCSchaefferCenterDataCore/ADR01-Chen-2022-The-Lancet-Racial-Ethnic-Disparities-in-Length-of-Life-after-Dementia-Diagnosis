/*********************************************************************************************/
title1 'Cohort Analysis';

* Author: PF;
* Purpose: Getting unadjusted mortality rates by 2018 by county, zip code and urban;
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

/******************************************* Build Geo Variables *************************************************/
* Creating state, county and urban indicators;
data &tempwork..cohort01_geo_allrace;
	merge mort.cohort01_allrace (in=a) mort.cci_2001_2013_otherrace (in=c keep=bene_id charlson); 
	by bene_id;

	if a;
	mort=c;

	* county;
	if state_code="" and bene_county_cd="999" then state_code1="99";
	else state_code1=state_code;
	ssa_county=compress(state_code1)||compress(bene_county_cd);

	* state;
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
	if max(of st1-st51)=0 then st51=1;

	* Giving charlson a value of 0;
	if charlson=. then charlson=0;

	* zip5;
	zip5=substr(bene_zip_cd,1,5);

run;

proc freq data=&tempwork..cohort01_geo_allrace;
	table mort;
run;

proc means data=&tempwork..cohort01_geo_allrace noprint nway;
	class stcd;
	var st1-st51;
	output out=&tempwork..cohort01_geo_allrace_stateck max()=;
run;

* Merge to FIPS county and county name;
proc sort data=&tempwork..cohort01_geo_allrace; by ssa_county; run;
proc sort data=base.ssa_fips_state_county2017; by ssacounty; run;

data &tempwork..cohort01_geo_allrace_;
	merge &tempwork..cohort01_geo_allrace (in=a) base.ssa_fips_state_county2017 (in=b rename=ssacounty=ssa_county);
	by ssa_county;
	geo=a;
	xwlk=b;
	if a;
run;

proc freq data=&tempwork..cohort01_geo_allrace_;
	table geo*xwlk;
run;

proc sort data=&tempwork..cohort01_geo_allrace_; by fipscounty; run;
proc sort data=base.urbanruralcont; by fips_county; run;

data mort.cohort01_geo_allrace;
	merge &tempwork..cohort01_geo_allrace_ (in=a rename=fipscounty=fips_county) base.urbanruralcont (in=b);
	by fips_county;
	geo=a;
	arf=b;
	
	* Using 2003 since it is the closest year for the urban rural continuum;
	if urbanrural03 in("01","02","03") then urban=1; else urban=0;

	* death dummy;
	if follow_type="death" then died=1; else died=0;

	* Missing county names;
	if county="" then county="MISSING";

	if geo;

run;

proc freq data=mort.cohort01_geo_allrace;
	table geo*arf;
run;

proc means data=mort.cohort01_geo_allrace noprint;
	class race_bg;
	output out=&tempwork..urban_byrace mean(urban charlson)=;
run;

/*********************************************** By County ***********************************************************/
proc freq data=mort.cohort01_geo_allrace noprint;
	table state_code*bene_county_cd / missing out=&tempwork..freq_county_bene;
run;

proc freq data=mort.cohort01_geo_allrace noprint;
	table county / out=&tempwork..freq_county_ck missing;
	table county*fips_county / out=&tempwork..freq_fipscounty_ck missing;
	table county*ssa_county / out=&tempwork..freq_ssacounty_ck missing;
	table zip5 / out=&tempwork..freq_zip5_ck missing;
run;

proc means data=mort.cohort01_geo_allrace noprint nway;
	class state county fips_county;
	var died censor mortality;
	output out=&tempwork..cohort01_county_mean mean()=;
run;

data &tempwork..freq_fipscounty_ck1;
	set &tempwork..freq_fipscounty_ck;
	cnt=_n_;
	array cnty [*] cnty1-cnty3223;
	do i=1 to 3223;
		cnty[i]=0;
		if _n_=i then cnty[i]=1;
	end;
run;

proc sort data=mort.cohort01_geo_allrace; by county fips_county; run;

data &tempwork..cohort01_county;
	merge mort.cohort01_geo_allrace (in=a) &tempwork..freq_fipscounty_ck1 (in=b keep=county fips_county cnt cnty:);
	by county fips_county;
	if a;
	ck=b;
run;

proc freq data=&tempwork..cohort01_county;
	table ck;
run;

* Unadjusted mortality rate by 2018 by county code;

%macro county; * Ommitting Los Angeles;
ods output parameterestimates=&tempwork..byrace_county_unadj;
proc phreg data=&tempwork..cohort01_county;
	format race_bg $raceft. sex $sexft.;
	class %do i=1 %to 1744; cnty&i. (desc) %end;
	%do i=1746 %to 3223; cnty&i. (desc) %end;;
	model mortality*censor(1)= cnty1-cnty1744 cnty1746-cnty3223 / risklimit;
run;

ods output parameterestimates=&tempwork..byrace_county_base;
proc phreg data=&tempwork..cohort01_county;
	format race_bg $raceft. sex $sexft.;
	class race_bg (desc) sex %do i=1 %to 1744; cnty&i. (desc) %end;
	%do i=1746 %to 3223; cnty&i. (desc) %end;;
	model mortality*censor(1)= race_bg  sex age_begdx age_begdx_sq cnty1-cnty1744 cnty1746-cnty3223 / risklimit;
run;

ods output parameterestimates=&tempwork..byrace_county_cc;
proc phreg data=&tempwork..cohort01_county;
	format race_bg $raceft.sex $sexft.;
	class race_bg (desc) sex cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) 
	%do i=1 %to 1744; cnty&i. (desc) %end;
	%do i=1746 %to 3223; cnty&i. (desc) %end;;
	model mortality*censor(1) = race_bg age_begdx age_begdx_sq sex cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab 
	cnty1-cnty1744 cnty1746-cnty3223 / risklimit;
run;

ods output parameterestimates=&tempwork..byrace_county_ses;
proc phreg data=&tempwork..cohort01_county;
	format race_bg $raceft.sex $sexft.;
	class race_bg (desc) sex cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) 
	%do i=1 %to 1744; cnty&i. (desc) %end;
	%do i=1746 %to 3223; cnty&i. (desc) %end;;
	model mortality*censor(1) = race_bg age_begdx age_begdx_sq sex cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual 
	cnty1-cnty1744 cnty1746-cnty3223 / risklimit;
run;

ods output parameterestimates=&tempwork..byrace_county_cci;
proc phreg data=&tempwork..cohort01_county;
	format race_bg $raceft.sex $sexft.;
	class race_bg (desc) sex cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) 
	%do i=1 %to 1744; cnty&i. (desc) %end;
	%do i=1746 %to 3223; cnty&i. (desc) %end;;
	model mortality*censor(1) = race_bg age_begdx age_begdx_sq sex cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual charlson
	cnty1-cnty1744 cnty1746-cnty3223 / risklimit;
run;
%mend;

%county;


/**************************************** Urban ********************************************/
proc means data=mort.cohort01_geo_allrace noprint nway;
	class urban;
	var died censor mortality;
	output out=&tempwork..urban_rate_unadj mean()=;
run;

ods output parameterestimates=&tempwork..byrace_urban_unadj;
proc phreg data=mort.cohort01_geo_allrace;
	format race_bg $raceft. sex $sexft.;
	class urban (desc) ;
	model mortality*censor(1)= urban / risklimit;
run;

ods output parameterestimates=&tempwork..byrace_urban_base;
proc phreg data=mort.cohort01_geo_allrace;
	format race_bg $raceft. sex $sexft.;
	class race_bg (desc) sex urban (desc) ;
	model mortality*censor(1)= race_bg  sex age_begdx age_begdx_sq urban / risklimit;
run;

ods output parameterestimates=&tempwork..byrace_urban_cc;
proc phreg data=mort.cohort01_geo_allrace;
	format race_bg $raceft.sex $sexft.;
	class race_bg (desc) sex cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) urban (desc);
	model mortality*censor(1) = race_bg age_begdx age_begdx_sq sex cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab 
	urban / risklimit;
run;

ods output parameterestimates=&tempwork..byrace_urban_ses;
proc phreg data=mort.cohort01_geo_allrace;
	format race_bg $raceft.sex $sexft.;
	class race_bg (desc) sex cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) urban (desc);
	model mortality*censor(1) = race_bg age_begdx age_begdx_sq sex cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual 
	urban / risklimit;
run;

ods output parameterestimates=&tempwork..byrace_urban_cci;
proc phreg data=mort.cohort01_geo_allrace;
	format race_bg $raceft.sex $sexft.;
	class race_bg (desc) sex cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) urban(desc);
	model mortality*censor(1) = race_bg age_begdx age_begdx_sq sex cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual charlson
	urban / risklimit;
run;

* Urban;
proc sort data=mort.cohort01_geo_allrace; by urban; run;

ods output parameterestimates=&tempwork..byurban_base;
proc phreg data=mort.cohort01_geo_allrace;
	format race_bg $raceft. sex $sexft.;
	by urban;
	class race_bg (desc) sex;
	model mortality*censor(1)= race_bg  sex age_begdx age_begdx_sq / risklimit;
run;

ods output parameterestimates=&tempwork..byurban_cc;
proc phreg data=mort.cohort01_geo_allrace;
	format race_bg $raceft.sex $sexft.;
	by urban;
	class race_bg (desc) sex cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc);
	model mortality*censor(1) = race_bg age_begdx age_begdx_sq sex cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab  / risklimit;
run;

ods output parameterestimates=&tempwork..byurban_ses;
proc phreg data=mort.cohort01_geo_allrace;
	format race_bg $raceft.sex $sexft.;
	by urban;
	class race_bg (desc) sex cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) ;
	model mortality*censor(1) = race_bg age_begdx age_begdx_sq sex cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual / risklimit;
run;

ods output parameterestimates=&tempwork..byurban_cci;
proc phreg data=mort.cohort01_geo_allrace;
	format race_bg $raceft.sex $sexft.;
	by urban;
	class race_bg (desc) sex cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) ;
	model mortality*censor(1) = race_bg age_begdx age_begdx_sq sex cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual charlson / risklimit;
run;

/*********************************************** By Zip ************************************************/
proc means data=mort.cohort01_geo_allrace noprint nway;
	class zip5;
	var died censor mortality;
	output out=&tempwork..cohort01_zip5_mean mean()=;
run;

/****************************************** By State **************************************************************/
%macro state;
ods output parameterestimates=&tempwork..byrace_state_unadj;
proc phreg data=mort.cohort01_geo_allrace;
	format race_bg $raceft. sex $sexft.;
	class %do i=2 %to 51; st&i. (desc) %end;;
	model mortality*censor(1)= st2-st51 / risklimit;
run;

ods output parameterestimates=&tempwork..byrace_state_base;
proc phreg data=mort.cohort01_geo_allrace;
	format race_bg $raceft. sex $sexft.;
	class race_bg (desc) sex %do i=2 %to 51; st&i. (desc) %end;;
	model mortality*censor(1)= race_bg  sex age_begdx age_begdx_sq st2-st51 / risklimit;
run;

ods output parameterestimates=&tempwork..byrace_state_cc;
proc phreg data=mort.cohort01_geo_allrace;
	format race_bg $raceft.sex $sexft.;
	class race_bg (desc) sex cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) 
	%do i=2 %to 51;
		st&i. (desc)
	%end;;
	model mortality*censor(1) = race_bg age_begdx age_begdx_sq sex cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab 
	st2-st51 / risklimit;
run;

ods output parameterestimates=&tempwork..byrace_state_ses;
proc phreg data=mort.cohort01_geo_allrace;
	format race_bg $raceft.sex $sexft.;
	class race_bg (desc) sex cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) 
	%do i=2 %to 51;
		st&i. (desc)
	%end;;
	model mortality*censor(1) = race_bg age_begdx age_begdx_sq sex cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual 
	st2-st51 / risklimit;
run;

ods output parameterestimates=&tempwork..byrace_state_cci;
proc phreg data=mort.cohort01_geo_allrace;
	format race_bg $raceft.sex $sexft.;
	class race_bg (desc) sex cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) 
	%do i=2 %to 51;
		st&i. (desc)
	%end;;
	model mortality*censor(1) = race_bg age_begdx age_begdx_sq sex cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual charlson
	st2-st51 / risklimit;
run;
%mend;

%state;

%macro export_geo(data);
proc export data=&tempwork..&data.
	outfile="&rootpath./Projects/Programs/mortality/exports/cohort01_geo_allrace.xlsx"
	dbms=xlsx
	replace;
	sheet="&data.";
run;
%mend;

%export_geo(cohort01_county_mean);
%export_geo(urban_rate_unadj);
%export_geo(byrace_urban_unadj);
%export_geo(byrace_urban_base);
%export_geo(byrace_urban_cc);
%export_geo(byrace_urban_ses);
%export_geo(byrace_urban_cci);
%export_geo(cohort01_zip5_mean);
%export_geo(byurban_base);
%export_geo(byurban_cc);
%export_geo(byurban_ses);
%export_geo(byurban_cci);
%export_geo(urban_byrace);
%export_geo(byrace_state_unadj);
%export_geo(byrace_state_base);
%export_geo(byrace_state_cc);
%export_geo(byrace_state_ses);
%export_geo(byrace_state_cci);

options obs=max;
