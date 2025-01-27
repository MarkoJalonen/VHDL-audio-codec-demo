#!/bin/bash
#
# Author Marko Jalonen
# Create a new project folder fod ModelSim
# Create a design library (vlib)
# Map the VHDL library and the compiled VHDL code

read -p "Enter project folder name: " project_name
new_folder="${PWD}/projects/${project_name}"
if [ -d $new_folder ]
    then
        echo "Project folder for ${project_name} already exists!"
        exit 1
fi

echo "Creating a folder and mapping..."
mkdir $new_folder
vlib ${new_folder}/work
vmap work ${new_folder}/work
vmap | grep work | cat

echo "Copying .do file..."
sim_setup="${PWD}/simulation_setup.do"
cp $sim_setup $new_folder
echo "Done"