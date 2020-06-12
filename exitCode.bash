#!/bin/bash

a=4
b=5
c=6
#|| $b -eq 6 && $c -eq 6 ]
#if [ $a -eq 5 ] || 
#    [ $b -eq 5 ] && 
#    [ $c -eq 6 ]
#    then
#    echo a is 4 or b is 5 and c is 6
#else
#    echo error
#fi

# if [ $a -eq 4 ]
#     then
#     echo found
# else
#     echo not found
# fi
test() {
	if [ $a -eq 4 ]
	then
		true
	else
		false
	fi
}

if test
then
	echo a is fine
else
	echo a in not fine
fi

echo $test
