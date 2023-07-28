/* clmids.sas
   make a file at bene_id level that flags whether has any of each type of claim
   
   Aug. 2013, p.st.clair: changed length of flags to 3 and added 2009/2010   
   9/23/2014, p.st.clair: updated for DUA 25731 and to standardize macros and files used
   10/9/2015, p.st.clair: updated to run 2012 and to rerun 2002-2005 with snf included
   2/14/2018, p.ferido: adapted for the VRDC, still no Part D
*/

options compress=yes nocenter ls=150 ps=200 errors=5 errorabend errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
	
%include "../header.sas";

***** Macro for listing variables;

%macro listv(pref,types,sfx=);
    %let i=1;
    %let typ=%scan(&types,&i);
    %do %while (%length(&typ)>0);
        &pref&typ&sfx
        %let i=%eval(&i+1);
        %let typ=%scan(&types,&i);
    %end;
%mend;

***** Macro for contents - Change contentsdir;
%macro sascontents(fn,lib=work,contdir=,opt=position,domeans=N);
   proc printto print="&contdir.&fn..contents.txt" new;
   proc contents data=&lib..&fn &opt;
   run;
   %if %upcase(&domeans)=Y %then %do;
       proc means data=&lib..&fn;
       run;
   %end;
   proc printto;
   run;
%mend;

***** Macro for one year
	*** year = year of interest
	*** types= all the claim types being processed
	*** ntyp = number of claim types
	*** typstr = string that will list all the types of claims a bene has in this year;
		
%macro oneyear(year,types=,ntyp=,typstr=);

title2 clmid&year;

***** Pulling unique bene_id from each claim month file and merging to create a year file;
%let i=1;
%let typ=%scan(&types,&i);
%do %while (%length(&typ)>0);
	
	proc sql; 
			%if &typ=pde and &year ge 2006 %then %do;
				%do mo=1 %to 9;
					create table &typ.&year._&mo as
					select distinct bene_id 
					from pde&year..&typ._demo_&year._0&mo
					where bene_id ne .
					order by bene_id;
				%end;
				%do mo=10 %to 12;
					create table &typ.&year._&mo as
					select distinct bene_id
					from pde&year..&typ._demo_&year._&mo
					where bene_id ne .
					order by bene_id;
				%end;
		%end;
		%else %do;
			%do mo=1 %to 9;
				create table &typ.&year._&mo as
				select distinct bene_id 
				from rif&year..&typ._claims_0&mo
				where bene_id ne .
				order by bene_id;
			%end;
			%do mo=10 %to 12;
				create table &typ.&year._&mo as
				select distinct bene_id
				from rif&year..&typ._claims_&mo
				where bene_id ne .
				order by bene_id;
			%end;
		%end;
		quit;
		
		data &typ.&year;
			merge 
				%do mo=1 %to 12;
					&typ.&year._&mo
				%end;;
			by bene_id;
		run;
	
	%let i=%eval(&i+1);
	%let typ=%scan(&types,&i);
	
%end;

data &outlib..clmid&year;
	merge 
	
	%let i=1;
	%let typ=%scan(&types,&i);
	%do %while (%length(&typ)>0);
		&typ.&year (in=_in&typ)
		%let i=%eval(&i+1);
		%let typ=%scan(&types,&i);
	%end;
		;
	by bene_id;
	
	length typstr&year $ &ntyp;
	length %listv(in,&types,sfx=&year) 3;
	
	array _in_ [*] %listv(_in,&types);
	array in_  [*] %listv(in,&types,sfx=&year);
	
	do i=1 to dim(_in_);
		in_[i]= _in_[i];
		if in_[i]=1 then substr(typstr&year,i,1)=substr("&typstr",i,1);
	end;
	
	drop i;
run;

proc freq;
	table in: typstr&year /missing list;
run;

%sascontents(clmid&year,lib=&outlib.,domeans=Y,contdir=&contentsdir);

%mend;

%macro doyrs(begy,endy,typlist=,ntypes=,typchar=);
	%do y=&begy %to &endy;
		%oneyear(&y,types=&typlist,ntyp=&ntypes,typstr=&typchar);
	%end;
%mend;

%let types0205=bcarrier dme hha hospice inpatient outpatient snf;
%let ntyp0205=7;
%let typstr0205=cdhxios;

%let types0615=bcarrier dme hha hospice inpatient outpatient snf pde;
%let ntyp0615=8;
%let typstr0615=cdhxiosp;

%let types_med=bcarrier dme hha hospice inpatient outpatient snf;
%let ntyp_med=7;
%let typstr_med=cdhxios;

%let types_wpde=bcarrier dme hha hospice inpatient outpatient snf pde;
%let ntyp_wpde=8;
%let typstr_wpde=cdhxiosp;

%doyrs(2001,2001,typlist=&types0205,ntypes=&ntyp0205,typchar=&typstr0205);
%doyrs(2002,2005,typlist=&types0205,ntypes=&ntyp0205,typchar=&typstr0205);
%doyrs(2006,2015,typlist=&types0615,ntypes=&ntyp0615,typchar=&typstr0615);
%doyrs(2016,2016,typlist=&types0205,ntypes=&ntyp0205,typchar=&typstr0205);
%doyrs(2017,2017,typlist=&types_wpde,ntypes=&ntyp_wpde,typchar=&typstr_wpde); * running on the annual file;
%doyrs(2018,2018,libq=q,typlist=&types_med,ntypes=&ntyp_med,typchar=&typstr_med); * running quarterly all the way to the end;


