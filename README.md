# Module 2: Text as data and LLM annotation

**Question:** *Do national climate laws and policies commit to concrete, measurable targets,
and does this differ between countries and regions?* Answering it at scale would mean letting a
model read thousands of documents. The lab asks whether we could trust that reading.

Students and two small open-weights LLMs decide whether passages from national climate policies
contain a **climate target** (quantifiable, with a deadline), then compare against expert labels
from [Climate Policy Radar](https://huggingface.co/datasets/ClimatePolicyRadar/national-climate-targets).
Everything is in one notebook, `module2.qmd`, and runs on the laptop. 

Companion reading: Lan, Zhang & Wang (2026), *Humanities and Social Sciences Communications*,
https://doi.org/10.1057/s41599-026-08575-0.

This is a methods exercise: the dataset is a classifier training set, not a
representative sample of national policies (see "Data" below).

## Getting started (same as previous module)

1. On this repository's GitHub page, click **Use this template** → **Create a new repository**.
2. Set **Owner** to the course organization (`dsep-ethz`), not your personal account.
3. Name the repository `climate-targets-lastname1-lastname2` (e.g. `climate-targets-chapman-perry`) and click **Create repository**.
4. In your new repository, go to **Settings** → **Collaborators and teams** → **Add people**, and add the TAs.
5. Clone your repository: in RStudio, **File** → **New Project** → **Version Control** → **Git**, and paste the URL from the green **Code** button.

## Before class (if you havent already)

1. Install [Ollama](https://ollama.com) and open it.
2. In a terminal, download the two models (~2 GB each):
   ```
   ollama pull llama3.2:3b
   ollama pull qwen2.5:3b
   ```

## The data files

The `data/` folder already contains everything the notebook needs: `sample.csv` (passages with and
without a target), `more_passages.csv` (100 unlabelled passages for section 8) and
`target_pool.csv` (target passages that name no country, for section 7). `prepare_data.R` shows how
they were made. It doesn't need to be run again, but it can be, for example to draw a different or
larger sample.

For the country swap at scale (section 7), run `country_swap_batch.R` once. It uses every passage in
`target_pool.csv` (293 with the current filter) times 6 countries, about 1,760 model calls (might take a few minutes).
It is resumable and writes `data/country_swap_results.csv`, which the notebook
loads automatically. Without it, students run a 20-passage version in class.

## The lab

Students work through `module2.qmd` at their own pace, in pairs

| Section | What students do |
| --- | --- |
| Intro | The framing question and what the data can and can't tell us |
| 1-2 | Read the definition, code 10 passages by hand |
| 3 | Run the two models (a few minutes of waiting the first time) |
| 4 | Compare everyone with the experts: targets found, agreement, Cohen's kappa |
| 5 | Read each disagreement: model error, unclear definition, or expert error? |
| 6 | Rewrite the definition, rerun one model, count how many labels flip |
| 7 (optional) | Same passage, different country name, then the batch results |
| 8 (optional) | Ask your own question: write a definition, hand-code 10 passages, test a model on 30 |
| 9 | From this sample to a whole corpus: what would you ask, and what would you check first? |
| | Closing questions |


## Data

Climate Policy Radar, national-climate-targets, CC-BY 4.0. Juhasz, M. et al. (2024). Identifying
Climate Targets in National Laws and Policies using Machine Learning. arXiv:2404.02822.

- 2,610 passages from national climate laws, policies and UNFCCC submissions, labelled by domain
  experts for net-zero, emissions-reduction and other targets.
- Built to train a classifier. The dataset card notes it "is not a list of all climate targets
  published by national governments", and passages were not sampled to represent countries.
- Many passages were machine-translated into English before labelling (`translated` column).
- The `geography` codes are unreliable: several passages tagged CRI (Costa Rica) are clearly from
  Canada, China or Germany. Don't use country or region for analysis.

Section 9 points students to Climate Policy Radar's full-text dataset,
[all-document-text-data](https://huggingface.co/datasets/ClimatePolicyRadar/all-document-text-data),
as the corpus they might scale up to.

## Exploring the full corpus (optional)

`bonus_cloud_native.qmd` is an optional extra, not part of the class exercise. It goes back to the
cloud-native workflow from Module 1 and applies it to Climate Policy Radar's full-text dataset
([all-document-text-data](https://huggingface.co/datasets/ClimatePolicyRadar/all-document-text-data),
48 files, 3.6 GB). The whole database isnt downloaded: dplyr verbs are translated by dbplyr and run by DuckDB
against the files in place, reading only file footers and the columns each question needs. It
covers corpus size and column sizes from metadata alone, counts by document type, country and
year, fetching text for one country, drawing a random sample of passages the experts never
labelled. The dataset of the full corpus is free but gated: you need a Hugging Face account, to accept Climate Policy Radar's
terms on the dataset page, and a token stored as `HF_TOKEN` (instructions in the notebook). The
token must be of type **Read**: Hugging Face's default fine-grained tokens are refused for gated
datasets unless "Read access to contents of all public gated repos you can access" is ticked, and
DuckDB reports that refusal as a confusing "HTTP 0" error. It
also needs `install.packages(c("duckdb", "DBI", "dbplyr"))`.
