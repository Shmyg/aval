#!/bin/bash

# Script for creating directory structure for autopayment project
# Created by Shmyg
# LMD by Shmyg 12.12.2003


declare -ar dirs=(log_files data_files control_files)
declare -ar territories=(center crimea dnepr east nord south west)
declare -ar center_dirs=(aval_1 aval_2 aval_3 eurobank integral portmone \
 pravex starokiev)
declare -ar crimea_dirs=(cash_1 cash_2 cash_3)
declare -ar dnepr_dirs=(dnipropetrovsk kirovograd kryvy_rig zaporizhya)
declare -ar east_dirs=(donetsk lugansk)
declare -ar nord_dirs
declare -ar south_dirs=(kherson mykolayiv odessa_1 odessa_3)
declare -ar west_dirs=(lviv_1 lviv_2 uzhgorod)

for i in 0 2; do
 mkdir ${dirs[i]}
 for j in 0 1; do
  mkdir ${dirs[i]}/${territories[j]}
   for k in 0 1; do
    array_name=${territories[j]}_dirs
    echo $array_name
    mkdir ${dirs[i]}/${territories[j]}/${$array_name[k]}
   done
 done
done



