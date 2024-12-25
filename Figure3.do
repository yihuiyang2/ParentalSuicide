**
** Figure 3 irr by week, comparing antepartun and postpartum with preconception
**

** Created by Yihui Yang, 2024-03-28



cd "W:\C6_Fang\WMH\Projects\Yihui\Sexdiff_suicide"


log using output/Figure3.log, text replace


* Import data
use "data/data1.dta", clear
append using "data/data2.dta" "data/data3.dta", generate(newv)
gen prd=newv+1
drop newv


foreach i of num 0/1{ 
	
preserve

keep if far==`i'

* Merge with data on spline
merge m:1 wk using "data/fig3_wksp`i'.dta"
drop _merge

replace prd=prd-1
*Note now the value of prd is: 0,1,2

*regression
poisson _d i.prd##c.wksp* i.agec i.cal i.edu i.marr i.income i.firstpreg i.fland i.psy i.sui_his, irr exp(fu)

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


**
** visulize
**
* load estimates
clear
append using output/figure3_0 output/figure3_1

*collapse
collapse (first) rr* lb* ub*, by(wk prd far)

* exclusion
drop if prd==1 & wk>40 

* exp 
replace rr = exp(rr)
replace lb = exp(lb)
replace ub = exp(ub)

* label
label define px 1 "Antepartum" 2 "Postpartum"
label values prd px


* plot 
twoway ///
    (rarea lb ub wk if far==0, sort color(pink) lw(none) fi(inten30))  ///
	(scatter rr wk if far==0, msymbol(o) msize(tiny) mcolor(red) connect(direct) lcolor(red) sort) ///
    (rarea lb ub wk if far==1, sort color(ltblue) lw(none) fi(inten30)) ///
	(scatter rr wk if far==1, msymbol(o) msize(tiny) mcolor(midblue) connect(direct) lcolor(navy) sort), ///
by(prd, rows(1) ixaxes iyaxes graphregion(color(white)) note("") legend(position(6))) ///
legend(order(2 4) lab(2 "Mothers") lab (4 "Fathers") rows(1) region(lcolor(white)) size(vsmall)) graphregion(color(white)) scale(.8) ///
xlabel(0(5)53) ///
yline(1, lp(solid) lc(black) lw(medium)) ///
ytitle("Incidence rate ratio") ///
xtitle("Week") ///
saving(output/figure3,replace) 


* output
graph use output/figure3
graph export output/figure3.jpg, replace

log close
