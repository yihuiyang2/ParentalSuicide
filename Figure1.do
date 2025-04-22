**
** Firgure 1 Trend of suicide attempt
**


*Created by Yihui Yang, 2024-03-28


cd "W:\C6_Fang\WMH\Projects\Yihui\Sexdiff_suicide"

log using output/Figure1.log, text replace


frame change default
capture frame drop result1
frame create result1 prd far year ir lb ub


* Import data

use "data/data.dta", clear

*keep key variables
keep lopnr prd entry exit sui_dt sa far agec cal

* code exit
replace exit=exit+1 if entry==exit

* code event
gen fail=0
replace fail=1 if exit==sui_dt & sa==1

*pseudo id
gen obs_id = _n

* set time
stset exit, failure(fail==1) entry(time entry) exit(time exit) origin(time entry) id(obs_id)
format _origin %td

*split by year
di date("01/01/2001", "MDY")
*14976

*calculate interval between years
foreach i of num 2002/2021{
	di date("12/31/`i'", "MDY")-14976

}

stsplit year, at(364 729 1094 1460 1825 2190 2555 2921 3286 3651 4016 4382 4747 5112 5477 5843 6208 6573 6938 7304 7669) after(time=14976)

replace year=year(_origin+_t) 

*estimate follow-up time (person days)
gen fu=_t - _t0

*collapse data
collapse (sum) _d fu, by(agec year far prd)

* round person time (in years)
gen py=round(fu/365.25)

* direct standardization
gen strata=1

foreach i of num 0/1 {
	foreach j of num 2001/2021 {
		foreach t of num 1/3 {

			   qui: count if far==`i' & year==`j' & prd==`t'
			   if (r(N) > 0) {
               qui: dstdize _d py agec if far==`i' & year==`j' & prd==`t', by(strata) using(data/stdpop1)
	
               local b1= r(adj)[1,1]
               local lb= r(lb_adj)[1,1]
               local ub= r(ub_adj)[1,1]
	
               frame post result1  (`t') (`i') (`j') (`b1') (`lb') (`ub') 
			   }
	} 
 } 
} 


*load result and merge 
frame result1:list 
frame change result1
save output/figure1,replace

*import datasets
use output/figure1,clear

*replace ir, lb and ub
replace ir=ir*1000
replace lb=lb*1000
replace ub=ub*1000

*label of prd
label define prdlab 1 "Preconception" 2 "Antepartum" 3 "Postpartum"
label values prd prdlab


*generate smoothed ci using lowess
foreach i of num 0/1 {
	foreach j of num 1/3{
		
		lowess lb year if far==`i' & prd==`j', gen(lbs`i'`j') nograph
        lowess ub year if far==`i' & prd==`j', gen(ubs`i'`j') nograph
        lowess ir year if far==`i' & prd==`j', nograph gen(irs`i'`j')

		}
}

gen lbs=min(lbs01,lbs02,lbs03,lbs11,lbs12,lbs13)
gen ubs=min(ubs01,ubs02,ubs03,ubs11,ubs12,ubs13)
gen irs=min(irs01,irs02,irs03,irs11,irs12,irs13)

* plot 
twoway ///
	(rarea lbs ubs year if far==0 , color(pink) lw(none) fi(inten10)) ///
	(rarea lbs ubs year if far==1 , color(ltblue) lw(none) fi(inten20)) ///
    (scatter ir year if far==0 , msymbol(O) mcolor(red) sort) /// 
	(line irs year if far==0 , color(pink)  fi(inten10)) ///
	(scatter ir year if far==1 , msymbol(O) mcolor(midblue) sort) ///
	(line irs year if far==1 , color(navy)  fi(inten10)), ///
by(prd, rows(1) ixaxes iyaxes graphregion(color(white)) note("") legend(position(6))) ///
legend(order(4 6) lab(4 "Mothers") lab (6 "Fathers") rows(1) region(lcolor(white)) size(vsmall)) graphregion(color(white)) ///
ylabel(0(1)2, grid angle(0)) ///
xlabel(2001(5)2021) ///
ytitle("Standardized incidence rate per 1,000 person-years",size(small)) ///
xtitle("Calendar year",size(small)) ///
saving(output/figure1,replace) 


* output
graph use output/figure1
graph export output/figure1.jpg, replace

log close
