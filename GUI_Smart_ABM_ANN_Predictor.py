# GUI_Smart_ABM_ANN_Predictor.py
# --------------------------------
# 1) Selects a NetLogo BehaviorSpace CSV/Excel dataset
# 2) Automatically detects the true header row
# 3) Maps raw NetLogo variable/reporter names to readable ANN variable names
# 4) Trains a scaled multi-output neural-network predictor
# 5) Opens the GUI only after training
# 6) Returns predictions in the original output units

import csv
import os
import re
import tkinter as tk
from tkinter import filedialog, messagebox
from typing import Dict, List

import numpy as np
import pandas as pd
from sklearn.neural_network import MLPRegressor
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler


# -----------------------------
# Variable Names
# -----------------------------
INPUT_COLUMNS = [
    "No. of Investors",
    "Mean Profit of Business Alternatives",
    "Business Mean Risk",
    "Business Max Risk",
    "Decision Time Horizon",
    "Simulation Years",
]

OUTPUT_COLUMNS = [
    "Mean Wealth of Investors",
    "Total Wealth of Investors",
    "No. of Investors with wealth < 100000",
    "Utility of Investors",
    "Mean Business Profit",
    "Patches Mean Failure Risk",
    "No. of Patches with profit < 500 (bankrupt)",
    "No. of Patches with profit > 15000",
]


# Raw NetLogo BehaviorSpace names -> readable names used by the ANN/GUI
COLUMN_ALIASES = {
    "num-investors": "No. of Investors",
    "patch-mean-profit": "Mean Profit of Business Alternatives",
    "patch-min-risk": "Business Mean Risk",
    "patch-max-risk": "Business Max Risk",
    "decision-time-horizon": "Decision Time Horizon",
    "years-simulated": "Simulation Years",
    "mean [wealth] of turtles": "Mean Wealth of Investors",
    "sum [wealth] of turtles": "Total Wealth of Investors",
    "count turtles with [wealth < 100000]": "No. of Investors with wealth < 100000",
    "mean [current-utility] of turtles": "Utility of Investors",
    "mean [profit] of patches": "Mean Business Profit",
    "mean [annual-risk] of patches": "Patches Mean Failure Risk",
    "count patches with [profit < 500]": "No. of Patches with profit < 500 (bankrupt)",
    "count patches with [profit > 15000]": "No. of Patches with profit > 15000",
}


# -----------------------------
# Helpers
# -----------------------------
def normalize_col(s: str) -> str:
    s = str(s).strip().lower()
    s = re.sub(r"[^a-z0-9]+", "", s)
    return s


# Build normalized aliases so spacing/punctuation differences do not matter.
NORMALIZED_ALIASES = {
    normalize_col(raw): readable for raw, readable in COLUMN_ALIASES.items()
}
for canonical in INPUT_COLUMNS + OUTPUT_COLUMNS:
    NORMALIZED_ALIASES[normalize_col(canonical)] = canonical


def standardize_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Rename recognized NetLogo/raw column headings to the ANN's readable names."""
    rename_map = {}
    for col in df.columns:
        key = normalize_col(col)
        if key in NORMALIZED_ALIASES:
            rename_map[col] = NORMALIZED_ALIASES[key]
    return df.rename(columns=rename_map)


def _header_score(values) -> int:
    """Count how many expected input/output headings occur in a candidate row."""
    keys = {normalize_col(v) for v in values if pd.notna(v)}
    return sum(key in NORMALIZED_ALIASES for key in keys)


def detect_csv_header(path: str, max_rows: int = 50) -> int:
    """Locate the actual header row in either raw BehaviorSpace or clean CSV files."""
    best_row = 0
    best_score = -1

    with open(path, "r", encoding="utf-8-sig", errors="replace", newline="") as f:
        reader = csv.reader(f)
        for row_number, row in enumerate(reader):
            if row_number >= max_rows:
                break
            score = _header_score(row)
            if score > best_score:
                best_row = row_number
                best_score = score

    # Require enough recognized fields to avoid treating metadata as a header.
    if best_score < 3:
        raise ValueError(
            "Could not identify the dataset header row. "
            "Please use a NetLogo BehaviorSpace export or a CSV/Excel file "
            "containing the required model variables."
        )
    return best_row


def detect_excel_header(path: str, max_rows: int = 50) -> int:
    """Locate the actual header row in an Excel dataset."""
    preview = pd.read_excel(path, header=None, nrows=max_rows)
    scores = [(_header_score(preview.iloc[i].tolist()), i) for i in range(len(preview))]
    best_score, best_row = max(scores, default=(-1, 0))

    if best_score < 3:
        raise ValueError(
            "Could not identify the dataset header row. "
            "Please use an Excel file containing the required model variables."
        )
    return best_row


def pick_file() -> str:
    root = tk.Tk()
    root.withdraw()
    path = filedialog.askopenfilename(
        title="Select your simulation dataset",
        filetypes=[
            ("CSV files", "*.csv"),
            ("Excel files", "*.xlsx *.xls"),
            ("All files", "*.*"),
        ],
    )
    root.update()
    root.destroy()
    if not path:
        raise SystemExit("No file selected.")
    return path


def read_table(path: str) -> pd.DataFrame:
    """Read clean datasets or raw NetLogo BehaviorSpace exports automatically."""
    ext = os.path.splitext(path)[1].lower()

    if ext == ".csv":
        header_row = detect_csv_header(path)
        df = pd.read_csv(path, header=header_row)
    elif ext in [".xlsx", ".xls"]:
        header_row = detect_excel_header(path)
        df = pd.read_excel(path, header=header_row)
    else:
        raise ValueError("Unsupported file type. Please select a CSV, XLSX, or XLS file.")

    return standardize_columns(df)


def build_column_map(df_cols: List[str]) -> Dict[str, str]:
    return {normalize_col(c): c for c in df_cols}


def resolve_columns(required: List[str], mapping: Dict[str, str]) -> List[str]:
    resolved, missing = [], []
    for name in required:
        key = normalize_col(name)
        if key in mapping:
            resolved.append(mapping[key])
        else:
            missing.append(name)

    if missing:
        raise ValueError(
            "The selected dataset is missing required columns:\n- "
            + "\n- ".join(missing)
        )
    return resolved


def coerce_numeric(df: pd.DataFrame, cols: List[str]) -> pd.DataFrame:
    df = df.copy()
    for c in cols:
        df[c] = pd.to_numeric(df[c], errors="coerce")
    return df


def make_model() -> Pipeline:
    mlp = MLPRegressor(
        hidden_layer_sizes=(128, 64, 32),
        activation="relu",
        solver="adam",
        random_state=42,
        max_iter=5000,
        early_stopping=True,
        n_iter_no_change=50,
        validation_fraction=0.15,
        learning_rate_init=0.001,
        verbose=True,
    )
    return Pipeline([
        ("xscaler", StandardScaler()),
        ("mlp", mlp),
    ])


# -----------------------------
# GUI Class
# -----------------------------
class PredictorGUI:
    def __init__(
        self,
        model: Pipeline,
        yscaler: StandardScaler,
        input_cols: List[str],
        output_cols: List[str],
        defaults: Dict[str, float],
    ):
        self.model = model
        self.yscaler = yscaler
        self.input_cols = input_cols
        self.output_cols = output_cols
        self.defaults = defaults

        self.root = tk.Tk()
        self.root.title("Smart ABM-ANN Predictor")
        self.root.geometry("950x550")
        self.root.configure(bg="#F4F4F4")

        tk.Label(
            self.root,
            text="Smart ABM-ANN Predictor",
            font=("Segoe UI", 18, "bold"),
            fg="black",
            bg="#F4F4F4",
        ).pack(pady=15)

        frm_inputs = tk.Frame(self.root, bg="#F4F4F4")
        frm_inputs.pack(padx=16, pady=8)

        ranges = {
            "No. of Investors": "(Range: 0–100)",
            "Mean Profit of Business Alternatives": "(Range: 2000–5000)",
            "Business Mean Risk": "(Range: 0.01–0.10)",
            "Business Max Risk": "(Range: 0.10–0.70)",
            "Decision Time Horizon": "(Range: 2–9)",
            "Simulation Years": "(Range: 10–100)",
        }

        self.vars: Dict[str, tk.StringVar] = {}
        for i, col in enumerate(self.input_cols):
            row = i % 3
            col_idx = i // 3

            box = tk.Frame(
                frm_inputs,
                bg="#F4F4F4",
                highlightbackground="#E0E0E0",
                highlightthickness=1,
            )
            box.grid(row=row, column=col_idx, padx=10, pady=6, sticky="ew")

            tk.Label(
                box,
                text=col,
                anchor="w",
                width=35,
                font=("Segoe UI", 10, "bold"),
                fg="black",
                bg="#F4F4F4",
            ).pack(side="left", padx=8)

            v = tk.StringVar(value=str(self.defaults.get(col, "")))
            tk.Entry(
                box,
                textvariable=v,
                bg="white",
                fg="black",
                width=12,
            ).pack(side="left", padx=8, pady=4)
            self.vars[col] = v

            tk.Label(
                box,
                text=ranges.get(col, ""),
                font=("Segoe UI", 9, "italic"),
                fg="#808080",
                bg="#F4F4F4",
            ).pack(side="left", padx=4)

        tk.Button(
            self.root,
            text="Predict",
            command=self.on_predict,
            font=("Segoe UI", 11, "bold"),
            fg="white",
            bg="#2E8B57",
            activebackground="#1e6b40",
            activeforeground="white",
            relief="flat",
            padx=15,
            pady=3,
        ).pack(pady=15)

        tk.Label(
            self.root,
            text="Predicted Outputs",
            font=("Segoe UI", 12, "bold"),
            fg="black",
            bg="#F4F4F4",
        ).pack(pady=5)

        self.out_text = tk.Text(
            self.root,
            height=9,
            width=95,
            bg="white",
            fg="black",
            insertbackground="black",
            font=("Consolas", 10),
        )
        self.out_text.pack(padx=16, pady=8)
        self.out_text.configure(state="disabled")

    def on_predict(self):
        try:
            values = [float(self.vars[col].get().strip()) for col in self.input_cols]
            X = np.array([values], dtype=float)

            # Pipeline applies the same input scaling used during training.
            y_scaled = self.model.predict(X)
            y_pred = self.yscaler.inverse_transform(
                np.asarray(y_scaled).reshape(1, -1)
            )[0]

            self.out_text.configure(state="normal")
            self.out_text.delete("1.0", tk.END)
            for name, pred in zip(self.output_cols, y_pred):
                self.out_text.insert(tk.END, f"{name}: {pred:,.2f}\n")
            self.out_text.configure(state="disabled")

        except Exception as e:
            messagebox.showerror("Prediction Error", str(e))

    def run(self):
        self.root.mainloop()


# -----------------------------
# Main
# -----------------------------
def main():
    path = pick_file()
    df = read_table(path)

    colmap = build_column_map(list(df.columns))
    in_cols = resolve_columns(INPUT_COLUMNS, colmap)
    out_cols = resolve_columns(OUTPUT_COLUMNS, colmap)

    df = coerce_numeric(df, in_cols + out_cols).dropna(subset=in_cols + out_cols)
    if len(df) == 0:
        raise SystemExit("No usable rows remain after numeric cleaning.")

    X = df[in_cols].values.astype(float)
    y = df[out_cols].values.astype(float)

    yscaler = StandardScaler()
    y_scaled = yscaler.fit_transform(y)

    print(f"\nLoaded {len(df):,} usable simulation records.")
    print("Training neural network model... Please wait.")
    model = make_model()
    model.fit(X, y_scaled)
    print("Training complete. Opening GUI...\n")

    defaults = {col: float(df[col].median()) for col in in_cols}
    app = PredictorGUI(model, yscaler, in_cols, out_cols, defaults)
    app.run()


if __name__ == "__main__":
    main()
