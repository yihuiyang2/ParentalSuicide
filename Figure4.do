**
** Figure 4 irr and ird by week, compare mother to father
**

** Created by Yihui Yang, 2024-03-28

sysdir set PLUS "W:\C6_Fang\IT\STATA\plus\"
cd "W:\C6_Fang\WMH\Projects\Yihui\Sexdiff_suicide"

log using output/Figure4.log, text replace


**# Generate spline 
* please see codes in Figure3 for how splines are generated
* append spline data for each period

*preconception
use data/wksp01, clear
append using data/wksp11, generate(newv)
gen mot=1-newv
drop newv
save data/fig4_wksp1, replace

*antepartum 
use data/wksp02, clear
append using data/wksp12, generate(newv)
gen mot=1-newv
drop newv
save data/fig4_wksp2, replace

*postpartum
use data/wksp03, clear
append using data/wksp13, generate(newv)
gen mot=1-newv
drop newv
save data/fig4_wksp3, replace


**# Regression using spline variable, estimating IRR
* Import aggregated data (number of events and person time by period, parent and covariates)

foreach i of num 1/3{ 
	
* Import data
use "data/data`i'.dta", clear

*In the original dataset, the variable far has 1=father, 0=mother
*now create variable mot: 1=mother, 0=father
gen far2=0 if far==1
replace far2=1 if far==0
drop far
rename far2 mot

* Merge with data on spline
merge m:1 wk mot using "data/fig4_wksp`i'.dta"
drop _merge

*regression
poisson _d i.mot##c.wksp* i.agec i.cal i.edu i.marr i.income i.firstpreg i.fland i.psy i.sui_his i.season, irr exp(fu)

*predict log IRR 
predictnl rr= _b[1.mot]+_b[1.mot#c.wksp1]*wksp1+_b[1.mot#c.wksp2]*wksp2+_b[1.mot#c.wksp3]*wksp3 if mot==1, ci(lb ub)

* save estimates
keep if mot == 1
keep mot wk rr lb ub p
gen prd=`i'
save "output/figure4irr_`i'", replace
}

**# Regression not using spline variable, estimating IRR
clear

frame change default
capture frame drop result1
frame create result1 prd wk rr0 lb0 ub0

foreach i of num 1/3{ 
	
* Import data
use "data/data`i'.dta", clear

*In the original dataset, the variable far has 1=father, 0=mother
*now create variable mot: 1=mother, 0=father
gen far2=0 if far==1
replace far2=1 if far==0
drop far
rename far2 mot


*regression
poisson _d i.mot##i.wk i.agec i.cal i.edu i.marr i.income i.firstpreg i.fland i.psy i.sui_his i.season, irr exp(fu)

levelsof wk, local(lvl) 

foreach t of local lvl {
	lincom 1.mot+1.mot#`t'.wk, irr
	
	local b1= r(estimate)
    local lb= r(lb)
    local ub= r(ub)
	
    frame post result1  (`i') (`t') (`b1') (`lb') (`ub') 
}

}

* save estimates
frame result1:list 
frame change result1
save output/figure4_irr_nosp,replace


**# visulize IRR

*load results on using splines
clear
append using output/figure4irr_1 output/figure4irr_2 output/figure4irr_3
drop mot

*collapse
collapse (first) rr lb ub, by(wk prd)

* exp 
replace rr = exp(rr)
replace lb = exp(lb)
replace ub = exp(ub)

*merge with data on IRR without splines
merge 1:1 prd wk using output/figure4_irr_nosp


* label
label define px 1 "Preconception" 2 "Antepartum" 3 "Postpartum"
label values prd px

* exclusion
drop if prd==2 & wk>40 


* plot 
twoway ///
	(rcap lb0 ub0 wk, sort color("255 153 153") fi(inten20) lw(thin)) ///
	(rarea lb ub wk, sort color(red) fi(inten50) lw(none)) ///
	(scatter rr0 wk, msymbol(o) msize(tiny) mcolor(pink) fi(inten10) lcolor(red) sort) ///
	(line rr wk, msymbol(o) msize(tiny) mcolor(red) connect(direct) lpattern(dash) lcolor(red) sort), ///
by(prd, rows(1) legend(off) ixaxes iyaxes graphregion(color(white)) note("")) ///
yline(1, lp(-) lc(ltblue) lw(medthick)) ///
ytitle("Incidence rate ratio") ///
xtitle("") ///
xlabel(0(5)53) xsize(20) ysize(7) ///
saving(output/figure4irr,replace) 


**# Regression using spline variable, estimating IRD

** based on https://journals.sagepub.com/doi/pdf/10.1177/1536867X221106437
** Stata tip 146: Using margins after a Poisson regression model to estimate the number of events prevented by an intervention

clear
matrix X = J(1,5,.)


foreach i of num 1/3 {
		
* Import data
use "data/data`i'.dta", clear

gen far2=0 if far==1
replace far2=1 if far==0
drop far
rename far2 mot

* Merge with data on spline
merge m:1 wk mot using "data/fig4_wksp`i'.dta"
drop _merge

* model
poisson _d i.mot##c.wksp* i.agec i.cal i.edu i.marr i.income i.firstpreg i.fland i.psy i.sui_his i.season, irr exp(fu)

* predict risk difference by week
foreach k of num 1/53 {
	preserve
	keep if wk==`k'
	
    count if mot==0 & e(sample)==1
    scalar r=r(N)
	
    if r > 0 {
    margins, at((asobs) _all) at(mot=1) exp(predict(n)*r) subpop(if mot==0) pwcompare level(95)
    mat t = r(table_vs)
    qui: sum(fu) if mot==0
    scalar p=r(sum)/1000

* extract RD
    matrix A = J(1,5,.)
	matrix A[1,1] = `i'
    matrix A[1,2] = `k'
    matrix A[1,3] = t[1,1]/p
    matrix A[1,4] = t[5,1]/p
    matrix A[1,5] = t[6,1]/p  
    
* save estimates
    matrix X = X \ A
  }
   restore
}
}


* output estimates
matrix colnames X = prd wk rd lb ub
clear
svmat X, names(col)
save output/Figure4_ird, replace

**# Regression not using splines, estimating IRD
clear
matrix X = J(1,5,.)

foreach i of num 1/3 {
		
* Import data
use "data/data`i'.dta", clear

gen far2=0 if far==1
replace far2=1 if far==0
drop far
rename far2 mot

*regression
poisson _d i.mot##i.wk i.agec i.cal i.edu i.marr i.income i.firstpreg i.fland i.psy i.sui_his i.season, irr exp(fu)


* predict risk difference by week
levelsof wk, local(lvl) 

foreach k of local lvl {
	preserve
	keep if wk==`k'
	
    count if mot==0 & e(sample)==1
    scalar r=r(N)
	
    if r > 0 {
    margins, at((asobs) _all) at(mot=1) exp(predict(n)*r) subpop(if mot==0) pwcompare level(95)
    mat t = r(table_vs)
    qui: sum(fu) if mot==0
    scalar p=r(sum)/1000

* extract RD
    matrix A = J(1,5,.)
	matrix A[1,1] = `i'
    matrix A[1,2] = `k'
    matrix A[1,3] = t[1,1]/p
    matrix A[1,4] = t[5,1]/p
    matrix A[1,5] = t[6,1]/p  
    
* save estimates
    matrix X = X \ A
  }
   restore
}
}

* output estimates
matrix colnames X = prd wk rd0 lb0 ub0
clear
svmat X, names(col)
save output/Figure4_ird_nosp, replace



**# visualize IRD

*load data on ird not using spline
use output/Figure4_ird_nosp, clear
replace rd=rd*365.25
replace lb=lb*365.25
replace ub=ub*365.25
save output/Figure4_ird_nosp2, replace


* input estimates
use output/Figure4_ird, clear

replace rd=rd*365.25
replace lb=lb*365.25
replace ub=ub*365.25

* merge data
merge 1:1 prd wk using output/figureS21_ird2


* label
label define px 1 "Preconception" 2 "Antepartum" 3 "Postpartum"
label values prd px

* exclusion
drop if prd==2 & wk>40 


* plot 
twoway ///
	(rcap lb0 ub0 wk, sort color("255 153 153") fi(inten20) lw(thin)) ///
	(rarea lb ub wk, sort color(red) lw(none) fi(inten50)) ///
	(scatter rd0 wk, msymbol(o) msize(tiny) mcolor(pink) fi(inten10) lcolor(red) sort) ///
	(line rd wk, msymbol(o) msize(tiny) mcolor(red) connect(direct) lpattern(dash) lcolor(red) sort), ///
by(prd, rows(1) legend(off) ixaxes iyaxes graphregion(color(white)) note("")) ///
yline(0, lp(-) lc(ltblue) lw(medthick)) ///
ytitle("Incidence rate difference" "per 1000 person years") ///
xtitle("Week") ///
yscale(range(-3.1 1.7)) ///
ylabel(-3(1)2) ///
xlabel(0(5)53) xsize(20) ysize(7) ///
saving(output/figure4ird,replace) 


**# Merge figure on irr and ird
grc1leg "output/figure4irr.gph" "output/figure4ird.gph", rows(2) imargin(1 1 1 1) ///
graphregion(color(white)) ///
ring(2) ///
xsize(70) ysize(100) ///
saving("output/figure4",replace)  

* output
graph use output/figure4
graph export output/figure4.jpg, replace

log close

