/*********************************************************************************************/
title1 'Exploring AD Incidence Definition';

* Author: PF;
* Purpose: Pulling all claim dates with dementia diagnosis;
* Input: Pull dementia claims; 
* Output: dementia_dx_[ctyp]_2001_2016, dementia_carmrg_2001_2016, dementia_dxdt_2001_2016;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%include "../header.sas";

***** Years/Macro variables;
%let minyear=2001;
%let maxyear=2018;
%let max_demdx=26;

***** Format;
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

***** Combine diagnosis codes found from the same service type on the same date;
%macro combine_dts(typ,dropv=);
	
		title2 dementia_dx_&typ._&minyear._&maxyear to dementia_dxdt_&typ._&minyear._&maxyear;

		data dementia_dt_&typ._&minyear._&maxyear;
				set &outlib..dementia_dx_&typ._&minyear._&maxyear (drop=&dropv where=(not missing(bene_id)));
				by bene_id year demdx_dt;
				
				length _dxtypes $ 13 _demdx1-_demdx&max_demdx $ 5;
				length n_claim_typ n_add_typ _dxmax _dxmax1 3;
				retain n_claim_typ _dxmax _dxmax1 _dxtypes _demdx1-_demdx&max_demdx;
				
				array demdx [*] demdx1-demdx&max_demdx;
				array _demdx [*] _demdx1-_demdx&max_demdx;
				
				* First claim on this date. Save dementia dx-s into master list;
				if first.demdx_dt=1 then do;
						do i=1 to dim(demdx);
							_demdx[i]=demdx[i];
						end;
						_dxtypes=dxtypes;
						_dxmax=dx_max;
						_dxmax1=dx_max;
						n_claim_typ=1;
				end;
				
				* subsequent claim on same date. Add any dementia dx not found in first claim;
				else do;
						n_claim_typ=n_claim_typ+1;
						do i=1 to dx_max;
							dxfound=0;
							do j=1 to _dxmax;
								if demdx[i]=_demdx[j] then dxfound=1;
							end;
							if dxfound=0 then do; * new dx, update list;
								_dxmax=_dxmax+1;
								if _dxmax<&max_demdx then _demdx[_dxmax]=demdx[i];
								
								select (demdx[i]); * update dxtypes string;
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
               end; /* select */
            end;  /* dxfound = 0 */
         	end; /* do i=1 to _dxmax */
      	end;  /* multiple claims on same date */
      	
      	* output one obs per service_type and date;
      	if last.demdx_dt=1 then do;
      			dxtypes=_dxtypes;
      			do i=1 to dim(demdx);
      				demdx[i]=_demdx[i];
      			end;
      			n_add_typ=_dxmax-_dxmax1;
      			dx_max=_dxmax;
      			output;
      	end;
      	
     		label n_add_typ="# of dementia dx codes added from mult claims"
            n_claim_typ="# of claims with same date of same service type"
            ;
        drop _demdx: _dxmax _dxtypes i j dxfound _dxmax1;
    run;
%mend combine_dts;

%combine_dts(inpatient,
						 dropv=at_physn_npi at_physn_spclty_cd at_physn_upin
			 			 op_physn_upin op_physn_npi op_physn_spclty_cd 
			 			 ot_physn_upin ot_physn_npi ot_physn_spclty_cd 
			 			 rndrng_physn_npi rndrng_physn_spclty_cd);
%combine_dts(outpatient,
						 dropv=at_physn_npi at_physn_spclty_cd at_physn_upin 
			 			 op_physn_upin op_physn_npi op_physn_spclty_cd 
						 ot_physn_upin ot_physn_npi ot_physn_spclty_cd 
						 rfr_physn_npi rfr_physn_spclty_cd 
						 rndrng_physn_npi rndrng_physn_spclty_cd);
%combine_dts(snf,
						 dropv=at_physn_upin at_physn_npi at_physn_spclty_cd
			 			 op_physn_upin op_physn_npi op_physn_spclty_cd 
						 ot_physn_upin ot_physn_npi ot_physn_spclty_cd 
						 rndrng_physn_npi rndrng_physn_spclty_cd);
%combine_dts(hha,
						 dropv=at_physn_npi at_physn_spclty_cd at_physn_upin 
			 			 op_physn_npi op_physn_spclty_cd 
						 ot_physn_npi ot_physn_spclty_cd 
						 rfr_physn_npi rfr_physn_spclty_cd 
						 rndrng_physn_npi rndrng_physn_spclty_cd);
%combine_dts(carmrg,dropv=rfr_physn_npi rfr_physn_upin);

***** Transposing all unique physician variables by date to merge onto date file;
%macro transpose(typ,styp,phyvtypes=,at=,op=,ot=,rfr=,rndrng=,prf=);

%macro createmvar(var,list=);
	data _null_;
		%global max;
		str="&list";
		call symput('max',countw(str));
	run;
	
	data _null_;
		str="&list";
		do i=1 to &max;
			v=scan(str,i,"");
			call symput(compress("&var"||i),"&"||strip(v));
			call symput(compress("typ"||i),strip(v));
		end;
%mend;

%createmvar(var,list=&phyvtypes); run;
%do i=1 %to &max;
	%put &&var&i;
%end;

proc sql;
	%do i=1 %to &max;
		create table &&typ&i as
		select distinct bene_id, year, demdx_dt, %sysfunc(tranwrd(%quote(&&var&i),%str( ),%str(,)))
		from &outlib..dementia_dx_&typ._&minyear._&maxyear;
	%end;
quit;

%do i=1 %to &max;
	
	%let j=1;
	%let phy=%scan(&&var&i,&j," ");
	
	%do %while(%length(&phy)>0);
		proc transpose data=&&typ&i out=&phy (drop=_name_) prefix=&styp._&phy; 
			var &phy;
			by bene_id year demdx_dt;
		run;
		
		%let j=%eval(&j+1);
		%let phy=%scan(&&var&i,&j," ");
	%end;
	
%end;

data &styp._phyv;
		merge 
			%do i=1 %to &max;
				&&var&i
			%end;;
		by bene_id year demdx_dt;
run;
%mend;

%transpose(inpatient,ip,phyvtypes=at op ot rndrng,
					 at=at_physn_npi at_physn_spclty_cd at_physn_upin,
			 		 op=op_physn_upin op_physn_npi op_physn_spclty_cd,
			 		 ot=ot_physn_upin ot_physn_npi ot_physn_spclty_cd, 
			 		 rndrng=rndrng_physn_npi rndrng_physn_spclty_cd);
%transpose(hha,hha,phyvtypes=at op ot rfr rndrng,
					 at=at_physn_npi at_physn_spclty_cd at_physn_upin,
			 		 op=op_physn_npi op_physn_spclty_cd, 
					 ot=ot_physn_npi ot_physn_spclty_cd, 
					 rfr=rfr_physn_npi rfr_physn_spclty_cd, 
					 rndrng=rndrng_physn_npi rndrng_physn_spclty_cd);
%transpose(outpatient,op,phyvtypes=at op ot rfr rndrng,
					 at=at_physn_npi at_physn_spclty_cd at_physn_upin, 
			 		 op=op_physn_upin op_physn_npi op_physn_spclty_cd, 
					 ot=ot_physn_upin ot_physn_npi ot_physn_spclty_cd, 
					 rfr=rfr_physn_npi rfr_physn_spclty_cd, 
					 rndrng=rndrng_physn_npi rndrng_physn_spclty_cd);
%transpose(snf,snf,phyvtypes=at op ot rndrng,
					 at=at_physn_npi at_physn_spclty_cd at_physn_upin, 
			 		 op=op_physn_upin op_physn_npi op_physn_spclty_cd, 
					 ot=ot_physn_upin ot_physn_npi ot_physn_spclty_cd, 
					 rndrng=rndrng_physn_npi rndrng_physn_spclty_cd);
%transpose(carmrg,carmrg,phyvtypes=rfr,rfr=rfr_physn_npi rfr_physn_upin);
%transpose(carline,carline,phyvtypes=prf,prf=prf_physn_npi prf_physn_upin prvdr_spclty);

* Need to adjust so that the npi, upin and specialty codes line up if they're together and don't get cut short if there are blanks;

*****  Merge all types together;
data dementia_dt_&minyear._&maxyear;
		
		merge dementia_dt_inpatient_&minyear._&maxyear
					dementia_dt_outpatient_&minyear._&maxyear
					dementia_dt_snf_&minyear._&maxyear
					dementia_dt_hha_&minyear._&maxyear
					dementia_dt_carmrg_&minyear._&maxyear;
		by bene_id year demdx_dt clm_typ;
				
		mult_clmtyp=(first.clm_typ=0 or last.clm_typ=0);
		
		* Output summarized events, across claim types on same date?
		length claim_types $ 5 _dxtypes $ 13 _demdx1-_demdx&max_demdx $ 5;
		length n_claims n_add_dxdate _dxmax _dxmax1 dxfound 3;
		length AD FTD Vascular oth_dementia elsewhere mixed oth_demadd elsewhere_add mixed_add
					 Lewy MCI mult_clmtyp 3;
		retain claim_types n_claims _dxmax _dxmax1 _dxtypes _demdx1-_demdx&max_demdx;
		
		array demdx [*] demdx1-demdx&max_demdx;
		array _demdx [*] _demdx1-_demdx&max_demdx;
		
		if first.demdx_dt=1 then do;
			do i=1 to dim(demdx);
				_demdx[i]=demdx[i];
			end;
			_dxtypes=dxtypes;
			_dxmax=dx_max;
			_dxmax1=dx_max;
			claim_types=clm_typ;
			n_claims=n_claim_typ;
		end;
		else do; * if multiple claims on same date, merge dx lists;
			n_claims=n_claims+n_claim_typ;
			if first.clm_typ=1 then claim_types=trim(left(claim_types))||clm_typ;
			do i=1 to dx_max;
					dxfound=0;
					do j=1 to _dxmax;
						if demdx[i]=_demdx[j] then dxfound=1;
					end;
					if dxfound=0 then do; * new dx, update list;
						_dxmax=_dxmax+1;
						if _dxmax<&max_demdx then _demdx[_dxmax]=demdx[i];
						
						select (demdx[i]); * update dxtypes string;
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
			end;
		end;
			
		if last.demdx_dt=1 then do;
				* restore original variables with updated ones;
				dxtypes=_dxtypes;
				do i=1 to dim(demdx);
						demdx[i]=_demdx[i];
				end;
				dx_max=_dxmax;
				n_add_dxdate=_dxmax-_dxmax1;
				
				* categorize the type of dementia diagnoses;
				AD=(substr(dxtypes,1,1)="A");
				FTD=(substr(dxtypes,2,1)="F");
				Vascular=(substr(dxtypes,3,1)="V");
				oth_dementia=(substr(dxtypes,4,1)="S" or
											substr(dxtypes,5,1)="U");
				oth_demadd=(oth_dementia=1 or 
										substr(dxtypes,9,1)="d" or
										substr(dxtypes,10,1)="s" or
										substr(dxtypes,12,1)="p");
				Lewy=(substr(dxtypes,7,1)="l");
				MCI=(substr(dxtypes,8,1)="m");
				elsewhere=(substr(dxtypes,6,1)="E");
				elsewhere_add=(elsewhere=1 or substr(dxtypes,11,1)="e");
					
				if sum(AD,FTD,Vascular)>1 then mixed=1; else mixed=0;
				if sum(AD,FTD,Vascular,Lewy)>1 then mixed_add=1; else mixed_add=0;
				
				* took out the part of the code that categorizes dementia;
				
				output;
		end;
		
    label n_add_dxdate="# of dementia dx added from additional claim types"
         n_claims="# of claims with dem dx on same date"
         ;
   	drop _demdx: _dxmax _dxmax1 _dxtypes i j dxfound clm_typ n_claim_typ n_add_typ;

run;

data &outlib..dementia_dt_&minyear._&maxyear;
	
	merge dementia_dt_&minyear._&maxyear
				ip_phyv
				carmrg_phyv
				carline_phyv
				op_phyv
				hha_phyv
				snf_phyv;
	
	by bene_id year demdx_dt;

run;
		
proc contents data=&outlib..dementia_dt_&minyear._&maxyear; run;
	