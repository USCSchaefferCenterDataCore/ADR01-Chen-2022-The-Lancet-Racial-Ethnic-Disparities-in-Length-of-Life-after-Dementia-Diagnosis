/*********************************************************************************************/
title1 'Exploring AD Incidence Definition';

* Author: PF;
* Purpose: Run through all the Drug Characteristic Files and Compare NDCs to FDB;
* Input: part D characteristics, part D events;
* Output: addrug_events;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

**%include "header.sas";

%let minyear=2006;
%let maxyear=2018;

%macro drugchar(byear,eyear);

%do yr=&byear %to &eyear;

data &tempwork..ad_drugchar&yr.;
	set pdch&yr..drug_char_&yr._extract (rename=gnn=gnn_&yr);
	galan=(find(gnn_&yr.,'GALANTAMINE')>0);
	meman=(find(gnn_&yr.,'MEMANTINE')>0);
	RIVAS=(FIND(gnn_&yr.,'RIVASTIGMINE')>0);
	DONEP=(FIND(gnn_&yr.,'DONEPEZIL')>0);
	if max(galan,meman,rivas,donep);
run;

proc sort data=&tempwork..ad_drugchar&yr.; by ndc; run;
%end;

data &tempwork..ad_drugchar;
	merge &tempwork..ad_drugchar&byear.-&tempwork..ad_drugchar&eyear.
	base.fdb_ndc_extract (in=b keep=ndc gnn60 hic3_desc ahfs_desc tc_desc);
	by ndc;

	fdb=b;

	if max(galan,meman,rivas,donep);

	array gnn_ [&minyear.:&maxyear.] gnn_&minyear.-gnn_&maxyear.;
	do yr=&minyear. to &maxyear.;
		if gnn_[yr] ne "" then gnn=gnn_[yr];
	end;
run;
%mend;

%drugchar(&minyear.,&maxyear.);

* checking against old list;
data &tempwork..ad_drugchar_ck;
	merge &tempwork..ad_drugchar (in=a) demdx.ad_ndc (in=b);
	by ndc;

	new=a;
	old=b;

run;

data demdx.ad_ndc;
	set &tempwork..ad_drugchar;
	keep ndc galan meman donep rivas gnn bn;
run;



