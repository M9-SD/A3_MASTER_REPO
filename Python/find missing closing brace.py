def find_missing_brace(script):
    stack = []
    line_number = 0

    for line in script.splitlines():
        line_number += 1
        for char in line:
            if char == "{":
                stack.append((line_number, "{"))
            elif char == "}":
                if not stack:
                    return line_number, char
                stack.pop()

    if stack:
        return stack[-1]

    return None, None

# Example usage
# Load the SQF file
file_path = 'M9SD_moduleInstallNapalmBomb.sqf'
with open(file_path, "r") as file:
    script = file.read()

line_number, char = find_missing_brace(script)

if line_number and char:
    print(f"Missing closing brace '}}' on line {line_number}.")
else:
    print("No missing braces found.")
