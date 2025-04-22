**
** TABLE 1 BASELINE CHAR
**

*Created by Yihui Yang, 2024-03-28

cd "W:\C6_Fang\WMH\Projects\Yihui\Sexdiff_suicide"

log using output/Table1.log, text replace

* Import data
use "data/data1.dta", clear
append using "data/data2.dta" "data/data3.dta", generate(newv)
gen prd=newv+1
drop newv


* sum up events and person-time
collapse (sum) _d fu, by(prd far agec cal edu fland marr income firstpreg psy sui_his season)

gen py=round(fu/365.25)
drop fu


* calculate total PY by sex
qui: sum py if far==0
scalar m = r(sum)

qui: sum py if far==1
scalar f = r(sum)

matrix X = J(1,6,.)

matrix X[1,1] = 0
matrix X[1,2] = 0
matrix X[1,3] = m
matrix X[1,5] = f



* calculate N, PY and IR by categorical covars
foreach i of num 1/10 {
local j: word `i' of "agec" "cal" "edu" "fland" "marr" "income" "firstpreg" "psy" "sui_his" "season"

* loop levels
levelsof `j', local(lvl) 

foreach k of local lvl {

  matrix A = J(1,6,.)
  
  matrix A[1,1] = `i'
  matrix A[1,2] = `k'
  
* mothers
  qui: sum py if far==0  &  `j' == `k'
  matrix A[1,3] = r(sum)
  
* fathers
  qui: sum py if far==1  & `j' == `k'
  matrix A[1,5] = r(sum)
	
* output
matrix X = X\A
}
}


matrix colnames X = var lvl py0 pct0 py1 pct1

clear
svmat X, names(col)
save output/table1, replace

*import data
use output/table1,clear

*calculate percentage
replace pct0=py0/m*100
replace pct1=py1/f*100

*format 
gen pym=string(py0,"%10.2gc")
gen pctm=string(pct0,"%9.2f")

gen pyf=string(py1,"%10.2gc")
gen pctf=string(pct1,"%9.2f")



* label
label define varlab 0 "Total" 1 "agec" 2 "cal" 3 "edu" 4 "fland" 5 "marr" 6 "income" 7 "firstpreg" 8 "psy" 9 "sui_his" 10 "season"
label values var varlab

keep var lvl pym pctm pyf pctf


* output
save output/table1, replace
export excel output/table1.xlsx, firstrow(var) replace

log close
