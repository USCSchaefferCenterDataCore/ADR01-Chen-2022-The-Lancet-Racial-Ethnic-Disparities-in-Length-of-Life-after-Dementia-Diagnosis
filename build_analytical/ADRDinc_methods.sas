/*********************************************************************************************/
title1 'Exploring AD Incidence Definition';

* Author: PF;
* Purpose: 	Verified ADRD Valid Verified Scenarios - skipping numbers to line up with other analysis
		- 1) ADRD + RX drug
		- 2) ADRD + ADRD 
		- 3) ADRD + Dementia Symptoms
		- 4) ADRD + Death	
		Merging together AD drugs, Dementia claims, dementia symptoms, specialists,
		& relevant CPT codes to make final analytical file
		- Adding limits to the verifications:
			- Death needs to occur within a year for it to count as a verify condition
			- All other verification needs to occur within 2 years for it count as a verify countion;

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../header.sas";

%let minyear=2001;
%let maxyear=2018;

data _null_;
	time=mdy(12,31,&maxyear.)-mdy(1,1,&minyear.)+1;
	call symput('time',time);
run;

%put &time;

data analytical;
	format year best4.;
	merge &outlib..dementia_dt_&minyear._&maxyear. (in=a rename=(demdx_dt=date)) &outlib..ADdrugs_dts_0617 (in=b rename=(srvc_dt=date));
	by bene_id year date;
	
	if bene_id ne "";
	
	dx=0;
	naddx=0;
	addx=0;
	symptom=0;
	
	if compress(dxtypes,,'l') ne "" then dx=1;
	if compress(dxtypes,"A",'l') ne "" then naddx=1;
	if find(dxtypes,"A") then addx=1;
	if find(dxtypes,'p') then symptom=1;
	
run;

***** Merging to birth date and death date;
data analytical1;
	merge analytical (in=a) &datalib..bene_demog2018 (in=b keep=bene_id death_date);
	by bene_id;
	if a and b;
run;

***** Analysis of AD Incidence;
data analytical2;
	set analytical1;
	by bene_id year date;
	
	if first.bene_id then do;
		first_dx=.;
		first_rx=.;
		first_symptoms=.;
	end;
	retain first_dx first_rx first_symptoms;
	
	* Setting first RX, symptoms and ADRD date;
	if first_dx=. and dx=1 then first_dx=date;
	if first_rx=. and addrug=1 then first_rx=date;
	if first_symptoms=. and symptom=1 then first_symptoms=date;
	format first_dx first_rx first_symptoms mmddyy10.;
	
	* Scenario 1: Two records of ADRD dx;
	retain scen_dx_inc scen_dx_vtime scen_dx_dx2dt scen_dx_inctype scen_dx_vtype scen_dx_vdt ;
	format scen_dx_inc scen_dx_vdt scen_dx_dx2dt mmddyy10. scen_dx_inctype scen_dx_vtype $4.;
	if first.bene_id then do;
		scen_dx_inc=.;
		scen_dx_inctype="";
		scen_dx_vtype="";
		scen_dx_vtime=.;
		scen_dx_dx2dt=.;
		scen_dx_vdt=.;
	end;
	if dx=1 then do;
		if scen_dx_inc=. and .<date-scen_dx_dx2dt<=730 then do;
			scen_dx_inc=scen_dx_dx2dt;
			scen_dx_vdt=date;
			scen_dx_vtime=date-scen_dx_inc;
			scen_dx_inctype="1";
			scen_dx_vtype="1";
		end;
		else if scen_dx_inc=. then scen_dx_dx2dt=date;
	end;
	
	* Scenario RX: dx +dx, dx + Rx;
	array scen_dxrx_dxdt_ [&time.] _temporary_;
	array scen_dxrx_type_ [&time.] $4. _temporary_;
	
	retain scen_dxrx_inc scen_dxrx_dxdt scen_dxrx_dx2dt scen_dxrx_vdt scen_dxrx_vtime scen_dxrx_inctype scen_dxrx_vtype scen_dxrx_dx2type;
	format scen_dxrx_inc scen_dxrx_dxdt scen_dxrx_dx2dt scen_dxrx_vdt mmddyy10.
				 scen_dxrx_inctype scen_dxrx_vtype scen_dxrx_dx2type $4.;
	if first.bene_id then do;
		scen_dxrx_inc=.;
		scen_dxrx_vtime=.;
		scen_dxrx_dxdt=.;
		scen_dxrx_dx2dt=.;
		scen_dxrx_dx2type="";
		scen_dxrx_vdt=.;
		scen_dxrx_inctype="";
		scen_dxrx_vtype="";
		do i=1 to &time.;
			scen_dxrx_dxdt_[i]=.;
			scen_dxrx_type_[i]="";
		end;
	end;
	day=date-mdy(1,1,&minyear.)+1;
	start=max(1,date-mdy(1,1,&minyear.)-730+1);
	end=min(day,&time.);
	if (dx or ADdrug) and 1<=day<=&time. then do;
		scen_dxrx_dxdt_[day]=date;
		if dx then substr(scen_dxrx_type_[day],1,1)="1";
		if addrug then substr(scen_dxrx_type_[day],2,1)="2";
	end;
	if scen_dxrx_inc=. then do;
		do i=start to end;
			if (find(scen_dxrx_type_[i],"1")) and scen_dxrx_dxdt=. then scen_dxrx_dxdt=scen_dxrx_dxdt_[i];	
			* getting second qualifying;
			if scen_dxrx_dx2dt=. then do;
				if (scen_dxrx_type_[i]="1" and scen_dxrx_dxdt_[i]>scen_dxrx_dxdt)
				or (find(scen_dxrx_type_[i],"2")) then do;
					scen_dxrx_dx2dt=scen_dxrx_dxdt_[i];
					scen_dxrx_dx2type=scen_dxrx_type_[i];
				end;
			end;
		end;
		if scen_dxrx_dxdt ne . and scen_dxrx_dx2dt ne . then do;
			if scen_dxrx_dxdt<=scen_dxrx_dx2dt then do;
				scen_dxrx_inc=scen_dxrx_dxdt;
				scen_dxrx_vdt=scen_dxrx_dx2dt;
				if scen_dxrx_dxdt<scen_dxrx_dx2dt then substr(scen_dxrx_inctype,1,1)="1";
				if scen_dxrx_dxdt=scen_dxrx_dx2dt then scen_dxrx_inctype="12";
				scen_dxrx_vtype=scen_dxrx_dx2type;
				scen_dxrx_vtime=scen_dxrx_dx2dt-scen_dxrx_dxdt;
			end;
			if scen_dxrx_dx2dt<scen_dxrx_dxdt then do;
				scen_dxrx_inc=scen_dxrx_dx2dt;
				scen_dxrx_vdt=scen_dxrx_dxdt;
				scen_dxrx_inctype=scen_dxrx_dx2type;
				scen_dxrx_vtype="1";
				scen_dxrx_vtime=scen_dxrx_dxdt-scen_dxrx_dx2dt;
			end;
		end;
		else do;
			scen_dxrx_dxdt=.;
			scen_dxrx_dx2dt=.;
			scen_dxrx_dx2type="";
		end;
	end;
		
	* Scenario symp: dx +dx, dx + symp;
	array scen_dxsymp_dxdt_ [&time.] _temporary_;
	array scen_dxsymp_type_ [&time.] $4. _temporary_;
	
	retain scen_dxsymp_inc scen_dxsymp_dxdt scen_dxsymp_dx2dt scen_dxsymp_vdt scen_dxsymp_vtime scen_dxsymp_inctype scen_dxsymp_vtype scen_dxsymp_dx2type;
	format scen_dxsymp_inc scen_dxsymp_dxdt scen_dxsymp_dx2dt scen_dxsymp_vdt mmddyy10.
				 scen_dxsymp_inctype scen_dxsymp_vtype scen_dxsymp_dx2type $4.;
	if first.bene_id then do;
		scen_dxsymp_inc=.;
		scen_dxsymp_vtime=.;
		scen_dxsymp_dxdt=.;
		scen_dxsymp_dx2dt=.;
		scen_dxsymp_dx2type="";
		scen_dxsymp_vdt=.;
		scen_dxsymp_inctype="";
		scen_dxsymp_vtype="";
		do i=1 to &time.;
			scen_dxsymp_dxdt_[i]=.;
			scen_dxsymp_type_[i]="";
		end;
	end;
	day=date-mdy(1,1,&minyear.)+1;
	start=max(1,date-mdy(1,1,&minyear.)-730+1);
	end=min(day,&time.);
	if (dx or symptom) and 1<=day<=&time. then do;
		scen_dxsymp_dxdt_[day]=date;
		if dx then substr(scen_dxsymp_type_[day],1,1)="1";
		if symptom then substr(scen_dxsymp_type_[day],3,1)="3";
	end;
	if scen_dxsymp_inc=. then do;
		do i=start to end;
			if (find(scen_dxsymp_type_[i],"1")) and scen_dxsymp_dxdt=. then scen_dxsymp_dxdt=scen_dxsymp_dxdt_[i];	
			* getting second qualifying;
			if scen_dxsymp_dx2dt=. then do;
				if (scen_dxsymp_type_[i]="1" and scen_dxsymp_dxdt_[i]>scen_dxsymp_dxdt)
				or (find(scen_dxsymp_type_[i],"3")) then do;
					scen_dxsymp_dx2dt=scen_dxsymp_dxdt_[i];
					scen_dxsymp_dx2type=scen_dxsymp_type_[i];
				end;
			end;
		end;
		if scen_dxsymp_dxdt ne . and scen_dxsymp_dx2dt ne . then do;
			if scen_dxsymp_dxdt<=scen_dxsymp_dx2dt then do;
				scen_dxsymp_inc=scen_dxsymp_dxdt;
				scen_dxsymp_vdt=scen_dxsymp_dx2dt;
				if scen_dxsymp_dxdt<scen_dxsymp_dx2dt then substr(scen_dxsymp_inctype,1,1)="1";
				if scen_dxsymp_dxdt=scen_dxsymp_dx2dt then scen_dxsymp_inctype="1 3";
				scen_dxsymp_vtype=scen_dxsymp_dx2type;
				scen_dxsymp_vtime=scen_dxsymp_dx2dt-scen_dxsymp_dxdt;
			end;
			if scen_dxsymp_dx2dt<scen_dxsymp_dxdt then do;
				scen_dxsymp_inc=scen_dxsymp_dx2dt;
				scen_dxsymp_vdt=scen_dxsymp_dxdt;
				scen_dxsymp_inctype=scen_dxsymp_dx2type;
				scen_dxsymp_vtype="1";
				scen_dxsymp_vtime=scen_dxsymp_dxdt-scen_dxsymp_dx2dt;
			end;
		end;
		else do;
			scen_dxsymp_dxdt=.;
			scen_dxsymp_dx2dt=.;
			scen_dxsymp_dx2type="";
		end;
	end;

	* Scenario All: DX, RX, SYmp;
	array scen_dxrxsymp_dxdt_ [&time.] _temporary_;
	array scen_dxrxsymp_type_ [&time.] $4. _temporary_;
	
	retain scen_dxrxsymp_inc scen_dxrxsymp_dxdt scen_dxrxsymp_dx2dt scen_dxrxsymp_vdt scen_dxrxsymp_vtime scen_dxrxsymp_inctype scen_dxrxsymp_vtype scen_dxrxsymp_dx2type;
	format scen_dxrxsymp_inc scen_dxrxsymp_dxdt scen_dxrxsymp_dx2dt scen_dxrxsymp_vdt mmddyy10.
				 scen_dxrxsymp_inctype scen_dxrxsymp_vtype scen_dxrxsymp_dx2type $4.;
	if first.bene_id then do;
		scen_dxrxsymp_inc=.;
		scen_dxrxsymp_vtime=.;
		scen_dxrxsymp_dxdt=.;
		scen_dxrxsymp_dx2dt=.;
		scen_dxrxsymp_dx2type="";
		scen_dxrxsymp_vdt=.;
		scen_dxrxsymp_inctype="";
		scen_dxrxsymp_vtype="";
		do i=1 to &time.;
			scen_dxrxsymp_dxdt_[i]=.;
			scen_dxrxsymp_type_[i]="";
		end;
	end;
	day=date-mdy(1,1,&minyear.)+1;
	start=max(1,date-mdy(1,1,&minyear.)-730+1);
	end=min(day,&time.);
	if (dx or ADdrug or symptom) and 1<=day<=&time. then do;
		scen_dxrxsymp_dxdt_[day]=date;
		if dx then substr(scen_dxrxsymp_type_[day],1,1)="1";
		if addrug then substr(scen_dxrxsymp_type_[day],2,1)="2";
		if symptom then substr(scen_dxrxsymp_type_[day],3,1)="3";
	end;
	if scen_dxrxsymp_inc=. then do;
		do i=start to end;
			if (find(scen_dxrxsymp_type_[i],"1")) and scen_dxrxsymp_dxdt=. then scen_dxrxsymp_dxdt=scen_dxrxsymp_dxdt_[i];	
			* getting second qualifying;
			if scen_dxrxsymp_dx2dt=. then do;
				if (scen_dxrxsymp_type_[i]="1" and scen_dxrxsymp_dxdt_[i]>scen_dxrxsymp_dxdt)
				or (find(scen_dxrxsymp_type_[i],"2")) or (find(scen_dxrxsymp_type_[i],"3")) then do;
					scen_dxrxsymp_dx2dt=scen_dxrxsymp_dxdt_[i];
					scen_dxrxsymp_dx2type=scen_dxrxsymp_type_[i];
				end;
			end;
		end;
		if scen_dxrxsymp_dxdt ne . and scen_dxrxsymp_dx2dt ne . then do;
			if scen_dxrxsymp_dxdt<=scen_dxrxsymp_dx2dt then do;
				scen_dxrxsymp_inc=scen_dxrxsymp_dxdt;
				scen_dxrxsymp_vdt=scen_dxrxsymp_dx2dt;
				if scen_dxrxsymp_dxdt<scen_dxrxsymp_dx2dt then substr(scen_dxrxsymp_inctype,1,1)="1";
				if scen_dxrxsymp_dxdt=scen_dxrxsymp_dx2dt then scen_dxrxsymp_inctype=scen_dxrx_dx2type;
				scen_dxrxsymp_vtype=scen_dxrxsymp_dx2type;
				scen_dxrxsymp_vtime=scen_dxrxsymp_dx2dt-scen_dxrxsymp_dxdt;
			end;
			if scen_dxrxsymp_dx2dt<scen_dxrxsymp_dxdt then do;
				scen_dxrxsymp_inc=scen_dxrxsymp_dx2dt;
				scen_dxrxsymp_vdt=scen_dxrxsymp_dxdt;
				scen_dxrxsymp_inctype=scen_dxrxsymp_dx2type;
				scen_dxrxsymp_vtype="1";
				scen_dxrxsymp_vtime=scen_dxrxsymp_dxdt-scen_dxrxsymp_dx2dt;
			end;
		end;
		else do;
			scen_dxrxsymp_dxdt=.;
			scen_dxrxsymp_dx2dt=.;
			scen_dxrxsymp_dx2type="";
		end;
	end;
	
	* Death scenarios;
	if first.bene_id then do;
		death_dx=.;
		death_dxrx=.;
		death_dxsymp=.;
		death_dxrxsymp=.;
		death_dx_type="    ";
		death_dxrx_type="    ";
		death_dxsymp_type="    ";
		death_dxrxsymp_type="    ";
		death_dx_vtime=.;
		death_dxrx_vtime=.;
		death_dxsymp_vtime=.;
		death_dxrxsymp_vtime=.;
	end;
	retain death_dx:;
	format death_dx death_dxrx death_dxsymp death_dxrxsymp mmddyy10.;
	if death_dx=. and dx and .<death_date-date<=365 then do;
		death_dx=date;
		death_dx_vtime=death_date-date;
		death_dx_type="1";
	end;
	if death_dxrx=. and (dx or addrug) and .<death_date-date<=365 then do;
		death_dxrx=date;
		death_dxrx_vtime=death_date-date;
		if dx then substr(death_dxrx_type,1,1)="1";
		if addrug then substr(death_dxrx_type,2,1)="2";
	end;
	if death_dxsymp=. and (dx or symptom) and .<death_date-date<=365 then do;
		death_dxsymp=date;
		death_dxsymp_vtime=death_date-date;
		if dx then substr(death_dxsymp_type,1,1)="1";
		if symptom then substr(death_dxsymp_type,3,1)="3";
	end;
	if death_dxrxsymp=. and (dx or addrug or symptom) and .<death_date-date<=365 then do;
		death_dxrxsymp=date;
		death_dxrxsymp_vtime=death_date-date;
		if dx then substr(death_dxrxsymp_type,1,1)="1";
		if addrug then substr(death_dxrxsymp_type,2,1)="2";
		if symptom then substr(death_dxrxsymp_type,3,1)="3";
	end;
	
	* Using death scenario as last resort if missing;
	if last.bene_id then do;
		if scen_dx_inc=. and death_dx ne . then do;
			scen_dx_inc=death_dx;
			scen_dx_vdt=death_date;
			scen_dx_vtime=death_dx_vtime;
			scen_dx_inctype=death_dx_type;
			scen_dx_vtype="   4";
		end;
		if scen_dxrx_inc=. and death_dxrx ne . then do;
			scen_dxrx_inc=death_dxrx;
			scen_dxrx_vdt=death_date;
			scen_dxrx_vtime=death_dxrx_vtime;
			scen_dxrx_inctype=death_dxrx_type;
			scen_dxrx_vtype="   4";
		end;
		if scen_dxsymp_inc=. and death_dxsymp ne . then do;
			scen_dxsymp_inc=death_dxsymp;
			scen_dxsymp_vdt=death_date;
			scen_dxsymp_vtime=death_dxsymp_vtime;
			scen_dxsymp_inctype=death_dxsymp_type;
			scen_dxsymp_vtype="   4";
		end;
		if scen_dxrxsymp_inc=. and death_dxrxsymp ne . then do;
			scen_dxrxsymp_inc=death_dxrxsymp;
			scen_dxrxsymp_vdt=death_date;
			scen_dxrxsymp_vtime=death_dxrxsymp_vtime;
			scen_dxrxsymp_inctype=death_dxrxsymp_type;
			scen_dxrxsymp_vtype="   4";
		end;
	end;
	
	if .<scen_dx_vtime<0 then dropdx=1;
	if .<scen_dxrx_vtime<0 then dropdxrx=1;
	if .<scen_dxsymp_vtime<0 then dropdxsymp=1;
	if .<scen_dxrxsymp_vtime<0 then dropdxrxsymp=1;
	
	label 
	scen_dx_inc="ADRD incident date for scenario using only dx"
	scen_dx_vdt="Date of verification for scenario using only dx"
	scen_dx_vtime="Verification time for scenario using only dx"
	scen_dx_inctype="1-incident date is ADRD dx, 2-incident date is drug use, 3-incident date is dem symptom"
	scen_dx_vtype="1-verification date is ADRD dx, 2-verification date is drug use, 3-verification date is dem symptom, 4-verified by death"
	scen_dxrx_inc="ADRD incident date for scenario using dx and drugs"
	scen_dxrx_vdt="Date of verification for scenario using dx and drugs"
	scen_dxrx_vtime="Verification time for scenario using dx and drugs"
	scen_dxrx_inctype="1-incident date is ADRD dx, 2-incident date is drug use, 3-incident date is dem symptom"
	scen_dxrx_vtype="1-verification date is ADRD dx, 2-verification date is drug use, 3-verification date is dem symptom, 4-verified by death"
	scen_dxsymp_inc="ADRD incident date for scenario using dx and symptoms"
	scen_dxsymp_vdt="Date of verification for scenario using dx and symptoms"
	scen_dxsymp_vtime="Verification time for scenario using dx and symptoms"
	scen_dxsymp_inctype="1-incident date is ADRD dx, 2-incident date is drug use, 3-incident date is dem symptom"
	scen_dxsymp_vtype="1-verification date is ADRD dx, 2-verification date is drug use, 3-verification date is dem symptom, 4-verified by death"
	scen_dxrxsymp_inc="ADRD incident date for scenario using dx, drugs and symptoms"
	scen_dxrxsymp_vdt="Date of verification for scenario using dx, drugs and symptoms"
	scen_dxrxsymp_vtime="Verification time for scenario using dx, drugs and symptoms"
	scen_dxrxsymp_inctype="1-incident date is ADRD dx, 2-incident date is drug use, 3-incident date is dem symptom"
	scen_dxrxsymp_vtype="1-verification date is ADRD dx, 2-verification date is drug use, 3-verification date is dem symptom, 4-verified by death";	

run;

proc univariate data=analytical2 noprint
	outtable=adrdinc_long_stats; 
run;

proc print data=adrdinc_long_stats;
	
proc print data=analytical2 (obs=100); run;
	
data &outlib..ADRDinc_&minyear._&maxyear.;
	set analytical2;
	by bene_id;
	if last.bene_id;
	keep bene_id scen: drop: samp;
run;
