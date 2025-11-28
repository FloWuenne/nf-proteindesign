/*
========================================================================================
    SPLIT_PROTEINMPNN_SEQUENCES: Split multi-sequence FASTA into individual files
========================================================================================
    This process takes a multi-sequence FASTA file from ProteinMPNN and splits it
    into individual FASTA files, one per sequence.
    
    It skips the first sequence (original binder) and only outputs the new designed sequences.
----------------------------------------------------------------------------------------
*/

process SPLIT_PROTEINMPNN_SEQUENCES {
    tag "${meta.id}"
    label 'process_low'

    container 'python:3.12-slim'

    input:
    tuple val(meta), path(fasta_file)

    output:
    tuple val(meta), path("*.fa"), emit: sequences
    path "versions.yml", emit: versions

    script:
    """
    #!/usr/bin/env python3
    
    import sys
    import os
    
    def split_fasta(input_file):
        sequences = []
        current_seq = []
        current_header = None
        
        # Read FASTA
        try:
            with open(input_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line: continue
                    if line.startswith('>'):
                        if current_header and current_seq:
                            sequences.append((current_header, ''.join(current_seq)))
                        current_header = line
                        current_seq = []
                    else:
                        current_seq.append(line)
                
                # Add last sequence
                if current_header and current_seq:
                    sequences.append((current_header, ''.join(current_seq)))
        except Exception as e:
            print(f"Error reading FASTA file {input_file}: {e}")
            sys.exit(1)
            
        print(f"Found {len(sequences)} sequences in {input_file}")
        
        # Skip the first sequence (original)
        sequences_to_process = sequences[1:] if len(sequences) > 1 else []
        
        if not sequences_to_process:
            print(f"Warning: Only found 1 sequence (original), no new MPNN sequences to split")
            # Create a placeholder to avoid error if downstream expects output
            # But typically we want to output nothing if no new sequences
            return
            
        print(f"Splitting {len(sequences_to_process)} new MPNN sequences")
        
        # Write each sequence to a separate file
        base_name = os.path.splitext(os.path.basename(input_file))[0]
        
        for idx, (header, seq) in enumerate(sequences_to_process):
            # Use 1-based indexing for filenames to match typical user expectations
            seq_num = idx + 1
            output_file = f"{base_name}_seq_{seq_num}.fa"
            
            with open(output_file, 'w') as out:
                out.write(f"{header}\\n{seq}\\n")
                
            print(f"Created {output_file}")

    if __name__ == "__main__":
        split_fasta("${fasta_file}")
        
        # Generate version information
        with open("versions.yml", "w") as f:
            f.write('"${task.process}":\\n')
            f.write(f'    python: {sys.version.split()[0]}\\n')
    """
}
