"""
inspect_mlpackage.py

A utility script to inspect the input and output specifications of a Core ML model package (.mlpackage).

Prerequisites:
    - Python 3
    - coremltools (`pip install coremltools`)

Usage:
    Run this script from the directory containing the model package, or pass the path as an argument.
    Example:
        python inspect_mlpackage.py MyModel.mlpackage
"""

import coremltools as ct
import sys
import os

# Default model path if none is provided via command line
default_model_path = "MiniLM-L12-Embedding.mlpackage"

def inspect_model(path):
    """
    Loads a Core ML model package and prints its input and output specifications.
    """
    if not os.path.exists(path):
        print(f"Error: Model not found at '{path}'")
        print(f"Usage: python {sys.argv[0]} [path/to/model.mlpackage]")
        return

    print(f"Loading model from: {path}")
    
    try:
        # Load the model
        mlmodel = ct.models.MLModel(path)
        spec = mlmodel.get_spec()

        # Print Description if available
        description = spec.description.metadata.shortDescription
        if description:
            print("\n=== DESCRIPTION ===")
            print(description)

        print("\n=== INPUTS ===")
        for inp in spec.description.input:
            print(f"- name: {inp.name}")
            print(f"  type: {inp.type}")

        print("\n=== OUTPUTS ===")
        for out in spec.description.output:
            print(f"- name: {out.name}")
            print(f"  type: {out.type}")
            
    except Exception as e:
        print(f"An error occurred while inspecting the model: {e}")

if __name__ == "__main__":
    # Use command line argument if available, otherwise default
    target_path = sys.argv[1] if len(sys.argv) > 1 else default_model_path
    inspect_model(target_path)
