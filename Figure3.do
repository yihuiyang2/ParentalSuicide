**
** Figure 3 irr by week, comparing antepartum and postpartum with preconception
**

** Created by Yihui Yang, 2024-03-28
** Modified on 2025-04-03


cd "W:\C6_Fang\WMH\Projects\Yihui\Sexdiff_suicide"

log using output/Figure3.log, text replace

**# Generate spline 
*import individual level data
use data/data.dta, clear

*keep variables
keep lopnr prd entry exit sui_dt far sa prd_dt0

* code fu
replace exit=exit+1 if entry==exit

* code event
gen fail=0
replace fail=1 if exit==sui_dt & sa==1

*pseudo id
gen obs_id = _n

foreach i of num 0/1 {
	foreach j of num 1/3 {

preserve
*keep observations
keep if far==`i' & prd==`j'

*stset
stset exit, failure(fail==1) entry(time entry) origin(time prd_dt0) exit(time exit) id(obs_id)

* split by weeks
stsplit wk, every(7)
replace wk=wk/7
replace wk=wk+1

* add splines to weeks
keep wk
mkspline wksp=wk, nknot(4) cubic displayknot
mat knots = r(knots)

* 
collapse (first) wksp*, by(wk)

save data/wksp`i'`j', replace

restore
}
  }
  
*append spline data by sex
*mother
use data/wksp01, clear
append using data/wksp02 data/wksp03, generate(newv)

gen prd=newv+1
drop newv

save data/fig3_wksp0, replace

*father
use data/wksp11, clear
append using data/wksp12 data/wksp13, generate(newv)

gen prd=newv+1
drop newv

save data/fig3_wksp1, replace


**# Regression using spline variable
* Import aggregated data (number of events and person time by period, parent and covariates)
use "data/data1.dta", clear
append using "data/data2.dta" "data/data3.dta", generate(newv)
gen prd=newv+1
drop newv


foreach i of num 0/1{ 
	
preserve

keep if far==`i'

* Merge with data on spline
merge m:1 wk prd using "data/fig3_wksp`i'.dta"
drop _merge

replace prd=prd-1
*Note now the value of prd is: 0,1,2

*regression
poisson _d i.prd##c.wksp* i.agec i.cal i.edu i.marr i.income i.firstpreg i.fland i.psy i.sui_his i.season, irr exp(fu)

*predict log IRR
predictnl rr= _b[1.prd]+_b[1.prd#wksp1]*wksp1+_b[1.prd#wksp2]*wksp2+_b[1.prd#wksp3]*wksp3 if prd==1, ci(lb ub)
predictnl rr1= _b[2.prd]+_b[2.prd#wksp1]*wksp1+_b[2.prd#wksp2]*wksp2+_b[2.prd#wksp3]*wksp3 if prd==2, ci(lb1 ub1)

replace rr=rr1 if prd==2
replace lb=lb1 if prd==2
replace ub=ub1 if prd==2

* save estimates
keep if prd == 1 | prd == 2
keep prd wk rr lb ub
gen far=`i'
save output/figure3_`i', replace
restore
}

**# Regression not using spline variable
use "data/data1.dta", clear
append using "data/data2.dta" "data/data3.dta", generate(newv)
gen prd=newv+1
drop newv

frame change default
capture frame drop result1
frame create result1 far prd wk rr0 lb0 ub0


foreach i of num 0/1{ 
	
preserve

keep if far==`i'

*regression
poisson _d i.prd##i.wk i.agec i.cal i.edu i.marr i.income i.firstpreg i.fland i.psy i.sui_his i.season, irr exp(fu)

*extract estimate
foreach j of num 2/3{
foreach t of num 1/53 {
	lincom `j'.prd+`j'.prd#`t'.wk, irr
	
	local b1= r(estimate)
    local lb= r(lb)
    local ub= r(ub)
	
    frame post result1  (`i') (`j') (`t') (`b1') (`lb') (`ub') 
}
} 

restore
}

*load result and merge 
frame result1:list 
frame change result1
replace prd=prd-1
save output/figure3_nosp,replace


**
** visulize
**

* load estimates
clear
append using output/figure3_0 output/figure3_1

*collapse
collapse (first) rr* lb* ub*, by(wk prd far)

* exp 
replace rr = exp(rr)
replace lb = exp(lb)
replace ub = exp(ub)

*merge with data on original IRR
merge 1:1 far prd wk using output/figure3_nosp

* exclusion
drop if prd==1 & wk>40 

* label
label define px 1 "Antepartum" 2 "Postpartum"
label values prd px


* plot 
twoway ///
    (rcap lb0 ub0 wk if far==0, sort color("255 153 153") lw(thin) fi(inten20))  ///
	(rcap lb0 ub0 wk if far==1, sort color("173 216 230") lw(thin) fi(inten20)) ///
	(rarea lb ub wk if far==0, sort color(red) lw(none) fi(inten60))  ///
	(rarea lb ub wk if far==1, sort color(ltblue) lw(none) fi(inten60)) ///
  	(scatter rr0 wk if far==0, msymbol(o) msize(tiny) mcolor(pink) lcolor(red) sort) ///
	(line rr wk if far==0, msymbol(o) msize(tiny) mcolor(red) connect(direct) lpattern(dash) lcolor(red) sort) ///
	(scatter rr0 wk if far==1, msymbol(o) msize(tiny) mcolor(midblue) lcolor(navy) sort) ///
	(line rr wk if far==1, msymbol(o) msize(tiny) mcolor(midblue) connect(direct) lpattern(dash) lcolor(navy) sort), ///
by(prd, rows(1) ixaxes iyaxes graphregion(color(white)) note("") legend(position(6))) ///
legend(order(6 8) lab(6 "Mothers") lab (8 "Fathers") rows(1) region(lcolor(white)) size(vsmall)) graphregion(color(white)) scale(.8) ///
xlabel(0(5)53) ///
ylabel(0 0.1 0.2 0.5 1 2 5) ///
yscale(log range(0.1 5)) ///
yline(1, lp(solid) lc(black) lw(medium)) ///
ytitle("Incidence rate ratio") ///
xtitle("Week") ///
saving(output/figure3,replace) 


* output
graph use output/figure3
graph export output/figure3.jpg, replace

log close

