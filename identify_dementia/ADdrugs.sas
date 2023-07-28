/*********************************************************************************************/
title1 'Exploring AD Incidence Definition';

* Author: PF;
* Purpose: Pulling all events related to AD drug use;
* Input: part D characteristics, part D events;
* Output: addrug_events;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

**%include "header.sas";

%let minyear=2006;
%let maxyear=2018;

%let clmbyear=2006;
%let clmeyear=2018;

***** Merging to Part D Events;

%macro pde(byear=&minyear,eyear=&maxyear);

%do year=&byear %to &eyear;
	%do mo=1 %to 12;
		%if &mo<10 %then %do;
			proc sql;
				create table &tempwork..pde&year._&mo as
				select x.bene_id, x.srvc_dt, x.pde_id, x.days_suply_num as dayssply, &year as year, 
				(y.ndc ne "") as Addrug, y.donep, y.galan, y.meman, y.rivas, y.ndc, y.bn, y.gnn
				from pde&year..pde_demo_&year._0&mo as x inner join demdx.ad_ndc as y
				on x.prod_srvc_id=y.ndc
				order by bene_id, year, srvc_dt;
			quit;
		%end;
		%else %do;
			proc sql;
				create table &tempwork..pde&year._&mo as
				select x.bene_id, x.srvc_dt, x.pde_id, x.days_suply_num as dayssply, &year as year, 
				(y.ndc ne "") as Addrug, y.donep, y.galan, y.meman, y.rivas, y.ndc, y.bn, y.gnn
				from pde&year..pde_demo_&year._&mo as x inner join demdx.ad_ndc as y
				on x.prod_srvc_id=y.ndc
				order by bene_id, year, srvc_dt;
			quit;
		%end;
	%end;
%end;

%mend;

%pde(byear=&clmbyear,eyear=&clmeyear);

***** Setting all together;
data &outlib..ADdrugs_0618;
	format year best4. srvc_dt mmddyy10.;
	set &tempwork..pde:;
	by bene_id year srvc_dt;
run;                 

proc contents data=&outlib..ADdrugs_0618; run;
	
***** Creating date level part D file;
proc sql;
	create table &outlib..ADdrugs_dts_0618 as
	select bene_id, srvc_dt, year, max(ADdrug) as ADdrug, max(donep) as donep, max(galan) as galan,
	max(meman) as meman, max(rivas) as rivas, sum(dayssply) as dayssply
	from &outlib..ADdrugs_0618
	where dayssply>=14
	group by bene_id, year, srvc_dt
	order by bene_id, year, srvc_dt;
quit;

***** Checks;
proc means data=&outlib..ADdrugs_dts_0618 noprint;
	class year;
	var ADdrug donep galan meman rivas dayssply;
	output out=&tempwork..addrugs_stats (drop=_type_ _freq_) sum(ADdrug donep galan meman rivas)= mean(dayssply)=avg_dayssply;
run;

proc freq data=&outlib..ADdrugs_dts_0618 noprint; table year*bene_id / out=&tempwork..bene_byyear; run;
proc freq data=&tempwork..bene_byyear noprint; table year / out=&tempwork..bene_byyear1 (drop=percent rename=(count=total_bene)); run;
	
data &tempwork..addrugs_stats1;
	merge &tempwork..bene_byyear1 (in=a) &tempwork..addrugs_stats (in=b);
	by year;
run;

proc print data=&tempwork..addrugs_stats1; run;

/*
proc datasets library=&tempwork kill; run;
*/
	
options obs=max;
