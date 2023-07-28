/* bene_demog.sas
   make a file of beneficiary non-time-varying demographics
   Provide best guess birth and death dates, gender, race.
   
   SAMPLE: all benes on denominator or bsf, no duplicates, over all years.
   Level of observation: bene_id
   
   Input files: mbsf_ab_[yyyy],clmid[yyyy]
   Output files: bene_demog
   
   March 10, 2014, p. st.clair
   July 2, 2014, p. st.clair: changed to keep first sex, birthdate, deathdate, race
   		instead of the last.  This way if any conflict, the value won't change as we
   		add more years.
  October 30, 2014, p. st.clair: generalized for transition to DUA 25731
  October 8, 2015: update to add 2012.  Will also incorporate problem with 2002-2005 (snf clmids not checked)
  January 7, 2016: update to add 2013. Also made this file a versioned file by last year included.
     Note that for now, the Part D data is not available for 2013, so in 2013, check for claims will be 
     just using Part AB claims. Also added a check for in hmo entire time--these benes may not have
     any claims.
  February 14, 2018: p. ferido - adapted for the VRDC
*/

options compress=yes nocenter ls=150 ps=200 replace errors=5 errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;

* %include "../header.sas";

***** Setting min and max years;
%let minyr=2001;
%let maxyr=2018;

***** Macro for contents - change contentsdir above;
%macro sascontents(fn,lib=work,contdir=,opt=position,domeans=N);
   proc printto print="&contdir.&fn..contents.txt" new;
   proc contents data=&lib..&fn &opt;
   run;
   %if %upcase(&domeans)=Y %then %do;
       proc means data=&lib..&fn n mean stddev;
       run;
   %end;
   proc printto;
   run;
%mend;

***** SAS Formats;
proc format;
/* for the veryold variable on bene_demog */
  value $veryold
  "0"="0.90 or less"
  "1"-"5"="1-5.91-high"
  ;
  value dysame
  0="0.death yr bef year reported less 1"
  1="1.same as year reported"
  2="2.death yr=year-1"
  3="3.death yr=year+1"
  9="9.death yr 2+ years after reported"
  ;
run;

***** macro to list clmid files for all years in merge statement;
%macro clmid_files (byear=&minyr, eyear=&maxyr);
   %do year = &byear %to &eyear;
       &outlib..clmid&year (in=_%substr(&year,3) keep=bene_id typstr&year)
   %end;
%mend;

***** macro to rename variables;
%macro den_rename (yr, dob, dod, dodsw, rti_race, race, sex, hmo_mo, hmoc=N);
   rename=(&dob=bdt&yr &dod=ddt&yr &dodsw=dodsw&yr
   
   %if %length(&rti_race)>0 %then 
           &rti_race=rti_race&yr ;
		
           &hmo_mo=hmo_mo&yr &race=race&yr &sex=sex&yr )

%mend;

%let vars0205=bene_birth_dt bene_death_dt bene_valid_death_dt_sw rti_race_cd bene_race_cd bene_sex_ident_cd bene_hmo_cvrage_tot_mons;
%let vars0615=bene_birth_dt bene_death_dt valid_death_dt_sw rti_race_cd bene_race_cd sex_ident_cd bene_hmo_cvrage_tot_mons;

data clmids;
	merge %clmid_files (byear=&minyr, eyear=&maxyr);
	by bene_id;
	
	length first_claim_yr last_claim_yr 3;
	
	array in_ [*] _01-_%substr(&maxyr,3);
	
	last_claim_yr=0;
	
	do i=1 to dim(in_);
		if in_[i]=1 then do;
			last_claim_yr=i+2000;
			if first_claim_yr=. then first_claim_yr=i+2000;
		end;
	end;
	
	drop i;
run;

%macro demog;
data &outlib..bene_demogall&maxyr;

	merge clmids (in=_inc)
		%do yr=&minyr %to &maxyr;
			%if &yr<=2005 %then %do;
				mbsf.mbsf_ab_&yr (in=_%substr(&yr,3) keep=bene_id &vars0205 %den_rename(%substr(&yr,3),bene_birth_dt,bene_death_dt,bene_valid_death_dt_sw,rti_race_cd,bene_race_cd,bene_sex_ident_cd,bene_hmo_cvrage_tot_mons))
			%end;
			%else %if &yr<=&demogv %then %do;
				mbsf.mbsf_abcd_&yr (in=_%substr(&yr,3) keep=bene_id &vars0615 %den_rename(%substr(&yr,3),bene_birth_dt,bene_death_dt,valid_death_dt_sw,rti_race_cd,bene_race_cd,sex_ident_cd,bene_hmo_cvrage_tot_mons))
			%end;
			%else %do;
				rifq&yr..mbsf_abcd_&yr (in=_%substr(&yr,3) keep=bene_id &vars0615 %den_rename(%substr(&yr,3),bene_birth_dt,bene_death_dt,valid_death_dt_sw,rti_race_cd,bene_race_cd,sex_ident_cd,bene_hmo_cvrage_tot_mons))
			 %end;
		%end;;
	
	by bene_id;
	
	dupdem=first.bene_id=0 or last.bene_id=0;
	
	inclaims=_inc;
   
   length birth_date death_date _minbdt _maxbdt _minddt _maxddt 8;
   length death_v_sw sex race_bg race_alt anyprob anybigprob veryold racesrc_rti
          in&minyr-in&maxyr dropflag _inany $ 1;
   length bene_prob n_years 3;
   length _sexprob _yobprob _mobprob _yodprob _modprob _dodprob _raceprob _raceproba
          _dysame _yobdiff 3;
          
   label birth_date="Bene birth date (first)"
         death_date="Bene death date (first)"
         death_v_sw="Whether death date verified"
         sex="Bene sex (first)"
         race_bg="Bene race (first RTI_RACE or first RACE)"
         racesrc_rti="Whether race taken from RTI_RACE (Y/N)"
         bene_prob="Flag for bene problems"
         anyprob="Whether any inconsistency across years (Y/N)"
         anybigprob="Whether any inconsistency with sex, birth or death year (Y/N)"
         _yobdiff="Difference between min and max birth year"
         veryold="Categorizes age by decades if 91 and older"
         n_years="# of years bene is present &minyr-&maxyr"
         last_claim_yr="Last year bene has a claim/&minyr-&maxyr"
         first_claim_yr="First year bene has a claim/&minyr-&maxyr"
         dropflag="Benes with anybigprob or >120 or >90 and no claims (Y/N)"
         ;
    
    array _in_[&minyr:&maxyr] _%substr(&minyr,3) - _%substr(&maxyr,3);
    array in_[&minyr:&maxyr] in&minyr-in&maxyr;
    array sex_[&minyr:&maxyr] sex%substr(&minyr,3)-sex%substr(&maxyr,3);
    array died_[&minyr:&maxyr] died%substr(&minyr,3)-died%substr(&maxyr,3);
    array bdt_[&minyr:&maxyr] bdt%substr(&minyr,3)-bdt%substr(&maxyr,3);
    array ddt_[&minyr:&maxyr] ddt%substr(&minyr,3)-ddt%substr(&maxyr,3);
    array dodsw_[&minyr:&maxyr] dodsw%substr(&minyr,3)-dodsw%substr(&maxyr,3);
    array race_[&minyr:&maxyr] race%substr(&minyr,3)-race%substr(&maxyr,3);
    array rti_race_[2006:&maxyr] rti_race06-rti_race%substr(&maxyr,3);
    array hmo_mo_[&minyr:&maxyr] hmo_mo%substr(&minyr,3)-hmo_mo%substr(&maxyr,3);
    
    bene_prob=0;
    _sexprob=0;
    _yobprob=0;
    _mobprob=0;
    _yodprob=0;
    _modprob=0;
    _dodprob=0;
    _raceprob=0;
    _raceproba=0;
    _minbdt=.;
    _maxbdt=.;
    _minddt=.;
    _maxddt=.;
    _dysame=.;
    _firsty=.;
    n_years=0;
    n_hmoyrs=0;
    _lasty=.;
    _inany="N";
    do y=&minyr to &maxyr;
       
       if _in_[y]=1 then in_[y]="Y";
       else in_[y]="N";
       
       if in_[y]="Y" then do;
          
          _inany="Y";
          if _firsty=. then _firsty=y;
          _lasty=y;
           
          if missing(sex) and sex_[y] in ("1","2") then sex=sex_[y];
          else if sex_[y] in ("1","2") and sex ne sex_[y] then _sexprob=_sexprob+1;
          
		  if y>2005 then do;  /* rti_race begins in 2006 */
             if missing(race_bg) and "1"<=rti_race_[y]<="6" then do;
                race_bg=rti_race_[y];
                racesrc_rti="Y";
			 end;
             else if "1"<=rti_race_[y]<="6" and race_bg ne rti_race_[y] then _raceprob=_raceprob+1;
          end;

          if missing(race_alt) and "1"<=race_[y]<="6" then race_alt=race_[y];
          else if "1"<=race_[y]<="6" and race_alt ne race_[y] then _raceproba=_raceproba+1;
          
          if birth_date=. then birth_date=bdt_[y];
          else do;
             if year(birth_date) ne year(bdt_[y]) then _yobprob=_yobprob+1;
             if month(birth_date) ne month(bdt_[y]) then _mobprob=_mobprob+1;
          end;
          _minbdt=min(_minbdt,bdt_[y]);
          _maxbdt=max(_maxbdt,bdt_[y]);
          
          if ddt_[y] ne . then do;
             if death_date=. then do;
                death_date=ddt_[y];
                death_v_sw=dodsw_[y];
                _dysame=(year(death_date)=y);
                if _dysame=0 and (year(death_date)+1) = y then _dysame=2;
                else if _dysame=0 and (year(death_date)-1) = y then _dysame=3;
                else if _dysame=0 and year(death_date)>y then _dysame=9;
             end;
             else do;
                if year(death_date) ne year(ddt_[y]) then _yodprob=_yodprob+1;
                if month(death_date) ne month(ddt_[y]) then _modprob=_modprob+1;
             end;
             _minddt=min(_minddt,ddt_[y]);
             _maxddt=max(_maxddt,ddt_[y]);
          end;
          
          if hmo_mo_[y]=12 then n_hmoyrs=n_hmoyrs + 1;
          else if hmo_mo_[y] >= month(ddt_[y]) and year(ddt_[y])=y then n_hmoyrs=n_hmoyrs + 1;
          
          n_years=n_years+1;
          
       end;  /* if bene in this year */

    end;  /* loop through all years */
    
    if missing(race_bg) and "1"<=race_alt<="6" then do;
       racesrc_rti="N";
       race_bg=race_alt;
    end;
    if _lasty>(year(death_date)+1)>.Z then _dodprob=_dodprob+1;
    
    bene_prob=1000*(_sexprob>0) + 100*(_yobprob>0) + 200*(_mobprob>0) + 
              10*(_yodprob>0) + 20*(_modprob>0) + 40*(_dodprob>0) + (_raceprob>0);
    
    if _yobprob>0 then _yobdiff=year(_maxbdt) - year(_minbdt);
    if _yodprob>0 then _yoddiff=year(_maxddt) - year(_minddt);
    
    if (_sexprob>0) or (_yobprob>0) or (_mobprob>0) or 
       (_yodprob>0) or (_modprob>0) or (_dodprob>0) or 
       (_raceprob>0) or (_raceproba>0) or 
       missing(sex) or missing(birth_date) then anyprob="Y";
    else anyprob="N";
    
    if (_sexprob>0) or (_yobprob>0) or (_yodprob>0) or (_dodprob>0) or
       missing(sex) or missing(birth_date) then anybigprob="Y";
    else anybigprob="N";
    
    _firstage=_firsty - year(birth_date);
    veryold="0";
    if _firstage>130 then veryold="5";
    else if _firstage>120 then veryold="4";
    else if _firstage>110 then veryold="3";
    else if _firstage>100 then veryold="2";
    else if _firstage>90 then veryold="1";
    if anybigprob="Y" or veryold in ("4","5") or 
       /* 90+ and no claim and not in HMO entire time */ 
       (veryold in ("1","2","3") and last_claim_yr=. and 
          n_hmoyrs<(_lasty - _firsty +1)) then dropflag="Y";
    else dropflag="N";
    
run;
%mend;

%demog;

proc sort data=&outlib..bene_demogall&maxyr (where=(dupdem=0 and _inany="Y"))
          out=&outlib..bene_demog&maxyr (keep=bene_id in&minyr-in&maxyr n_years sex birth_date death_date death_v_sw 
                                     race_bg racesrc_rti bene_prob anyprob anybigprob veryold last_claim_yr 
                                     first_claim_yr _yobdiff dropflag);
   by bene_id;
run;

proc freq data=&outlib..bene_demog&maxyr;
   table in&minyr-in&maxyr sex race_bg racesrc_rti death_v_sw
         birth_date death_date anyprob anybigprob veryold 
         dropflag dropflag*anybigprob*veryold*last_claim_yr
         anyprob*anybigprob anybigprob*bene_prob
         /missing list;
   format birth_date death_date year4. veryold $veryold.;
run;

%sascontents(bene_demog&maxyr,lib=&outlib.,domeans=N,
             contdir=&contentsdir)
             
proc printto print="&contentsdir.bene_demog&maxyr..contents.txt";

proc freq data=&outlib..bene_demog&maxyr;
   table in&minyr-in&maxyr sex race_bg racesrc_rti death_v_sw
         death_date anyprob anybigprob veryold 
         dropflag
         /missing list;
   format birth_date death_date year4. veryold $veryold.;
run;

proc printto;
run;

%sascontents(bene_demogall&maxyr,lib=&outlib.,domeans=N,
             contdir=&contentsdir)
             
proc freq data=&outlib..bene_demogall&maxyr;
   table  _inany dupdem _inany*(in&minyr-in&maxyr) _inany*inclaims _inany*n_years
          anyprob anybigprob dupdem dupdem*anybigprob bene_prob 
         anybigprob*_dysame anybigprob*_sexprob*_yobprob*_yodprob*_dodprob
         anybigprob*_sexprob*_yobdiff*_yoddiff
         _yobdiff _yoddiff _sexprob _yobprob _mobprob _yodprob _modprob _dodprob _raceprob
         _dysame
      /missing list;
   format _dysame dysame.;
run;

proc freq data=&outlib..bene_demogall&maxyr (where=(dropflag="Y"));
   table n_hmoyrs veryold dropflag veryold*n_hmoyrs*last_claim_yr
      /missing list;
run;

proc means data=&outlib..bene_demogall&maxyr n mean stddev ;
   class dropflag veryold;
   types () dropflag veryold dropflag*veryold;
   var n_hmoyrs n_years;
 run; 
