import coremltools as ct
import sys
import os

def inspect_model(model_path):
    # Load spec only for efficiency (avoids loading large weights into memory)
    try:
        spec = ct.utils.load_spec(model_path)
    except Exception as e:
        print(f"Warning: Could not load spec directly ({e}). Falling back to full model load.")
        # Fallback: compute_units=CPU_ONLY to avoid GPU allocation for simple inspection
        mlmodel = ct.models.MLModel(model_path, compute_units=ct.ComputeUnit.CPU_ONLY)
        spec = mlmodel.get_spec()

    print(f"=== Model: {model_path} ===")
    
    print("\n=== INPUTS ===")
    for inp in spec.description.input:
        print(f"- name: {inp.name}")
        print(f"  type: {inp.type}")

    print("\n=== OUTPUTS ===")
    for out in spec.description.output:
        print(f"- name: {out.name}")
        print(f"  type: {out.type}")

if __name__ == "__main__":
    # Default to hardcoded path if no arg provided, for backward compatibility
    target_path = "MiniLM-L12-Embedding.mlpackage"
    
    if len(sys.argv) > 1:
        target_path = sys.argv[1]
        
    if os.path.exists(target_path):
        inspect_model(target_path)
    else:
        print(f"Error: Model file not found at {target_path}")