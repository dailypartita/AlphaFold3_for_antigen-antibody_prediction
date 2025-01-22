#!/usr/bin/env nextflow

"""
This Nextflow pipeline is designed to run AlphaFold3 for antigen-antibody prediction.

Author: Kaixin Yang (yang_kaixin@gzlab.ac.cn), GCBI

1. `generateInputJson`: This process generates JSON input files required by AlphaFold3. It reads antibody and antigen sequences from FASTA files, combines them, and writes the combinations to JSON files.

2. `run_msa`: This process runs AlphaFold3 using the generated JSON files. It uses a singularity container with the necessary environment and dependencies.

3. `run_inference`: This process runs AlphaFold3 using the generated JSON files. It uses a singularity container with the necessary environment and dependencies.

### Requirements
- Nextflow = 23.04.0
- Singularity (default in environment)
- AlphaFold3 model files and database (follow the Usage)

### Usage
1. Place your antibody and antigen sequences in `antibody.fasta` and `antigen.fasta` (see Example Input).

2. Run the pipeline with:
    ```bash
    nextflow run af3_parallel_abag.nf -with-singularity /home/apps/alphafold3/alphafold3_parallel.sif --model /home/apps/alphafold3/af3.bin.zst --af3db /home/apps/alphafold3/af3db --antibody <abs_path_of_antibody.fasta> --antigen <abs_path_of_antigen.fasta> -bg #-bg to running background
    ```

> Note: more details about `nextflow` can be found [here](https://www.nextflow.io/docs/latest/index.html).

### Example Input
Sequence id must be uppercase alpha string, and the end of each id must be set to light chain (L) or heavy chain (H), example:
- `antibody.fasta`:
  ```
  >ONEL
  DIQMTQTTSSL...
  >ONEH
  EVKLLESGGGLVQPGG...
  >TWOL
  DIVMTQSHKFM...
  >TWOH
  QVQLQQSGAELV...
  ```
- `antigen.fasta`:
  ```
  >AG
  AEGAEAPCGVAPQARITGGS...
  ```

!!!ID NOT supported!!!:
>onel / >oneh / >twol / >twoh
>l1 / >h1 / >l2 / >h2
>1 / >2

### Output
AlphaFold3 results in the `work` directory.

Need Help: yang_kaixin@gzlab.ac.cn
"""

def model_dir = new File(params.model).getParent()

process generateInputJson {
    executor 'local'

    input:
    path antibody
    path antigen
    output:
    path "combo_*.json"

    script:
    """
    python - <<EOF
    import json

    def read_fasta(file_path):
        ids, sequences = [], []
        current_id = None
        current_seq = []
        
        with open(file_path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                if line.startswith('>'):
                    if current_id:
                        ids.append(current_id)
                        sequences.append(''.join(current_seq))
                        current_seq = []
                    current_id = line[1:].upper()  # Remove '>' and convert to uppercase
                else:
                    current_seq.append(line)
            
            if current_id:  # Don't forget the last sequence
                ids.append(current_id)
                sequences.append(''.join(current_seq))
                
        return ids, sequences

    abid, abseq = read_fasta("${antibody}")
    agid, agseq = read_fasta("${antigen}")
    
    for i in range(len(abid) - 1):
        if abid[i][-1] != 'L':
            continue
        input_json = {
            "name": f"combo_{abid[i][:-1]}_{agid[0]}",
            "modelSeeds": [1],
            "sequences": [],
            "dialect": "alphafold3",
            "version": 1
        }
        input_json["sequences"].append({
            "protein": {
                "id": abid[i],
                "sequence": abseq[i]
            }
        })
        input_json["sequences"].append({
            "protein": {
                "id": abid[i + 1],
                "sequence": abseq[i + 1]
            }
        })
        input_json["sequences"].append({
            "protein": {
                "id": agid[0],
                "sequence": agseq[0]
            }
        })
        with open(f"combo_{abid[i][:-1]}_{agid[0]}.json", "w") as f:
            json.dump(input_json, f, indent=4)
    EOF
    """
}

process run_msa {
    executor 'slurm'
    clusterOptions '--job-name=AF3_MSA --cpus-per-task=32 --mem=64GB'
    containerOptions "--bind ${params.af3db}:/mnt/public_databases --bind ${model_dir}:/mnt/models"

    input:
    path json_in
    
    output:
    path('*/*_data.json', arity: '1')
    
    script:
    """
    python /app/alphafold/run_alphafold.py --norun_inference --db_dir=/mnt/public_databases --model_dir=/mnt/models --json_path=${json_in} --output_dir=./
    """
}

process run_inference {
    errorStrategy 'finish'
    executor 'slurm'
    clusterOptions '--job-name=AF3_INFERENCE --partition=gpu --gres=gpu:1'
    containerOptions "--nv --bind ${params.af3db}:/mnt/public_databases --bind ${model_dir}:/mnt/models"
    
    input:
    path json_msa
    
    script:
    """
    export XLA_PYTHON_CLIENT_PREALLOCATE=false
    export TF_FORCE_UNIFIED_MEMORY=true
    export XLA_CLIENT_MEM_FRACTION=3.2
    python /app/alphafold/run_alphafold.py --norun_data_pipeline --db_dir=/mnt/public_databases --model_dir=/mnt/models --json_path=${json_msa} --output_dir=./
    """
}

workflow {
    generateInputJson(params.antibody, params.antigen)
    run_msa(generateInputJson.out | flatten) | run_inference
}
