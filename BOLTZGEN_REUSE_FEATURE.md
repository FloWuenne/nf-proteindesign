# Boltzgen Output Reuse Feature

## Overview

The `boltzgen_output_dir` feature allows you to skip the computationally expensive Boltzgen step and start the pipeline directly from ProteinMPNN using pre-computed Boltzgen results. This is particularly useful when:

1. **Nextflow cache is invalidated** - Even though only parameters changed, Nextflow sometimes invalidates the Boltzgen cache
2. **Testing downstream analyses** - You want to experiment with ProteinMPNN, Boltz-2, or other analysis parameters without re-running Boltzgen
3. **Iterative refinement** - You're satisfied with Boltzgen designs and want to focus on sequence optimization and refolding

## How It Works

When you provide a `boltzgen_output_dir` in your samplesheet, the pipeline will:
- **Skip running Boltzgen** for that sample
- **Use the existing Boltzgen output directory** as if it was just computed
- **Continue with ProteinMPNN and downstream analyses** using the pre-computed structures

## Samplesheet Configuration

### Without Boltzgen Reuse (Normal Mode)

```csv
sample_id,design_yaml,structure_files,protocol,num_designs,budget,reuse,target_msa,target_sequence,target_template,boltzgen_output_dir
my_design,designs/2vsm.yaml,structures/2VSM.cif,protein-anything,5,2,false,,targets/target.fasta,,
```

### With Boltzgen Reuse (Skip Boltzgen)

```csv
sample_id,design_yaml,structure_files,protocol,num_designs,budget,reuse,target_msa,target_sequence,target_template,boltzgen_output_dir
my_design,designs/2vsm.yaml,structures/2VSM.cif,protein-anything,5,2,false,,targets/target.fasta,,results/my_design/boltzgen/my_design_output
```

**Key points:**
- The `boltzgen_output_dir` should point to the Boltzgen output directory (typically `{sample_id}_output`)
- The path can be **relative** (from launch directory or project directory) or **absolute**
- Even when reusing, you must still provide `design_yaml` and `structure_files` (for consistency, though they won't be used)
- The directory must contain the standard Boltzgen output structure

## Expected Boltzgen Output Directory Structure

The `boltzgen_output_dir` should have this structure:

```
my_design_output/
├── final_ranked_designs/
│   ├── final_1_designs/
│   │   ├── rank1_*.cif
│   │   └── rank2_*.cif
│   └── final_2_designs/
│       ├── rank1_*.cif
│       └── rank2_*.cif
├── intermediate_designs/
│   ├── design_*.cif
│   └── design_*.npz
├── intermediate_designs_inverse_folded/
│   └── *.npz
├── aggregate_metrics_analyze.csv
└── per_target_metrics_analyze.csv
```

The pipeline specifically requires:
- `final_ranked_designs/final_*_designs/*.cif` - Budget design CIF files for ProteinMPNN

## Example Use Case

### Step 1: Initial Run with Boltzgen

**samplesheet.csv:**
```csv
sample_id,design_yaml,structure_files,protocol,num_designs,budget,reuse,target_msa,target_sequence,target_template,boltzgen_output_dir
2vsm_design,designs/2vsm.yaml,structures/2VSM.cif,protein-anything,5,2,false,,targets/target.fasta,,
```

**Run pipeline:**
```bash
nextflow run main.nf \
  -profile docker \
  --input samplesheet.csv \
  --outdir results \
  --run_proteinmpnn \
  --run_boltz2_refold
```

This generates results in: `results/2vsm_design/boltzgen/2vsm_design_output/`

### Step 2: Re-run with Different ProteinMPNN Parameters

Now you want to test different ProteinMPNN parameters but don't want to re-run Boltzgen:

**samplesheet_reuse.csv:**
```csv
sample_id,design_yaml,structure_files,protocol,num_designs,budget,reuse,target_msa,target_sequence,target_template,boltzgen_output_dir
2vsm_design,designs/2vsm.yaml,structures/2VSM.cif,protein-anything,5,2,false,,targets/target.fasta,,results/2vsm_design/boltzgen/2vsm_design_output
```

**Run pipeline with new parameters:**
```bash
nextflow run main.nf \
  -profile docker \
  --input samplesheet_reuse.csv \
  --outdir results_retest \
  --run_proteinmpnn \
  --run_boltz2_refold \
  --mpnn_num_seqs 16  # Try more sequences
```

### Step 3: Compare Results

You can now compare the outputs from different downstream analyses while using the same Boltzgen designs.

## Benefits

1. **💰 Cost Savings** - Boltzgen is GPU-intensive; skipping it saves compute costs
2. **⏱️ Time Savings** - Typical Boltzgen run: 30-60 minutes; this feature: instant start
3. **🔬 Experimentation** - Test multiple downstream parameter combinations efficiently
4. **🛡️ Cache Safety** - Preserve expensive results even when Nextflow cache is invalidated
5. **📊 Reproducibility** - Use exact same Boltzgen designs across multiple analysis runs

## Important Notes

- The `boltzgen_output_dir` field is **optional** - leave it blank for normal Boltzgen execution
- When provided, Boltzgen will be completely skipped for that sample
- You can mix samples with and without `boltzgen_output_dir` in the same samplesheet
- The directory structure must match what Boltzgen produces
- ProteinMPNN and downstream analyses will work identically whether Boltzgen was just run or reused

## Troubleshooting

### Error: "Cannot find directory"
- Check that the path to `boltzgen_output_dir` is correct
- Use absolute path if relative path isn't working
- Verify the directory exists and has proper permissions

### Error: "No CIF files found"
- Ensure the directory structure matches expected Boltzgen output
- Check that `final_ranked_designs/final_*_designs/*.cif` files exist

### Unexpected behavior
- Verify that the pre-computed Boltzgen results match the expected design
- Check that the `sample_id` matches between runs (for consistent output naming)

## Future Enhancements

Potential future improvements:
- Automatic detection of Boltzgen output directories
- Validation of directory structure before starting
- Support for partial reuse (e.g., reuse intermediate but not final designs)
