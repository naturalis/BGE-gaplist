# BGE-gaplist

This Snakemake workflow orchestrates the processing of taxonomic data 
from multiple sources, including BOLD Systems, Fauna Europaea, and expert 
contributions. It integrates data, performs gap analysis, and maintains 
updated species lists.

## License

Copyright 2024 [Organization]

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Workflow Overview

The pipeline consists of four main steps:
1. Updating BOLD data through their API
2. Combining data from multiple taxonomic sources
3. Analyzing coverage gaps
4. Generating final updated species lists

## Available Targets

### Default Target (`all`)
```bash
snakemake --cores all
```
Runs the complete pipeline, generating:
- Updated combined species lists
- Gap analysis reports
- Sorted taxonomic hierarchies

### Individual Targets

#### Update BOLD Data
```bash
snakemake --cores 1 Curated_Data/{date}_updated_BOLD_data.csv
```
Queries the BOLD API for current specimen data.

#### Combine Lists
```bash
snakemake --cores 1 Curated_Data/combined_species_lists.csv
```
Integrates data from all taxonomic sources.

#### Analyze Gaps
```bash
snakemake --cores 1 Gap_Lists/Gap_list_all.csv
```
Generates gap analysis reports.

#### Update Final List
```bash
snakemake --cores 1 Curated_Data/updated_combined_lists.csv
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
taxonomy-pipeline/
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

[Your Name] - [Your Institution]

## Acknowledgments

This workflow builds on work from [relevant projects/people].
