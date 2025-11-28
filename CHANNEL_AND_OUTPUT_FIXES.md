# Channel Grouping and Output Restructuring Fixes

## Summary of Changes

This document describes the fixes applied to ensure:
1. **All budget designs from Boltzgen get processed by ipSAE and Prodigy**
2. **Restructured output directories** for clearer organization

## Problems Identified

### 1. Channel Grouping Issue
**Problem**: Not all budget designs from Boltzgen were being processed by ipSAE and Prodigy.

**Root Cause**: The `budget_design_cifs` output in `boltzgen_run.nf` was using the wrong glob pattern:
- Old: `${meta.id}_output/final_ranked_designs/final_*_designs/*.cif`
- This pattern tried to match nested subdirectories with wildcards, which doesn't reliably capture all files

**Solution**: Changed to use the correct directory where Boltzgen places ALL budget designs:
- New: `${meta.id}_output/intermediate_designs_inverse_folded/*.cif`
- This directory contains exactly the budget designs (e.g., if budget=2, there are 2 CIF files)
- Similarly updated NPZ files: `${meta.id}_output/intermediate_designs_inverse_folded/*.npz`

### 2. Output Structure Issue
**Problem**: Output directories were inconsistent and unclear:
- Boltzgen outputs went to: `{sample_id}/`
- ipSAE outputs went to: `{sample_id}/ipsae_scores/`
- Prodigy outputs went to: `{parent_id}/prodigy/`
- Boltz2 outputs went to: `{parent_id}/boltz2/`

This made it hard to see which results belonged to which design row.

**Solution**: Restructured all outputs to use a consistent parent folder structure:
```
outdir/
└── {sample_id}/              # Parent folder for each design row from samplesheet
    ├── boltzgen/             # Boltzgen results
    ├── ipsae/                # ipSAE scores
    ├── prodigy/              # Prodigy results
    ├── proteinmpnn/          # ProteinMPNN results (if enabled)
    ├── boltz2/               # Boltz2 results (if enabled)
    └── foldseek/             # Foldseek results (if enabled)
```

## Files Modified

### 1. `modules/local/boltzgen_run.nf`
**Changes**:
- Fixed `budget_design_cifs` output glob pattern to use `intermediate_designs_inverse_folded/*.cif`
- Fixed `budget_design_npz` output glob pattern to use `intermediate_designs_inverse_folded/*.npz`
- Changed publishDir from `${params.outdir}/${meta.id}` to `${params.outdir}/${meta.id}/boltzgen`

**Impact**: 
- Ensures ALL budget designs are captured and passed to downstream processes
- Organizes Boltzgen outputs into a dedicated subfolder

### 2. `modules/local/ipsae_calculate.nf`
**Changes**:
- Changed publishDir from `${params.outdir}/${meta.id}/ipsae_scores` to `${params.outdir}/${meta.parent_id ?: meta.id}/ipsae`
- Added comment explaining parent_id usage

**Impact**:
- ipSAE results now go into the parent design folder
- Consistent naming with other tools (ipsae instead of ipsae_scores)

### 3. `modules/local/prodigy_predict.nf`
**Changes**:
- Already using `${params.outdir}/${meta.parent_id ?: meta.id}/prodigy` ✓
- No changes needed

### 4. `modules/local/proteinmpnn_optimize.nf`
**Changes**:
- Changed publishDir from `${params.outdir}/${meta.id}/proteinmpnn` to `${params.outdir}/${meta.parent_id ?: meta.id}/proteinmpnn`
- Added comment explaining parent_id usage

**Impact**:
- ProteinMPNN results now go into the parent design folder

### 5. `modules/local/boltz2_refold.nf`
**Changes**:
- Updated comment for clarity
- Already using `${params.outdir}/${meta.parent_id ?: meta.id}/boltz2` ✓
- Added fallback to meta.id if parent_id is not set

### 6. `modules/local/foldseek_search.nf`
**Changes**:
- Already using `${params.outdir}/${meta.parent_id ?: meta.id}/foldseek` ✓
- No changes needed

### 7. `modules/local/consolidate_metrics.nf`
**Changes**:
- Updated `ipsae_pattern` from `**/ipsae_scores/*` to `**/ipsae/*`
- This ensures the consolidation script finds ipSAE results in the new location

## How the Parallelization Works

### Budget Designs Flow
1. **Boltzgen** generates N designs based on `budget` parameter (e.g., budget=2 → 2 designs)
2. **Output channel** `budget_design_cifs` emits: `[meta, [design_1.cif, design_2.cif]]`
3. **flatMap** in workflow creates individual tasks:
   - Task 1: `[meta1, design_1.cif]` → ipSAE
   - Task 2: `[meta2, design_1.cif]` → Prodigy
   - Task 3: `[meta1, design_2.cif]` → ipSAE
   - Task 4: `[meta2, design_2.cif]` → Prodigy

### ProteinMPNN + Boltz2 Flow
1. **ProteinMPNN** generates M sequences per budget design (e.g., 8 sequences × 2 designs = 16 sequences)
2. **Split sequences** creates individual FASTA files (16 files)
3. **Boltz2** refolds each sequence (16 parallel tasks)
4. **ipSAE and Prodigy** run on each Boltz2 output (32 parallel tasks)

## Testing Recommendations

To verify these changes work correctly:

1. **Test with budget=2**:
   ```bash
   nextflow run main.nf --input samplesheet.csv --budget 2 --run_ipsae --run_prodigy
   ```
   
   **Expected results**:
   - 2 ipSAE tasks per design (2 × N designs)
   - 2 Prodigy tasks per design (2 × N designs)

2. **Check output structure**:
   ```bash
   tree results/
   ```
   
   **Expected structure**:
   ```
   results/
   ├── sample1/
   │   ├── boltzgen/
   │   │   └── sample1_output/
   │   ├── ipsae/
   │   │   ├── sample1_design1_10_10.txt
   │   │   └── sample1_design2_10_10.txt
   │   └── prodigy/
   │       ├── sample1_design1_prodigy_summary.csv
   │       └── sample1_design2_prodigy_summary.csv
   └── sample2/
       └── ...
   ```

3. **Verify ipSAE/Prodigy counts**:
   - Count files in each sample's ipsae folder: should equal budget value
   - Count files in each sample's prodigy folder: should equal budget value
   - If ProteinMPNN+Boltz2 enabled: should also have results for each refolded sequence

## Benefits

### 1. Complete Analysis Coverage
- Every budget design now gets scored by ipSAE and Prodigy
- No designs are skipped or missed
- Parallel processing ensures fast execution

### 2. Clear Organization
- Each sample from the samplesheet has its own parent folder
- Easy to see all results for a specific design
- Tool-specific subfolders make it clear which analysis generated which files

### 3. Scalability
- Works with any budget value (1, 2, 10, etc.)
- Handles variable numbers of ProteinMPNN sequences
- Properly parallelizes across all designs and sequences

## Migration Notes

If you have existing results with the old structure, you can reorganize them:

```bash
# Example script to reorganize old results
cd results/
for sample in */; do
    sample_name=${sample%/}
    
    # Move Boltzgen outputs
    if [ -d "$sample_name/${sample_name}_output" ]; then
        mkdir -p "$sample_name/boltzgen"
        mv "$sample_name/${sample_name}_output" "$sample_name/boltzgen/"
    fi
    
    # Rename ipsae_scores to ipsae
    if [ -d "$sample_name/ipsae_scores" ]; then
        mv "$sample_name/ipsae_scores" "$sample_name/ipsae"
    fi
done
```

## Additional Notes

- The `meta.parent_id` field tracks the original sample_id from the samplesheet
- Modules use `${meta.parent_id ?: meta.id}` as a fallback for compatibility
- The consolidation module was updated to find files in the new ipsae path
- No changes were needed to the actual workflow logic in `workflows/protein_design.nf`

---

**Date**: 2025-11-28
**Author**: Seqera AI
**Status**: Implemented and Ready for Testing
