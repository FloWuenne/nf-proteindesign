#!/bin/bash

echo "========================================"
echo "Boltz-2 Migration Verification Script"
echo "========================================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

# Function to check a condition
check() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
        ((PASS++))
    else
        echo -e "${RED}✗${NC} $2"
        ((FAIL++))
    fi
}

echo "Checking removed files..."
echo "-------------------------"
[ ! -f "modules/local/protenix_refold.nf" ]
check $? "Protenix module removed"

[ ! -f "modules/local/convert_protenix_to_npz.nf" ]
check $? "NPZ conversion module removed"

[ ! -f "assets/convert_protenix_to_npz.py" ]
check $? "NPZ conversion script removed"

echo ""
echo "Checking new files..."
echo "--------------------"
[ -f "modules/local/boltz2_refold.nf" ]
check $? "Boltz-2 module created"

echo ""
echo "Checking configuration updates..."
echo "---------------------------------"
grep -q "run_boltz2_refold" nextflow.config
check $? "run_boltz2_refold parameter added"

grep -q "boltz2_num_diffusion" nextflow.config
check $? "boltz2_num_diffusion parameter added"

grep -q "boltz2_num_recycling" nextflow.config
check $? "boltz2_num_recycling parameter added"

grep -q "boltz2_use_msa" nextflow.config
check $? "boltz2_use_msa parameter added"

grep -q "boltz2_predict_affinity" nextflow.config
check $? "boltz2_predict_affinity parameter added"

! grep -q "run_protenix_refold" nextflow.config
check $? "Protenix parameters removed from config"

echo ""
echo "Checking schema updates..."
echo "-------------------------"
grep -q "boltz2_options" nextflow_schema.json
check $? "Boltz-2 options section added to schema"

! grep -q "protenix_options" nextflow_schema.json
check $? "Protenix options removed from schema"

grep -q "Boltz-2 structures" nextflow_schema.json
check $? "Foldseek description updated to Boltz-2"

echo ""
echo "Checking workflow updates..."
echo "---------------------------"
grep -q "BOLTZ2_REFOLD" workflows/protein_design.nf
check $? "BOLTZ2_REFOLD process imported"

! grep -q "PROTENIX_REFOLD" workflows/protein_design.nf
check $? "PROTENIX_REFOLD removed from workflow"

! grep -q "CONVERT_PROTENIX_TO_NPZ" workflows/protein_design.nf
check $? "CONVERT_PROTENIX_TO_NPZ removed from workflow"

grep -q "boltz2_structures" workflows/protein_design.nf
check $? "Boltz-2 output channels defined"

grep -q "boltz2_pae_npz" workflows/protein_design.nf
check $? "Boltz-2 PAE NPZ channel defined"

grep -q "boltz2_affinity" workflows/protein_design.nf
check $? "Boltz-2 affinity channel defined"

echo ""
echo "Checking Boltz-2 module structure..."
echo "------------------------------------"
grep -q "process BOLTZ2_REFOLD" modules/local/boltz2_refold.nf
check $? "BOLTZ2_REFOLD process defined"

grep -q "conda.*boltz" modules/local/boltz2_refold.nf
check $? "Conda directive with Boltz package"

grep -q "accelerator.*nvidia-gpu" modules/local/boltz2_refold.nf
check $? "GPU accelerator configured"

grep -q "emit: pae_npz" modules/local/boltz2_refold.nf
check $? "PAE NPZ output channel defined"

grep -q "emit: affinity" modules/local/boltz2_refold.nf
check $? "Affinity output channel defined"

echo ""
echo "========================================"
echo "Verification Results"
echo "========================================"
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Migration complete.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Review the output above.${NC}"
    exit 1
fi
