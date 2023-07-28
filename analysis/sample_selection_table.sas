/*********************************************************************************************/
title1 'Cohort Analysis';

* Author: PF;
* Purpose: Sample selection for 2001 cohort;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

* All beneficiaries in Medicare 2001;
data &tempwork..ptab;
	set sh054066.bene_status_year2001 (in=a keep=bene_id enrAB_allyr age_beg65);
	by bene_id;
	if enrAB_allyr="Y" and age_beg65="Y";
run;

* FFS in 1999, 2000 and 2001;
data &tempwork..ffs;
	merge &tempwork..ptab (in=a) 
	ad.adrdinc_verified (in=b keep=bene_id final_dx_inc final_dxrx_inc final_all_inc scen1_adrddxdt)
	base.samp_3yrffs_9918_allrace (keep=bene_id race_bg age_beg: insamp: birth_date death_date sex);
	by bene_id;
	if a;

	if insamp2001;
run;

* Drop prevalent AD;
data &tempwork..prevAD;
	set &tempwork..ffs;
	by bene_id;

	if .<year(final_dx_inc)<=2001;
run;

* Drop non-AD;
data &tempwork..nonAD;
	set &tempwork..prevAD;
	by bene_id;

	if year(final_dx_inc) ne 2001 then delete;
	yrck=year(final_dx_inc);
run;

* check;
proc freq data=&tempwork..nonAD;
	table yrck / missing;
run;


