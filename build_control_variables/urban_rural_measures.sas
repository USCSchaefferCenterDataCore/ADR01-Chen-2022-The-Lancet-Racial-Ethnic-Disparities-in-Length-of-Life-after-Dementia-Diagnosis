/*********************************************************************************************/
title1 'Area Resource File';

* Author: PF;
* Purpose: Keeping only relevant information for Urban/Rural Measures
					 Creates array of yearly variable with contemporaneous value;
* Input: ahrf2012-ahrf2013, ahrf2014-ahrf2015;
* Output: specialist.xls;

options compress=yes nocenter ls=150 ps=200 errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../../../../51866/PROGRAMS/setup.inc";
libname arf "../original_data";
libname out "../processed_data";

* There are two years for the Urban/Rural Continuum - 2003 and 2013.;
* All years between 2008-2012 will get the 2003 value, all years from 2013 on will get 2013 value.;

proc sort data=arf.ahrf2012 (keep=f00011 f00012 f0002003) out=ahrf2012; by f00011 f00012; run;
proc sort data=arf.ahrf2015 (keep=f00011	f00012 f0002013) out=ahrf2015; by f00011 f00012; run;
	
* Check for uniqueness;
data ahrf2012_ck;
	set ahrf2012;
	by f00011 f00012;
	if not(first.f00012 and last.f00012);
run;

data ahrf2015_ck;
	set ahrf2015;
	by f00011 f00012;
	if not(first.f00012 and last.f00012);
run;

* Merge;
data urbanrural;
	merge ahrf2012 (in=a) ahrf2015 (in=b);
	by f00011 f00012;
	_2012=a;
	_2015=b;
	fips_county=strip(f00011||f00012);
	* checking how many change between 2003 & 2013;
	if f0002003=f0002013 then match=1; else match=0;
	rename
	f00011=fips_state
	f0002003=urbanrural03
	f0002013=urbanrural13;
run;

proc freq data=urbanrural;
	table _2012*_2015 match;
run;

proc sort data=urbanrural; by fips_county; run;
	
* Creating array for all years;
data out.UrbanRuralCont;
	set urbanrural;
	by fips_county;
	array urbanrural [2008:2015] urbanrural2008-urbanrural2015;
	do yr=2008 to 2012;
		urbanrural[yr]=urbanrural03;
	end;
	do yr=2013 to 2015;
		urbanrural[yr]=urbanrural13;
	end;
	drop yr;
run;

proc contents data=out.urbanruralcont; run;
	
options obs=100;
proc print data=out.UrbanRuralCont; run;


	