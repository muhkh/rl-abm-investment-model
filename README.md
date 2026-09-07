# RL-ABM Investment Model

Research code and computational models integrating **Proximal Policy Optimization (PPO)** with **Agent-Based Modeling (ABM)** for dynamic investment decision-making.

The repository also includes a Python-based **Smart ABM-ANN Predictor**, which trains an artificial neural network (ANN) using simulation-generated data and provides predictions through a graphical user interface.

## Repository Contents

- `ABM-PPO for Dynamic Investments.nlogo` — NetLogo PPO-based agent-based investment model
- `GUI_Smart_ABM_ANN_Predictor.py` — Python ANN predictor with graphical user interface
- `sample_ppo_simulation_data.csv` — Sample PPO simulation dataset for testing the predictor
- `requirements.txt` — Required Python packages
- `CITATION.cff` — Citation metadata
- `LICENSE` — MIT License

## Using the ANN Predictor

### 1. Install the required Python packages

```bash
pip install -r requirements.txt
```

### 2. Run the predictor

```bash
python GUI_Smart_ABM_ANN_Predictor.py
```

### 3. Select a simulation dataset

When prompted, select a compatible NetLogo simulation dataset in CSV or Excel format.

The included file:

`sample_ppo_simulation_data.csv`

can be used to test the application.

### 4. Model training

The program automatically:

- identifies the relevant simulation variables,
- prepares and cleans the dataset,
- scales the input and output variables,
- trains the artificial neural network,
- and opens the **Smart ABM-ANN Predictor** graphical interface.

### 5. Generate predictions

Enter new parameter values in the graphical user interface and click **Predict** to generate predicted simulation outcomes.

## ANN Inputs

The predictor uses the following input variables:

- Number of Investors
- Mean Profit of Business Alternatives
- Business Mean Risk
- Business Max Risk
- Decision Time Horizon
- Simulation Years

## Predicted Outputs

The ANN generates predictions for:

- Mean Wealth of Investors
- Total Wealth of Investors
- Number of Investors with Wealth Below 100,000
- Utility of Investors
- Mean Business Profit
- Mean Failure Risk of Business Alternatives
- Number of Bankrupt Business Alternatives
- Number of High-Profit Business Alternatives

## CoMSES Computational Model Library

The published PPO-ABM model is also publicly available through the **CoMSES Computational Model Library**:

https://doi.org/10.25937/644j-cv09

The CoMSES release serves as the archived version of the computational model.

## How to Cite

If you use this model or associated code in academic work, please cite the archived CoMSES release:

Ali, M. K., Ali, H., & Mohammad, H. (2026). *Integrating Reinforcement Learning in Agent-Based Modeling for Dynamic Investment Decisions* (Version 1.0.0). CoMSES Computational Model Library. https://doi.org/10.25937/644j-cv09

## Authors

- **Muhammad Khurram Ali, PhD**
- **Haider Ali**
- **Hafiz Mohammad**

This repository accompanies the research work *Integrating Reinforcement Learning in Agent-Based Modeling for Dynamic Investment Decisions*.

## License

This repository is distributed under the **MIT License**. See the `LICENSE` file for details.
