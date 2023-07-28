/*********************************************************************************************/
title1 'Exploring AD Incidence Definition';

* Author: PF;
* Purpose: Pulling all claim dates with dementia diagnosis, keeping diagnosis info and 
					 diagnosing physician info;
* Input: Pull dementia claims; 
* Output: dementia_dx_[ctyp]_2001_2016, dementia_carmrg_2001_2016, dementia_dxdt_2001_2016;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../header.sas";

***** Years/Macro Variables;
%let minyear=2001;
%let maxyear=2018;
%let max_demdx=26;

***** Formats;
proc format;
	%include "demdx.fmt";
run;
 
***** Dementia Codes;
%let ccw_dx9="3310"  "33111" "33119" "3312"  "3317"  "2900"  "29010"
            "29011" "29012" "29013" "29020" "29021" "2903"  "29040" 
            "29041" "29042" "29043" "2940"  "29410" "29411" "29420" 
            "29421" "2948"  "797";
%let oth_dx9="33182" "33183" "33189" "3319" "2908" "2909" "2949" "78093" "7843" "78469";

%let ccw_dx10="F0150" "F0151" "F0280" "F0281" "F0390" "F0391" "F04" "G132" "G138" "F05"
							"F061" "F068" "G300" "G301" "G308" "G309" "G311" "G312" "G3101" "G3109"
							"G914" "G94" "R4181" "R54";

%let oth_dx10="G3183" "G3184" "G3189" "G319" "R411" "R412" "R413" "R4701" "R481" "R482" "R488" "F07" "F0789" "F079" "F09";
							
***** ICD9;
	***** Dementia Codes by type;
	%let AD_dx9="3310";
	%let ftd_dx9="33111", "33119";
	%let vasc_dx9="29040", "29041", "29042", "29043";
	%let senile_dx9="29010", "29011", "29012", "29013", "3312", "2900",  "29020", "29021", "2903", "797";
	%let unspec_dx9="29420", "29421";
	%let class_else9="3317", "2940", "29410", "29411", "2948" ;

	***** Other dementia dx codes not on the ccw list;
	%let lewy_dx9="33182";
	%let mci_dx9="33183";
	%let degen9="33189", "3319";
	%let oth_sen9="2908", "2909";
	%let oth_clelse9="2949";
	%let dem_symp9="78093", "7843", "78469","33183"; * includes MCI;

***** ICD10;
	***** Dementia Codes by type;
	%let AD_dx10="G300", "G301", "G308", "G309";
	%let ftd_dx10="G3101", "G3109";
	%let vasc_dx10="F0150", "F0151";
	%let senile_dx10="G311", "R4181", "R54";
	%let unspec_dx10="F0390", "F0391";
	%let class_else10="F0280", "F0281", "F04","F068","G138", "G94";
	* Excluded because no ICD-9 equivalent
					  G31.2 - Degeneration of nervous system due to alochol
						G91.4 - Hydrocephalus in diseases classified elsew
						F05 - Delirium due to known physiological cond
						F06.1 - Catatonic disorder due to known physiological cond
						G13.2 - Systemic atrophy aff cnsl in myxedema;
						
	***** Other dementia dx codes not on the ccw list or removed from the CCW list;
	%let lewy_dx10="G3183";
	%let mci_dx10="G3184";
	%let degen10="G3189","G319";
	%let oth_clelse10="F07","F0789","F079","F09";
	%let dem_symp10="R411","R412","R413","R4701","R481","R482","R488","G3184"; * includes MCI;
	%let ccw_excl_dx10="G312","G914","F05", "F061","G132";
	
%macro getdx(ctyp,byear,eyear,dxv=,dropv=,keepv=,byvar=);
	%do year=&byear %to &eyear;
		data &outlib..dementia_dx_&ctyp._&year;
		
			set 
				
			%if &year<2017 %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rif&year..&ctyp._claims_0&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
					%else %if &mo>=10 %then %do;
						rif&year..&ctyp._claims_&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
				%end;
			%end;
			%else %if &year>=2017 %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rifq&year..&ctyp._claims_0&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
					%else %if &mo>=10 %then %do;
						rifq&year..&ctyp._claims_&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
				%end;
			%end;
			;
			by bene_id &byvar;

		length demdx1-demdx&max_demdx $ 5 dxtypes $ 13;
		length n_ccwdem n_othdem n_demdx dxsub 3;
		
		* Count how many dementia-related dx are found, separately by ccw list and other list;
		*	Keep thru_dt as dx_date;
		* Keep first 5 dx codes found;
		
		array diag [*] icd_dgns_cd: &dxv;
		array demdx [*] demdx1-demdx&max_demdx;
		
		year=year(clm_thru_dt);
		
		n_ccwdem=0;
		n_othdem=0;
		dxsub=0;
		
		do i=1 to dim(diag);
			if diag[i] in(&ccw_dx9,&ccw_dx10) then n_ccwdem=n_ccwdem+1; * Counting total number of CCW dementia diagnoses;
			if diag[i] in(&oth_dx9,&oth_dx10) then n_othdem=n_othdem+1; * Counting total number of other dementia diagnoses;
			* If a dementia diagnosis, checking if already accounted for, if not then creating a variable with diagnosis;
			if diag[i] in (&ccw_dx9,&ccw_dx10,&oth_dx9,&oth_dx10) then do; 
				found=0;
				do j=1 to dxsub;
					if diag[i]=demdx[j] then found=j;
				end;
				if found=0 then do;
					dxsub=dxsub+1;
					if dxsub<=&max_demdx then demdx[dxsub]=diag[i];
				end;
			end;
		end;
		
		if n_ccwdem=0 and n_othdem=0 then delete;
		else demdx_dt=clm_thru_dt;
		
		n_demdx=sum(n_ccwdem,n_othdem);
		
		* Summarize the types of dementia dx into a string: AFVSUElmdsep, uppercase are CCW dx, lowercase are others;
		
		do j=1 to dxsub;
			select (demdx[j]);
         when (&AD_dx9,&AD_dx10)  substr(dxtypes,1,1)="A";
         when (&ftd_dx9,&ftd_dx10) substr(dxtypes,2,1)="F";
         when (&vasc_dx9,&vasc_dx10) substr(dxtypes,3,1)="V";
         when (&senile_dx9,&senile_dx10) substr(dxtypes,4,1)="S";
	       when (&unspec_dx9,&unspec_dx10) substr(dxtypes,5,1)="U";
	       when (&class_else9,&class_else10) substr(dxtypes,6,1)="E";
	       when (&lewy_dx9,&lewy_dx10) substr(dxtypes,7,1)="l";
	       when (&mci_dx9,&mci_dx10) substr(dxtypes,8,1)="m";
	       when (&degen9,&degen10) substr(dxtypes,9,1)="d";
	       when (&oth_sen9) substr(dxtypes,10,1)="s";
	       when (&oth_clelse9,&oth_clelse10) substr(dxtypes,11,1)="e";
	       when (&dem_symp9,&dem_symp10) substr(dxtypes,12,1)="p";
         otherwise substr(dxtypes,13,1)="X";
      end;
   	end;
       
    length clm_typ $1;
    
    if "%substr(&ctyp,1,1)" = "i" then clm_typ="1"; /* inpatient */
    else if "%substr(&ctyp,1,1)" = "s" then clm_typ="2"; /* SNF */
    else if "%substr(&ctyp,1,1)" = "o" then clm_typ="3"; /* outpatient */
    else if "%substr(&ctyp,1,1)" = "h" then clm_typ="4"; /* home health */
    else if "%substr(&ctyp,1,1)" = "b" then clm_typ="5"; /* carrier */
    else clm_typ="X";  
    
		drop icd_dgns_cd: &dxv clm_thru_dt i j;
		rename dxsub=dx_max;
		
    label n_ccwdem="# of CCW dementia dx"
      n_othdem="# of other dementia dx"
      n_demdx="Total # of dementia dx"
      dxsub="# of unique dementia dx"
      demdx1="Dementia diagnosis 1"
      demdx2="Dementia diagnosis 2"
      demdx3="Dementia diagnosis 3"
      demdx4="Dementia diagnosis 4"
      demdx5="Dementia diagnosis 5"
      demdx6="Dementia diagnosis 6"
      demdx7="Dementia diagnosis 7"
      demdx8="Dementia diagnosis 8"
      demdx9="Dementia diagnosis 9"
      demdx10="Dementia diagnosis 10"
      demdx11="Dementia diagnosis 11"
      demdx12="Dementia diagnosis 12"
			demdx13="Dementia diagnosis 13"
			demdx14="Dementia diagnosis 14"
			demdx15="Dementia diagnosis 15"
			demdx16="Dementia diagnosis 16"
			demdx17="Dementia diagnosis 17"
			demdx18="Dementia diagnosis 18"
			demdx19="Dementia diagnosis 19"
			demdx20="Dementia diagnosis 20"
			demdx21="Dementia diagnosis 21"
			demdx22="Dementia diagnosis 22"
			demdx23="Dementia diagnosis 23"
      demdx24="Dementia diagnosis 24"
      demdx25="Dementia diagnosis 25"
      demdx26="Dementia diagnosis 26"
      demdx_dt="Date of dementia diagnosis"
      dxtypes="String summarizing types of dementia dx"
      clm_typ="Type of claim";
      
run;	
%if %upcase(&ctyp) ne BCARRIER %then %do;
proc sort data=&outlib..dementia_dx_&ctyp._&year; by bene_id year demdx_dt clm_typ; run;
%end;
%end;
%mend getdx;

%macro appenddx(ctyp);
	
data &outlib..dementia_dx_&ctyp._&minyear._&maxyear;
		set 
	%do year=&minyear %to &maxyear;
		&outlib..dementia_dx_&ctyp._&year
	%end; ;
	by bene_id year demdx_dt clm_typ;
run;

%mend;

%getdx(bcarrier,&minyear,2004,dxv=prncpal_dgns_cd,dropv=,keepv=clm_id rfr_physn_npi rfr_physn_upin,byvar=clm_id);
%getdx(bcarrier,2005,2010,dxv=prncpal_dgns_cd,dropv=,keepv=clm_id rfr_physn_npi rfr_physn_upin,byvar=clm_id);
%getdx(bcarrier,2011,2018,dxv=prncpal_dgns_cd,dropv=,keepv=clm_id rfr_physn_npi rfr_physn_upin,byvar=clm_id);

%getdx(hha,&minyear,2004,dxv=prncpal_dgns_cd,dropv=,
			 keepv=at_physn_npi at_physn_upin);
%getdx(hha,2005,2010,dxv=prncpal_dgns_cd,dropv=,
			 keepv=at_physn_npi at_physn_spclty_cd at_physn_upin 
			 op_physn_npi op_physn_spclty_cd 
			 ot_physn_npi ot_physn_spclty_cd 
			 rfr_physn_npi rfr_physn_spclty_cd 
			 rndrng_physn_npi rndrng_physn_spclty_cd);
%getdx(hha,2011,2018,dxv=prncpal_dgns_cd,dropv=,
			 keepv=at_physn_npi at_physn_spclty_cd at_physn_upin 
			 op_physn_npi op_physn_spclty_cd 
			 ot_physn_npi ot_physn_spclty_cd 
			 rfr_physn_npi rfr_physn_spclty_cd 
			 rndrng_physn_npi rndrng_physn_spclty_cd);			
%appenddx(hha);
		
%getdx(inpatient,&minyear,2004,dxv=prncpal_dgns_cd,dropv=,
			 keepv=at_physn_npi at_physn_upin
			 			 op_physn_npi op_physn_upin
			 			 ot_physn_npi ot_physn_upin);
%getdx(inpatient,2005,2010,dxv=prncpal_dgns_cd,dropv=,
			 keepv=at_physn_npi at_physn_spclty_cd at_physn_upin
			 op_physn_upin op_physn_npi op_physn_spclty_cd 
			 ot_physn_upin ot_physn_npi ot_physn_spclty_cd 
			 rndrng_physn_npi rndrng_physn_spclty_cd);		
%getdx(inpatient,2011,2018,dxv=prncpal_dgns_cd,dropv=,
			 keepv=at_physn_npi at_physn_spclty_cd at_physn_upin
			 op_physn_upin op_physn_npi op_physn_spclty_cd 
			 ot_physn_upin ot_physn_npi ot_physn_spclty_cd 
			 rndrng_physn_npi rndrng_physn_spclty_cd);		
%appenddx(inpatient);
		
%getdx(outpatient,&minyear,2004,dxv=prncpal_dgns_cd,dropv=,
			 keepv=at_physn_npi at_physn_upin
			 			 op_physn_npi op_physn_upin
			 			 ot_physn_npi ot_physn_upin);
%getdx(outpatient,2005,2010,dxv=prncpal_dgns_cd,dropv=,
			 keepv=at_physn_npi at_physn_spclty_cd at_physn_upin 
			 op_physn_upin op_physn_npi op_physn_spclty_cd 
			 ot_physn_upin ot_physn_npi ot_physn_spclty_cd 
			 rfr_physn_npi rfr_physn_spclty_cd 
			 rndrng_physn_npi rndrng_physn_spclty_cd);	
%getdx(outpatient,2011,2018,dxv=prncpal_dgns_cd,dropv=,
			 keepv=at_physn_npi at_physn_spclty_cd at_physn_upin 
			 op_physn_upin op_physn_npi op_physn_spclty_cd 
			 ot_physn_upin ot_physn_npi ot_physn_spclty_cd 
			 rfr_physn_npi rfr_physn_spclty_cd 
			 rndrng_physn_npi rndrng_physn_spclty_cd);		
%appenddx(outpatient);

%getdx(snf,&minyear,2004,dxv=prncpal_dgns_cd,dropv=,
			 keepv=at_physn_upin at_physn_npi 
			 			 op_physn_upin ot_physn_npi
			 			 ot_physn_upin ot_physn_npi);
%getdx(snf,2005,2010,dxv=prncpal_dgns_cd,dropv=,
			 keepv=at_physn_upin at_physn_npi at_physn_spclty_cd
			 op_physn_upin op_physn_npi op_physn_spclty_cd 
			 ot_physn_upin ot_physn_npi ot_physn_spclty_cd 
			 rndrng_physn_npi rndrng_physn_spclty_cd);		
%getdx(snf,2011,2018,dxv=prncpal_dgns_cd,dropv=,
			 keepv=at_physn_upin at_physn_npi at_physn_spclty_cd
			 op_physn_upin op_physn_npi op_physn_spclty_cd 
			 ot_physn_upin ot_physn_npi ot_physn_spclty_cd 
			 rndrng_physn_npi rndrng_physn_spclty_cd);	
%appenddx(snf);

* Car line diagnoses;
%macro carline(byear,eyear);
%do year=&byear %to &eyear;
data &outlib..dementia_dx_carline_&year;
		set 
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rif&year..bcarrier_line_0&mo (keep=bene_id clm_thru_dt line_icd_dgns_cd clm_id prf_physn_npi prf_physn_upin prvdr_spclty)
					%end;
					%if &mo>=12 %then %do;
						rif&year..bcarrier_line_&mo (keep=bene_id clm_thru_dt line_icd_dgns_cd clm_id prf_physn_npi prf_physn_upin prvdr_spclty) 
					%end;
				%end;
				;
		by bene_id clm_id;

		length line_ccwdem line_othdem 3;
		length clm_typ $1 line_dxtype $1;
		
		year=year(clm_thru_dt);
		
		line_ccwdem=line_icd_dgns_cd in(&ccw_dx9,&ccw_dx10);
		line_othdem=line_icd_dgns_cd in(&oth_dx9,&oth_dx10);
		
		if line_ccwdem=0 and line_othdem=0 then delete;
		demdx_dt=clm_thru_dt;
		clm_typ="6";

		select (line_icd_dgns_cd);
       when (&AD_dx9, &AD_dx10) line_dxtype="A"; 
       when (&ftd_dx9, &ftd_dx10) line_dxtype="F"; 
       when (&vasc_dx9, &vasc_dx10) line_dxtype="V"; 
       when (&senile_dx9, &senile_dx10) line_dxtype="S"; 
       when (&unspec_dx9, &unspec_dx10) line_dxtype="U"; 
       when (&class_else9, &class_else10) line_dxtype="E"; 
       when (&lewy_dx9, &lewy_dx10) line_dxtype="l"; 
       when (&mci_dx9, &mci_dx10) line_dxtype="m"; 
       when (&degen9, &degen10) line_dxtype="d"; 
       when (&oth_sen9) line_dxtype="s"; 
       when (&oth_clelse9, &oth_clelse10) line_dxtype="e";
       when (&dem_symp9, &dem_symp10) line_dxtype="p"; 
       otherwise line_dxtype="X"; 
    end;
      
		drop clm_thru_dt;
		label line_ccwdem="Whether carrier line dx =CCW dementia dx"
      		line_othdem="Whether carrier line dx =other dementia dx"
      		line_dxtype="Type of dementia dx"
      		clm_typ="Type of claim"
      		demdx_dt="Date of dementia dx"
      		;
run;
data &outlib..dementia_dx_carmrg_&year;
		merge &outlib..dementia_dx_bcarrier_&year (in=_inclm drop=year)
					&outlib..dementia_dx_carline_&year  (in=_inline drop=clm_typ prf_physn_npi prf_physn_upin prvdr_spclty rename=(demdx_dt=linedx_dt));
		by bene_id clm_id;

		infrom=10*_inclm+_inline;
		
		length n_found n_added matchdt _maxdx in_line 3;
		length _dxtypes $ 13 _demdx1-_demdx&max_demdx $ 5;
		retain n_found n_added matchdt _maxdx _dxtypes in_line _demdx1-_demdx&max_demdx _demdx_dt;
		
		array demdx [*] demdx1-demdx&max_demdx;
		array _demdx [*] _demdx1-_demdx&max_demdx;
		
		if first.clm_id then do;
				n_found=0;
				n_added=0;
				matchdt=0;
				if _inclm=1 then _maxdx=dx_max;
				else _maxdx=0;
				if _inclm=1 then _dxtypes=dxtypes;
				else _dxtypes="";
				in_line=0;
				do i=1 to dim(demdx);
					_demdx[i]=demdx[i];
				end;
				if _inclm then _demdx_dt=demdx_dt;
				else _demdx_dt=linedx_dt;
		end;
		
		if clm_typ="" then clm_typ="5"; * treat linedx source as car;
		
		if _inline=1 then in_line=in_line+1; * count how many lines merge to a claim;
			
		if _inline then do; * if in line file then keeping track of new diagnoses;
			line_found=0;
			do i=1 to _maxdx;
				if line_icd_dgns_cd=_demdx[i] then line_found=1;
			end;
			if line_found=1 then do; * keep track of codes found on base file;
				n_found=n_found+1;
				matchdt=matchdt+(linedx_dt=demdx_dt);
			end;
			else do; * add unfound code;
				_maxdx=_maxdx+1;
				if 0<_maxdx<=&max_demdx then _demdx[_maxdx]=line_icd_dgns_cd;
				n_added=n_added+1;
				if infrom=11 then matchdt=matchdt+(linedx_dt=demdx_dt);
				else if infrom=1 then _demdx_dt=linedx_dt;
			end;	
		
		* update dxtypes;
			select (line_icd_dgns_cd);
         when (&AD_dx9,&AD_dx10)  substr(_dxtypes,1,1)="A";
         when (&ftd_dx9,&ftd_dx10) substr(_dxtypes,2,1)="F";
         when (&vasc_dx9,&vasc_dx10) substr(_dxtypes,3,1)="V";
         when (&senile_dx9,&senile_dx10) substr(_dxtypes,4,1)="S";
	       when (&unspec_dx9,&unspec_dx10) substr(_dxtypes,5,1)="U";
	       when (&class_else9,&class_else10) substr(_dxtypes,6,1)="E";
	       when (&lewy_dx9,&lewy_dx10) substr(_dxtypes,7,1)="l";
	       when (&mci_dx9,&mci_dx10) substr(_dxtypes,8,1)="m";
	       when (&degen9,&degen10) substr(_dxtypes,9,1)="d";
	       when (&oth_sen9) substr(_dxtypes,10,1)="s";
	       when (&oth_clelse9,&oth_clelse10) substr(_dxtypes,11,1)="e";
	       when (&dem_symp9,&dem_symp10) substr(_dxtypes,12,1)="p";
         otherwise substr(_dxtypes,13,1)="X"; 
    	end;
    end;

	if last.clm_id then do;
			dxtypes=_dxtypes;
			dx_max=_maxdx;
			do i=1 to dim(demdx);
				demdx[i]=_demdx[i];
			end;
			demdx_dt=_demdx_dt;
			year=year(demdx_dt);
			output;
	end;
	
	label infrom="10-only in header,1-only in line,11-header+line"
				n_added="# of codes added from line"
				in_line="# of line clms that merge to header"
				line_found="Line clm found on header"
				n_found="# of line clms found on header"
				matchdt="# of dates match w/ matching line & header clms";
	
	drop line_icd_dgns_cd line_dxtype _maxdx _dxtypes i _demdx:;
	format linedx_dt demdx_dt mmddyy10.;
	
run;
proc sort data=&outlib..dementia_dx_carmrg_&year; by bene_id year demdx_dt clm_typ; run;
%end;
%mend;

%carline(&minyear,&maxyear);
%appenddx(carmrg);

* Creating an appended carline for dealing with physician file;
%macro appendcarline;
%do year=&minyear %to &maxyear;
proc sort data=&outlib..dementia_dx_carline_&year
out=&tempwork..dementia_dx_carline_&year;
by bene_id year demdx_dt clm_typ;
run;
%end;

data &outlib..dementia_dx_carline_&minyear._&maxyear;
		set 
	%do year=&minyear %to &maxyear;
		&tempwork..dementia_dx_carline_&year
	%end; ;
	by bene_id year demdx_dt clm_typ;
run;
%mend;

%appendcarline;

***** Merge together carrier base file and line file, will deal with performing physician in next program;
proc contents data=&outlib..dementia_dx_carmrg_&minyear._&maxyear; run;
