# BGE-gaplist

This Snakemake workflow orchestrates the processing of taxonomic data 
from multiple sources, including BOLD Systems, Fauna Europaea, and expert 
contributions. It integrates data, performs gap analysis, and maintains 
updated species lists.

## License

Copyright 2024 Naturalis Biodiversity Center

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Preliminaries

The workflow combines pre-processed taxonomic information from the
following sources:

- BOLD
- Fauna Europaea
- Lepiform
- [WORMS](https://www.marinespecies.org/)
- [iNaturalist](https://doi.org/10.15468/dl.w5v28a)
- input from various experts

At present, these data are expected to simply be there, though the
future plan is to do this as part of the overall workflow.

## Workflow Overview

The pipeline consists of four main steps:
1. Updating BOLD data through their API
2. Combining data from multiple taxonomic sources
3. Analyzing coverage gaps
4. Generating final updated species lists

## Available Targets

### Default Target (`all`)
```bash
snakemake all
```
Runs the complete pipeline, generating:
- Updated combined species lists
- Gap analysis reports
- Sorted taxonomic hierarchies

### Individual Targets

#### Update BOLD Data
```bash
snakemake update_bold_data
```
Queries the BOLD API for current specimen data.

#### Combine Lists
```bash
snakemake combine_lists
```
Integrates data from all taxonomic sources.

#### Analyze Gaps
```bash
snakemake analyze_gaps
```
Generates gap analysis reports.

#### Update Final List
```bash
snakemake update_final_list
```
Merges latest BOLD data into combined lists.

### Utility Targets

#### Clean
```bash
snakemake clean
```
Removes all generated files and logs.

#### Generate Documentation
```bash
snakemake generate_docs
```
Creates documentation for all components.

## Running the Workflow

### Prerequisites
- Conda or Mamba
- Input data in Raw_Data directory

### Setup
1. Create the conda environment:
```bash
conda env create -f environment.yml
```

2. Activate the environment:
```bash
conda activate taxonomy-pipeline
```

### Execution

Full pipeline:
```bash
snakemake --cores all
```

Dry run to check execution plan:
```bash
snakemake -n
```

Generate workflow DAG:
```bash
snakemake --dag | dot -Tsvg > workflow.svg
```

### Resource Requirements

- BOLD data update: Single thread, ~2GB memory
- Data combination: Single thread, memory varies with input size
- Gap analysis: Multi-thread capable, memory scales with data size

### Output Structure

```
BGE-gaplist/
├── Curated_Data/          # Processed data
│   ├── updated_combined_lists.csv
│   ├── combined_species_lists.csv
│   └── {date}_updated_BOLD_data.csv
├── Gap_Lists/            # Analysis results
│   ├── Gap_list_all.csv
│   └── sorted/          # Hierarchical results
└── logs/                # Process logs
```

## Error Handling

- All steps log to files in logs/
- Failed steps retain partial outputs for inspection
- Use `--rerun-incomplete` to restart failed jobs

## Configuration

Edit config/config.yaml to modify:
- File paths
- API settings
- Processing parameters

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## Support

File issues on the project's issue tracker.

## Authors

Fabian Deister - SNSB
Rutger Vos - Naturalis 

## Acknowledgments

This workflow builds on work from Fabian Deister, SNSB
