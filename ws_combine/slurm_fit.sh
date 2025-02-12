#!/bin/bash
#SBATCH -p wn
#SBATCH --account=t3
#SBATCH --job-name=SLTest
#SBATCH --output=slurm_output_%a.log  # Log file for each array job
#SBATCH --output=slurm_output_%a.out
#SBATCH --error=slurm_output_%a.err
#SBATCH --array=0-9  # Modify range as needed
#SBATCH --time=00:30:00  # Set appropriate time limit
#SBATCH --partition=short  # Use standard partition
#SBATCH --mem=2G  # Adjust memory as needed

echo HOME: $HOME 
echo USER: $USER 
echo SLURM_JOB_ID: $SLURM_JOB_ID
echo HOSTNAME: $HOSTNAME

# Get array index from Slurm environment variable
i=$SLURM_ARRAY_TASK_ID
export TARGET_PATH=/scratch/$USER/${SLURM_JOB_ID}
mkdir -p $TARGET_PATH/output/inputs
mkdir -p $TARGET_PATH/output/ws_combine
mkdir -p $TARGET_PATH/output/ws

# Set environment
ulimit -s unlimited
set -e
cd /t3home/niharrin/devel/CMSSW_14_1_0_pre4/src
export SCRAM_ARCH=el9_amd64_gcc12
source /cvmfs/cms.cern.ch/cmsset_default.sh
eval "$(scramv1 runtime -sh)"

# Copy files to scratch
xrdcp -fr /t3home/niharrin/devel/CMSSW_14_1_0_pre4/src/SLTest/inputs/htt_tt.input_${i}.root $TARGET_PATH/output/inputs
xrdcp -fr /t3home/niharrin/devel/CMSSW_14_1_0_pre4/src/SLTest/inputs/htt_tt_125_8TeV.txt $TARGET_PATH/output/inputs
xrdcp -fr /t3home/niharrin/devel/CMSSW_14_1_0_pre4/src/SLTest/inputs/htt_tt.input.root $TARGET_PATH/output/inputs

# Move to working directory
cd $TARGET_PATH/output/ws_combine

# Create directory and move into it
mkdir -p fit_${i}
cd fit_${i}

echo "Running iteration $i"
new_input_file="$TARGET_PATH/output/inputs/htt_tt_125_8TeV_${i}.txt"
sed "s/htt_tt\.input\.root/htt_tt.input_${i}.root/g" $TARGET_PATH/output/inputs/htt_tt_125_8TeV.txt > "$new_input_file"

# Run analysis
text2workspace.py "$new_input_file" -P HiggsAnalysis.CombinedLimit.PhysicsModel:multiSignalModel \
  --PO verbose --PO 'map=htt_tt_0_8TeV/ggH:r_high[1,-10,10]' \
  --PO 'map=htt_tt_1_8TeV/ggH:r_low[1,-10,10]' \
  --PO 'map=htt_tt_2_8TeV/ggH:r_low[1,-10,10]' \
  -o $TARGET_PATH/output/ws/ws_mu_ggH_${i}.root -m 125

combine -M MultiDimFit --algo grid -n .high.${i} -d $TARGET_PATH/output/ws/ws_mu_ggH_${i}.root -P r_high
combine -M MultiDimFit --algo grid -n .low.${i} -d $TARGET_PATH/output/ws/ws_mu_ggH_${i}.root -P r_low

plot1DScan.py higgsCombine.high.${i}.MultiDimFit.mH120.root --POI r_high -o scan_ggH_high_${i}
plot1DScan.py higgsCombine.low.${i}.MultiDimFit.mH120.root --POI r_low -o scan_ggH_low_${i}

rm -rf $TARGET_PATH/output/input
xrdcp -fr $TARGET_PATH/output root://t3dcachedb.psi.ch:1094///pnfs/psi.ch/cms/trivcat/store/user/niharrin/ntuples/midRun3/simplified_likelihood/SLTest
rm -rf $TARGET_PATH
