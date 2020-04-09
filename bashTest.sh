#!/bin/bash

#world="World"
#
#echo "Hello $world"
#------checking exprassion options-------
#echo "this is an example"
#adding_exper="S"
#
#v=$(expr 5 + $adding_expr)
deploy=false uglify=false
while (( $# > 1 ));
do
    case $1 in
        --deploy) deploy="$2"
            ;;
        --uglify) uglify="$2"
            ;;
        *)
            break
            ;;

    esac;
    shift 2
done
$deploy && echo "will deploy... deploy = $deploy"
$uglify && echo "will uglify... uglify = $uglify"
printf $#


































