import coremltools as ct
import argparse
import sys
import os

def inspect_model(model_path):
    if not os.path.exists(model_path):
        print(f"Error: Model not found at {model_path}")
        sys.exit(1)

    try:
        # Load the model
        mlmodel = ct.models.MLModel(model_path)
        spec = mlmodel.get_spec()

        print(f"Inspecting: {model_path}")
        print("=== INPUTS ===")
        for inp in spec.description.input:
            print(f"- name: {inp.name}")
            print(f"  type: {inp.type}")

        print("\n=== OUTPUTS ===")
        for out in spec.description.output:
            print(f"- name: {out.name}")
            print(f"  type: {out.type}")
            
    except Exception as e:
        print(f"Failed to load model: {e}")
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Inspect a CoreML model package.")
    parser.add_argument("model_path", nargs="?", default="MiniLM-L12-Embedding.mlpackage", help="Path to the .mlpackage or .mlmodel file")
    
    args = parser.parse_args()
    inspect_model(args.model_path)