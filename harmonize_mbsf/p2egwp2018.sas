options ls=125 ps=50 nocenter replace compress=yes FILELOCKS=NONE;

%let subtitl=;
%let minyear=2006;
%let maxyear=2018;

%macro p2egwp;
data _null_;
   
   set 
   	%do yr=&minyear. %to &maxyear.;
		pdch&yr..plan_char_&yr._extract (in=_in%substr(&yr.,3) keep=contract_id plan_id egwp_indicator)
	%end;
	end=lastone;
   
   %do yr=&minyear. %to &maxyear.;
   	if _in%substr(&yr.,3) then year=&yr.;
   %end;;
   
   length plnid $ 14 varout $ 4;
   
   /* the raw egwp_ind variable */
   file "&fmtlib.p2egwp.fmt";
   if _N_=1 then 
      put "value $p2egwp";
   plnid=compress('"' || put(year,4.0) || contract_id || plan_id || '"');
   varout=compress('"' || egwp_indicator || '"');
   put @5 plnid "=" varout;
   if lastone then put "OTHER='M';";

run;
proc format;
   %include "&fmtlib.p2egwp.fmt";
run;
%mend;

%p2egwp;
