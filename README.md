# Which Pharmacies Get Generics First After Launch?

## Title
Which Pharmacies Get Generics First After Launch? An ML.NET-Based Forecasting Framework for Generic Drug Diffusion and Access Inequality

## Overview
This project studies how first generic medicines diffuse across pharmacy access markets after launch. The research uses Numeric Distribution (ND) and Weighted Distribution (WD) metrics to analyze whether generic drugs reach high-volume markets first or spread broadly across markets.

## Research Question
After a first generic drug approval, do generic medicines reach high-volume pharmacy markets first, or do they spread equally across pharmacy markets? Can early ND/WD signals forecast whether a generic launch will become fast, delayed, or unequal?

## Technology Stack
- C#
- .NET
- ML.NET
- SQL Server
- SQL Server Management Studio
- Medicaid State Drug Utilization Data
- FDA First Generic Approval data

## Key Metrics
Numeric Distribution (ND):
Number of states where the generic appears divided by number of states where the brand/generic molecule appears.

Weighted Distribution (WD):
Total molecule prescriptions in states where the generic appears divided by total molecule prescriptions in all active states.

Access Gap:
WD minus ND.

## ML Task
The ML.NET model classifies generic adoption as:
- Fast
- Medium
- Slow

## Folder Structure
- Code/: C# and ML.NET code
- Data/: local raw data and training CSV files, not pushed to GitHub
- Results/: local result tables and trained model output, not pushed to GitHub
- Paper/: research paper draft and figures
- Figures/: charts and visualizations

## Note
Raw data files are not included in this repository because Medicaid SDUD files can be large. They should be downloaded separately from public data sources.

## Paper

Khan, T. M. (2026). *Which State-Level Pharmacy Markets Get Generics First After Launch? An ML.NET-Based Forecasting Framework for Generic Drug Diffusion and Access Inequality*. Zenodo. https://doi.org/10.5281/zenodo.20837673

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20837673.svg)](https://doi.org/10.5281/zenodo.20837673)

## Contact

Tanvir Mahmud Khan
Independent Researcher
Dhaka, Bangladesh
sajid8212@gmail.com