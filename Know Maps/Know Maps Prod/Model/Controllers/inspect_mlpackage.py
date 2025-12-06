import coremltools as ct

model_path = "MiniLM-L12-Embedding.mlpackage"

# Load the model
mlmodel = ct.models.MLModel(model_path)

spec = mlmodel.get_spec()

print("=== INPUTS ===")
for inp in spec.description.input:
    print(f"- name: {inp.name}")
    print(f"  type: {inp.type}")

print("\n=== OUTPUTS ===")
for out in spec.description.output:
    print(f"- name: {out.name}")
    print(f"  type: {out.type}")
