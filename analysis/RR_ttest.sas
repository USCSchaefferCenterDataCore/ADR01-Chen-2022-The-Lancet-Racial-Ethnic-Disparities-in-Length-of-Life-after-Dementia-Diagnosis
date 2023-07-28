/*********************************************************************************************/
title1 'Cohort Analysis';

* Author: PF;
* Purpose: Running t-test on covariates by race;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

/* t-test */
%macro ttest(cov);
proc ttest data=mort.cohort01_geo_allrace;
	where race_bg in("1","2");
	class race_bg;
	var &cov.;
run;

proc ttest data=mort.cohort01_geo_allrace;
	where race_bg in("1","4");
	class race_bg;
	var &cov.;
run;

proc ttest data=mort.cohort01_geo_allrace;
	where race_bg in("1","5");
	class race_bg;
	var &cov.;
run;

proc ttest data=mort.cohort01_geo_allrace;
	where race_bg in("1","6");
	class race_bg;
	var &cov.;
run;
%mend;

%ttest(age_begdx);
%ttest(female);
%ttest(charlson);
%ttest(cc_hyp);
%ttest(cc_hyperl);
%ttest(cc_ami);
%ttest(cc_atf);
%ttest(cc_diab);
%ttest(cc_str);
%ttest(cc_depsn);
%ttest(cc_anxi);
%ttest(dual);
%ttest(urban);
