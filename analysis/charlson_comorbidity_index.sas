/*********************************************************************************************/
title1 'Cohort Analysis';

* Author: PF;
* Purpose: Get the charlson comorbitiy index for the 2008-2013 cohorts;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

* Create a smaller subset population to pull all claims for based on cohort year
  - Bene_id, start year to pull, last year to pull
  - Will pull one year before index date in order to account for all claims 12 months prior for CCI;

%let byr=2001;
%let eyr=2013;

%macro cci_samp(startyr,endyr);
data &tempwork..cci_samp;
	set %do yr=&startyr. %to &endyr.;
		mort.cohort_5yrsurvival&yr. (in=_&yr. keep=bene_id final_dx_inc)
		%end;
		mort.cohort01 (in=a keep=bene_id final_dx_inc);
	by bene_id;
	modx=month(final_dx_inc);
	yrdx=year(final_dx_inc);
	startdt=mdy(modx,1,yrdx-1);
	enddt=mdy(modx,1,yrdx)-1;
	format startdt enddt mmddyy10.;
	label
		startdt= 'One year before date of diagnosis'
		enddt='Last day before month of diagnosis';
run;
%mend;

%cci_samp(&byr.,&eyr.);

%let clmyr=%eval(&byr.-1);

%macro dx(clmin,clmout,ftype,startyr,endyr,datev,keepv);

%do yr=&startyr %to &endyr;

	proc sql;
		%do mo=1 %to 9;
			create table &tempwork..&clmout.&yr._&mo. as
			select x.*,y.startdt,y.enddt,y.final_dx_inc
			from rif&yr..&clmin._claims_0&mo. (keep=bene_id &keepv) as x
			inner join 
			&tempwork..cci_samp as y
			on x.bene_id=y.bene_id and (y.startdt-30)<=x.&datev.<=(y.enddt+30)
			order by x.bene_id, x.&datev;
		%end;
		%do mo=10 %to 12;
			create table &tempwork..&clmout.&yr._&mo. as
			select x.*,y.startdt,y.enddt,y.final_dx_inc
			from rif&yr..&clmin._claims_&mo. (keep=bene_id &keepv) as x
			inner join 
			&tempwork..cci_samp as y
			on x.bene_id=y.bene_id and y.startdt<=x.&datev.<=y.enddt
			order by x.bene_id, x.&datev;
		%end;
	run;

	data &tempwork..&clmout.&yr.;
		set &tempwork..&clmout.&yr._1-&tempwork..&clmout.&yr._12;
		by bene_id &datev.;
		rename &datev=claim_date;
		filetype="&ftype.";
	run;

%end;
%mend;

%dx(outpatient,op,O,&clmyr.,&eyr.,clm_from_dt,clm_from_dt icd_dgns_cd1-icd_dgns_cd25 icd_prcdr_cd1-icd_prcdr_cd25);
%dx(inpatient,ip,M,&clmyr.,&eyr.,clm_admsn_dt,clm_admsn_dt admtg_dgns_cd clm_utlztn_day_cnt icd_dgns_cd1-icd_dgns_cd25 icd_prcdr_cd1-icd_prcdr_cd25);
%dx(snf,snf,M,&clmyr.,&eyr.,clm_admsn_dt,clm_admsn_dt admtg_dgns_cd clm_utlztn_day_cnt icd_dgns_cd1-icd_dgns_cd25 icd_prcdr_cd1-icd_prcdr_cd25);
%dx(bcarrier,car,N,&clmyr.,&eyr.,clm_from_dt,clm_from_dt prncpal_dgns_cd icd_dgns_cd1-icd_dgns_cd12);

data mort.cci_clms;
	set 
	&tempwork..op&clmyr.-&tempwork..op&eyr. 
	&tempwork..ip&clmyr.-&tempwork..ip&eyr. 
	&tempwork..snf&clmyr.-&tempwork..snf&eyr.
	&tempwork..car&clmyr.-&tempwork..car&eyr.;
run;

%include "&rootpath./Projects/Programs/mortality/charlson_comorbidity_index_macro.sas";

%COMORB(mort.cci_clms,bene_id,startdt,enddt,claim_date,filetype,clm_utlztn_day_cnt,icd_dgns_cd1-icd_dgns_cd25 prncpal_dgns_cd admtg_dgns_cd,
icd_prcdr_cd1-icd_prcdr_cd25,R,mort.cci_&byr._&eyr.);


