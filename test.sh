#!/bin/bash

input='hello world'

change_string(){
    # $1 here is the string "hello world" passed into the function below
    
    # We pipe the string into awk, and swap column 2 ($2) with column 1 ($1)
    echo "$1" | awk '{print $2, $1}'
}

# You MUST explicitly pass the variable to the function here:
change_string "$input"
