/*********************************************************************************************/
title1 'Cohort Analysis';

* Author: PF;
* Purpose: Pooling Years 2001-2013 and checking that N's by state;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/
options obs=max;
data &tempwork..pooled_;
	set  mort.cohort_5yrsurvival_allrace2001-mort.cohort_5yrsurvival_allrace2013;
	by bene_id;
	stcd=state_code*1;
	array st [*] st1-st51;
	do i=1 to 51;
		st[i]=0;
	end;
	if stcd=5 then do;
		st1=1;
		stnm=1;
	end;
	do i=1 to 4;
		if stcd=i then do; 
			st[i+1]=1; 
			stnm=i+1;
		end;
	end;
	do i=6 to 8;
		if stcd=i then do;
			st[i]=1;
			stnm=i;
		end;
	end;
	do i=10 to 39;
		if stcd=i then do;
			st[i-1]=1;
			stnm=i-1;
		end;
	end;
	do i=41 to 47;
		if stcd=i then do;
			st[i-2]=1;
			stnm=i-2;
		end;
	end;
	do i=49 to 53;
		if stcd=i then do;
			st[i-3]=1; 
			stnm=i-3; 
		end;
	end;
	if max(of st1-st51)=0 then do;
		st51=1;
		stnm=51;
	end;
run;

data &tempwork..pooled;
	merge &tempwork..pooled_ (in=a) mort.cci_2001_2013_otherrace (in=c keep=bene_id charlson);
	by bene_id;
	if a;
	charlsonsq=charlson*charlson;
run;

proc freq data=&tempwork..pooled;
	table stnm*state_code / out=&tempwork..pooled_st;
run;

proc freq data=&tempwork..pooled;
	table stnm / out=&tempwork..pooled_stck;
run;

proc freq data=&tempwork..pooled;
	table stnm*race_bg / out=&tempwork..pooled_strace outpct;
run;

proc transpose data=&tempwork..pooled_strace out=&tempwork..pooled_strace_t (drop=_name_ _label_) prefix=racebg_;
	by stnm;
	var count;
	id race_bg;
run;

data &tempwork..pooled_strace1;
	merge &tempwork..pooled_strace_t (in=a) &tempwork..pooled_st (in=b);
	by stnm;
run;

%macro state;
ods output parameterestimates=&tempwork..white_state_cci;
proc phreg data=&tempwork..pooled;
	format race_bg $raceft.sex $sexft.;
	where race_bg="1";
	class female (desc) cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) 
	%do i=2 %to 51;
		st&i. (desc)
	%end;;
	model mortality*censor(1) = age_begdx age_begdx_sq female cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual charlson 
	st2-st51 charlsonsq/ risklimit;
run;

ods output parameterestimates=&tempwork..black_state_cci;
proc phreg data=&tempwork..pooled;
	format race_bg $raceft.sex $sexft.;
	where race_bg="2";
	class female (desc) cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) 
	%do i=2 %to 51;
		st&i. (desc)
	%end;;
	model mortality*censor(1) = age_begdx age_begdx_sq female cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual charlson
	st2-st51 charlsonsq/ risklimit;
run;

ods output parameterestimates=&tempwork..hispanic_state_cci;
proc phreg data=&tempwork..pooled;
	format race_bg $raceft.sex $sexft.;
	where race_bg="5";
	class female (desc) cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) 
	%do i=2 %to 51;
		st&i. (desc)
	%end;;
	model mortality*censor(1) = age_begdx age_begdx_sq female cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual charlson
	st2-st51 charlsonsq/ risklimit;
run;

ods output parameterestimates=&tempwork..asian_state_cci;
proc phreg data=&tempwork..pooled;
	format race_bg $raceft.sex $sexft.;
	where race_bg="4";
	class female (desc) cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) 
	%do i=2 %to 51;
		st&i. (desc)
	%end;;
	model mortality*censor(1) = age_begdx age_begdx_sq female cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual charlson
	st2-st51 charlsonsq/ risklimit;
run;

ods output parameterestimates=&tempwork..aian_state_cci;
proc phreg data=&tempwork..pooled;
	format race_bg $raceft.sex $sexft.;
	where race_bg="6";
	class female (desc) cc_hyp (desc) cc_hyperl (desc) cc_ami (desc)
	cc_atf (desc) cc_str (desc) cc_diab (desc) dual(desc) 
	%do i=2 %to 51;
		st&i. (desc)
	%end;;
	model mortality*censor(1) = age_begdx age_begdx_sq female cc_hyp cc_hyperl cc_ami cc_atf cc_str cc_diab dual charlson
	st2-st51 charlsonsq/ risklimit;
run;

%mend;

%state;

%macro exportstccisq(data);
proc export data=&tempwork..&data.
	outfile="&rootpath./Projects/Programs/mortality/exports/byrace_state_0113_allrace_ccisq.xlsx"
	dbms=xlsx
	replace;
	sheet="&data.";
run;
%mend;

%exportstccisq(pooled_strace1);
%exportstccisq(white_state_cci);
%exportstccisq(black_state_cci);
%exportstccisq(hispanic_state_cci);
%exportstccisq(asian_state_cci);
%exportstccisq(aian_state_cci);




