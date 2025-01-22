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

```{text}
>onel / >oneh / >twol / >twoh
>l1 / >h1 / >l2 / >h2
>1 / >2
```

### Output
AlphaFold3 results in the `work` directory.

Need Help: yang_kaixin@gzlab.ac.cn