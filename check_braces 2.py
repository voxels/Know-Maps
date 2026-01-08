
def check_braces(filename):
    with open(filename, 'r') as f:
        lines = f.readlines()
    
    stack = []
    
    for i, line in enumerate(lines):
        line = line.strip()
        # Remove comments
        if "//" in line:
            line = line.split("//")[0]
        
        for char in line:
            if char == '{':
                stack.append(i + 1)
            elif char == '}':
                if not stack:
                    print(f"Extraneous }} at line {i + 1}")
                    return
                stack.pop()
                if not stack:
                     print(f"Stack became empty at line {i + 1}")
    
    if stack:
        print(f"Unclosed {{ at lines: {stack}")
    else:
        print("Braces are balanced.")

check_braces("/Users/voxels/Documents/dev/Know-Maps/Know-Maps/Know-Maps/Know Maps Prod/View/PlaceDetailSheet.swift")
