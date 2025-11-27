# Workflow Flow Diagram

## Complete Pipeline Flow (After Fix)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ INPUT: Samplesheet                                                       │
│ sample_id: 2vsm_protein_binder                                           │
│ budget: 2                                                                │
│ num_designs: 5                                                           │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ BOLTZGEN_RUN (1 execution per sample)                                   │
│ • Generates 5 designs                                                    │
│ • Filters to top 2 (budget=2)                                            │
│ • Output: rank_1.cif, rank_2.cif                                         │
└───────────────┬─────────────────────────┬───────────────────────────────┘
                │                         │
                │                         └──────────────────┐
                ▼                                            ▼
┌───────────────────────────────────┐    ┌───────────────────────────────────┐
│ CONVERT_CIF_TO_PDB                │    │ EXTRACT_TARGET_SEQUENCES          │
│ • rank_1.cif → rank_1.pdb         │    │ • Reads rank_1.cif                │
│ • rank_2.cif → rank_2.pdb         │    │ • Extracts target chain sequence  │
└───────────────┬───────────────────┘    │ • Output: target_seq.txt          │
                │                         └───────────────────┬───────────────┘
                │                                             │
                ▼                                             │
┌─────────────────────────────────────────────────────────┐  │
│ ch_pdb_per_design (flatMap - 2 parallel branches)       │  │
│ [meta_rank1, rank_1.pdb]                                 │  │
│ [meta_rank2, rank_2.pdb]                                 │  │
└───────┬──────────────────────────────┬──────────────────┘  │
        │                              │                      │
        ▼                              ▼                      │
┌──────────────────────┐   ┌──────────────────────┐         │
│ PROTEINMPNN_OPTIMIZE │   │ PROTEINMPNN_OPTIMIZE │         │
│ (rank_1.pdb)         │   │ (rank_2.pdb)         │         │
│ • 8 sequences        │   │ • 8 sequences        │         │
│   seq0: original     │   │   seq0: original     │         │
│   seq1-7: new        │   │   seq1-7: new        │         │
└──────────┬───────────┘   └──────────┬───────────┘         │
           │                          │                      │
           └───────────┬──────────────┘                      │
                       ▼                                     │
┌─────────────────────────────────────────────────────────┐ │
│ ch_boltz2_per_sequence (flatMap - 16 parallel branches) │ │
│ One per FASTA file:                                      │ │
│ [meta_rank1_seq0, rank1_seq0.fa]                         │ │
│ [meta_rank1_seq1, rank1_seq1.fa]                         │ │
│ ...                                                       │ │
│ [meta_rank1_seq7, rank1_seq7.fa]                         │ │
│ [meta_rank2_seq0, rank2_seq0.fa]                         │ │
│ [meta_rank2_seq1, rank2_seq1.fa]                         │ │
│ ...                                                       │ │
│ [meta_rank2_seq7, rank2_seq7.fa]                         │ │
└────────────────┬────────────────────────────────────────┘ │
                 │                                           │
                 │ .map { [parent_id, meta, fasta] }        │
                 ▼                                           │
┌─────────────────────────────────────────────────────────┐ │
│ Add parent_id as key:                                    │ │
│ ["2vsm", meta_rank1_seq0, rank1_seq0.fa]                 │ │
│ ["2vsm", meta_rank1_seq1, rank1_seq1.fa]                 │ │
│ ...                                                       │ │
│ ["2vsm", meta_rank2_seq7, rank2_seq7.fa]                 │ │
└────────────────┬────────────────────────────────────────┘ │
                 │                                           │
                 │ .combine(target_sequences, by: 0)        │
                 │                          ◄───────────────┘
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ COMBINE operation (key: parent_id)                          │
│ ALL 16 sequences paired with target_seq.txt:                │
│ ["2vsm", meta_rank1_seq0, rank1_seq0.fa, target_seq.txt]    │
│ ["2vsm", meta_rank1_seq1, rank1_seq1.fa, target_seq.txt]    │
│ ...                                                          │
│ ["2vsm", meta_rank2_seq7, rank2_seq7.fa, target_seq.txt]    │
└────────────────┬────────────────────────────────────────────┘
                 │
                 │ .map { [meta, fasta, target_seq] }
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ Final channel for BOLTZ2_REFOLD (14 parallel executions):   │
│ [meta_rank1_seq1, rank1_seq1.fa, target_seq.txt]  ← Skip 0  │
│ [meta_rank1_seq2, rank1_seq2.fa, target_seq.txt]            │
│ ...                                                          │
│ [meta_rank1_seq7, rank1_seq7.fa, target_seq.txt]            │
│ [meta_rank2_seq1, rank2_seq1.fa, target_seq.txt]  ← Skip 0  │
│ [meta_rank2_seq2, rank2_seq2.fa, target_seq.txt]            │
│ ...                                                          │
│ [meta_rank2_seq7, rank2_seq7.fa, target_seq.txt]            │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ BOLTZ2_REFOLD (14 parallel executions)                      │
│ • Each FASTA has multiple sequences                          │
│ • Skip first sequence (original from Boltzgen)              │
│ • Refold remaining sequences                                 │
│ • Output: CIF structures + PAE NPZ files                     │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ Total Structures for Analysis:                              │
│ • 2 Boltzgen structures (rank_1, rank_2)                     │
│ • 14 Boltz2 refolded structures (7 per budget design)        │
│ = 16 total structures                                        │
└────────────────┬────────────────────────────────────────────┘
                 │
         ┌───────┴───────┬───────────────┐
         ▼               ▼               ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ IPSAE       │  │ PRODIGY     │  │ FOLDSEEK    │
│ 16 scores   │  │ 16 scores   │  │ 16 searches │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │
       └────────────────┼────────────────┘
                        ▼
        ┌───────────────────────────────┐
        │ CONSOLIDATE_METRICS           │
        │ • Combines all scores         │
        │ • 16 rows in final table      │
        │ • CSV + Markdown report       │
        └───────────────────────────────┘
```

## Key Points

### Parallelization Strategy

1. **Boltzgen**: 1 execution per sample
   - Generates multiple designs
   - Filters to top N based on budget

2. **ProteinMPNN**: budget executions (one per design)
   - Example: budget=2 → 2 parallel executions
   - Each generates `mpnn_num_seq_per_target` sequences

3. **Boltz2**: budget × (mpnn_num_seq_per_target - 1) executions
   - Example: budget=2, mpnn_num_seq_per_target=8 → 14 parallel executions
   - Skips first sequence (original) from each FASTA

4. **ipSAE/Prodigy/Foldseek**: budget + [budget × (mpnn_num_seq_per_target - 1)]
   - Example: 2 + 14 = 16 parallel executions
   - Processes ALL structures (Boltzgen + Boltz2)

### Channel Operations

**flatMap**: Splits collections into individual items
```groovy
// Input:  [meta, [file1.fa, file2.fa]]
// Output: [meta, file1.fa], [meta, file2.fa]
```

**join**: One-to-one matching (ONLY first match per key)
```groovy
// Channel A: [key, dataA1], [key, dataA2]
// Channel B: [key, dataB]
// Result:    [key, dataA1, dataB]  ← dataA2 DROPPED!
```

**combine**: All-to-all matching (ALL items with same key)
```groovy
// Channel A: [key, dataA1], [key, dataA2]
// Channel B: [key, dataB]
// Result:    [key, dataA1, dataB], [key, dataA2, dataB]  ← ALL kept!
```

### Why combine() Fixed the Issue

**Problem**: Multiple ProteinMPNN outputs shared the same `parent_id`
- rank_1 sequences: parent_id = "2vsm_protein_binder"
- rank_2 sequences: parent_id = "2vsm_protein_binder"

**Old behavior (join)**: Only matched FIRST ProteinMPNN output
- Result: Only rank_1 sequences were refolded by Boltz2
- rank_2 sequences were DROPPED

**New behavior (combine)**: Matches ALL ProteinMPNN outputs
- Result: ALL sequences from rank_1 AND rank_2 are refolded
- Nothing is dropped

### Sequence Numbering

ProteinMPNN outputs multi-sequence FASTA files:
```
>seq_0  ← ORIGINAL Boltzgen sequence (SKIP for Boltz2)
MKTAYIAKQRQISFVKSHFS...
>seq_1  ← NEW ProteinMPNN sequence (REFOLD with Boltz2)
MKTAYIAKQRQISFVKSHFS...
>seq_2  ← NEW ProteinMPNN sequence (REFOLD with Boltz2)
MKTAYIAKQRQISFVKSHFS...
...
>seq_7
MKTAYIAKQRQISFVKSHFS...
```

Boltz2 logic:
```python
sequences_to_process = sequences[1:]  # Skip seq_0
```

This ensures we don't refold the original Boltzgen sequence (we already have it!)
