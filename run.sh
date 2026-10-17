#!/usr/bin/bash

set -e

# Basic folders
PDB="structures/1AKI_clean.pdb"
INPUT="inputs"
GROMACS="pathtogromacs"

# For gamd
NTMPI=1
NTOMP=8
PIN=on

# System Preparation

echo "Starting System Prep"

$GROMACS pdb2gmx -f $PDB -o 1AKI_processed.gro -water tip3p -ignh
$GROMACS editconf -f 1AKI_processed.gro -o 1AKI_newbox.gro -c -d 1.2 -bt cubic
$GROMACS solvate -cp 1AKI_newbox.gro -cs spc216.gro -o 1AKI_solv.gro -p topol.top

$GROMACS grompp -f $INPUT/ions.mdp -c 1AKI_solv.gro -p topol.top -o ions.tpr
$GROMACS genion -s ions.tpr -o 1AKI_solv_ions.gro -p topol.top -pname NA -nname CL -neutral

# Minimization
$GROMACS grompp -f $INPUT/minim.mdp -c 1AKI_solv_ions.gro -p topol.top -o em.tpr
$GROMACS mdrun -v -deffnm em

# NVT
$GROMACS grompp -f $INPUT/nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr
$GROMACS mdrun -v -deffnm nvt

# NPT
$GROMACS grompp -f $INPUT/npt.mdp -c nvt.gro -r nvt.gro -p topol.top -o npt.tpr
$GROMACS mdrun -v -deffnm npt

# Normal Production MD
mkdir cMD
cd cMD
$GROMACS grompp -f ../inputs/cMD_50ns.mdp -c ../npt.gro -t ../npt.cpt -p ../topol.top -o md_50ns.tpr
date; $GROMACS mdrun -v -deffnm md_50ns; date

cd ..
mkdir -p gamd_1
cp inputs/gamd.in gamd_1/gamd.in
cd gamd_1

# GaMD equilibration
$GROMACS grompp \
  -f ../inputs/gamd_equil.mdp \
  -c ../npt.gro \
  -t ../npt.cpt \
  -p ../topol.top \
  -o gamd.tpr

date; $GROMACS mdrun -v \
  -s gamd.tpr \
  -deffnm gamd \
  -ntmpi $NTMPI \
  -ntomp $NTOMP \
  -pin $PIN \
  -nb gpu \
  -pme gpu \
  -bonded gpu \
  -update gpu; date

# GaMD Production

# Create clean production directory
mkdir -p ../gamd_prod
cp gamd-restart.dat gamd-restart-prev.dat ../gamd_prod/
cp ../inputs/gamd_prod.in ../gamd_prod/gamd.in

cd ../gamd_prod

$GROMACS grompp \
  -f ../inputs/gamd_50ns.mdp \
  -c ../gamd_1/gamd.gro \
  -t ../gamd_1/gamd.cpt \
  -p ../topol.top \
  -o gamd_prod.tpr

date; $GROMACS mdrun -v \
  -s gamd_prod.tpr \
  -deffnm gamd_prod \
  -ntmpi $NTMPI \
  -ntomp $NTOMP \
  -pin $PIN \
  -nb gpu \
  -pme gpu \
  -bonded gpu \
  -update gpu; date

echo "ALL DONE"
